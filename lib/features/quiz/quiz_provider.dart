import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/ai/ai_settings_service.dart';
import 'package:uuid/uuid.dart';
import 'quiz.dart';
import '../sources/source_provider.dart';
import '../gamification/gamification_provider.dart';
import '../../core/ai/gemini_service.dart';
import '../../core/ai/openrouter_service.dart';
import '../../core/security/global_credentials_service.dart';
import '../../core/api/api_service.dart';

/// Provider for managing quizzes
class QuizNotifier extends StateNotifier<List<Quiz>> {
  final Ref ref;

  QuizNotifier(this.ref) : super([]) {
    _loadQuizzes();
  }

  Future<void> _loadQuizzes() async {
    try {
      final api = ref.read(apiServiceProvider);
      final quizzesData = await api.getQuizzes();
      state = quizzesData.map((j) => Quiz.fromBackendJson(j)).toList()
        ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    } catch (e) {
      debugPrint('Error loading quizzes: $e');
      state = [];
    }
  }

  /// Get quizzes for a specific notebook
  List<Quiz> getQuizzesForNotebook(String notebookId) {
    return state.where((quiz) => quiz.notebookId == notebookId).toList();
  }

  /// Add a new quiz
  Future<void> addQuiz(Quiz quiz) async {
    try {
      final api = ref.read(apiServiceProvider);
      await api.createQuiz(
        title: quiz.title,
        notebookId: quiz.notebookId,
        sourceId: quiz.sourceId,
        questions: quiz.questions.map((q) => q.toBackendJson()).toList(),
      );
      await _loadQuizzes();
    } catch (e) {
      debugPrint('Error adding quiz: $e');
    }
  }

  /// Update existing quiz
  Future<void> updateQuiz(Quiz quiz) async {
    await _loadQuizzes();
  }

  /// Delete a quiz
  Future<void> deleteQuiz(String id) async {
    try {
      final api = ref.read(apiServiceProvider);
      await api.deleteQuiz(id);
      state = state.where((quiz) => quiz.id != id).toList();
    } catch (e) {
      debugPrint('Error deleting quiz: $e');
    }
  }

  /// Generate quiz from sources using AI
  Future<Quiz> generateFromSources({
    required String notebookId,
    required String title,
    String? sourceId,
    int questionCount = 10,
  }) async {
    // Get source content
    final sources = ref.read(sourceProvider);
    final relevantSources = sourceId != null
        ? sources.where((s) => s.id == sourceId).toList()
        : sources.where((s) => s.notebookId == notebookId).toList();

    if (relevantSources.isEmpty) {
      throw Exception('No sources found to generate quiz from');
    }

    final sourceContent =
        relevantSources.map((s) => '## ${s.title}\n${s.content}').join('\n\n');

    // Build prompt for AI
    final prompt = '''
Generate exactly $questionCount multiple-choice questions from the following content.
Each question should have 4 options with exactly one correct answer.
Include a brief explanation for why the correct answer is right.

CONTENT:
$sourceContent

Return ONLY a JSON array with this exact format:
[
  {
    "question": "What is the main purpose of...?",
    "options": ["Option A", "Option B", "Option C", "Option D"],
    "correctOptionIndex": 0,
    "explanation": "The correct answer is A because..."
  }
]

correctOptionIndex: 0-3 (index of the correct option)
Vary difficulty across questions.
''';

    // Call AI service
    final response = await _callAI(prompt);
    final questions = _parseQuestionsFromResponse(response);

    final now = DateTime.now();
    final quiz = Quiz(
      id: const Uuid().v4(),
      title: title,
      notebookId: notebookId,
      sourceId: sourceId,
      questions: questions,
      createdAt: now,
      updatedAt: now,
    );

    await addQuiz(quiz);
    return quiz;
  }

  Future<String> _callAI(String prompt) async {
    try {
      final settings = await AISettingsService.getSettings();
      final provider = settings.provider;
      final model = settings.getEffectiveModel();
      final creds = ref.read(globalCredentialsServiceProvider);

      debugPrint('[QuizProvider] Using AI provider: $provider, model: $model');

      if (provider == 'openrouter') {
        final apiKey = await creds.getApiKey('openrouter');
        if (apiKey == null || apiKey.isEmpty) {
          throw Exception(
              'OpenRouter API key not found. Please configure it in Settings.');
        }
        final openRouter = OpenRouterService();
        return await openRouter.generateContent(prompt,
            model: model, apiKey: apiKey, maxTokens: 8192);
      } else {
        final apiKey = await creds.getApiKey('gemini');
        if (apiKey == null || apiKey.isEmpty) {
          throw Exception(
              'Gemini API key not found. Please configure it in Settings.');
        }
        final gemini = GeminiService();
        return await gemini.generateContent(prompt,
            model: model, apiKey: apiKey, maxTokens: 8192);
      }
    } catch (e) {
      debugPrint('[QuizProvider] AI call failed: $e');
      rethrow;
    }
  }

  List<QuizQuestion> _parseQuestionsFromResponse(String response) {
    try {
      // Extract JSON from response
      final jsonMatch = RegExp(r'\[[\s\S]*\]').firstMatch(response);
      if (jsonMatch == null) throw Exception('No JSON array found');

      final List<dynamic> jsonList = jsonDecode(jsonMatch.group(0)!);

      return jsonList.map((item) {
        return QuizQuestion(
          id: const Uuid().v4(),
          question: item['question'] ?? '',
          options: List<String>.from(item['options'] ?? []),
          correctOptionIndex: item['correctOptionIndex'] ?? 0,
          explanation: item['explanation'],
        );
      }).toList();
    } catch (e) {
      debugPrint('Error parsing questions: $e');
      return [];
    }
  }

  /// Record a quiz attempt
  Future<void> recordAttempt(
      String quizId, int score, int total, Duration timeTaken) async {
    final index = state.indexWhere((q) => q.id == quizId);
    if (index < 0) return;

    final quiz = state[index];
    final now = DateTime.now();

    final updatedQuiz = quiz.copyWith(
      timesAttempted: quiz.timesAttempted + 1,
      lastScore: score,
      bestScore: (quiz.bestScore == null || score > quiz.bestScore!)
          ? score
          : quiz.bestScore,
      lastAttemptedAt: now,
      updatedAt: now,
    );

    state = [...state]..[index] = updatedQuiz;
    // Track gamification
    final isPerfect = score == total;
    ref
        .read(gamificationProvider.notifier)
        .trackQuizCompleted(isPerfect: isPerfect);
    ref.read(gamificationProvider.notifier).trackFeatureUsed('quiz');

    // Sync to backend
    try {
      final api = ref.read(apiServiceProvider);
      await api.recordQuizAttempt(
        quizId: quizId,
        score: score,
        total: total,
      );
      await _loadQuizzes();
    } catch (e) {
      debugPrint('Error recording attempt: $e');
    }
  }
}

final quizProvider = StateNotifierProvider<QuizNotifier, List<Quiz>>((ref) {
  return QuizNotifier(ref);
});
