import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/ai/ai_settings_service.dart';
import '../../core/ai/openrouter_service.dart';
import '../../core/ai/gemini_service.dart';
import '../../core/ai/deep_research_service.dart';
import '../../core/security/global_credentials_service.dart';
import 'prediction.dart';

final predictorChatProvider =
    StateNotifierProvider<PredictorChatNotifier, PredictorChatState>((ref) {
  return PredictorChatNotifier(ref);
});

class PredictorMessage {
  final String id;
  final String content;
  final bool isUser;
  final DateTime timestamp;

  PredictorMessage({
    required this.id,
    required this.content,
    required this.isUser,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();
}

class PredictorChatState {
  final List<PredictorMessage> messages;
  final bool isTyping;
  final String? error;
  final List<SportsPrediction> predictionsContext;

  PredictorChatState({
    this.messages = const [],
    this.isTyping = false,
    this.error,
    this.predictionsContext = const [],
  });

  PredictorChatState copyWith({
    List<PredictorMessage>? messages,
    bool? isTyping,
    String? error,
    List<SportsPrediction>? predictionsContext,
  }) {
    return PredictorChatState(
      messages: messages ?? this.messages,
      isTyping: isTyping ?? this.isTyping,
      error: error,
      predictionsContext: predictionsContext ?? this.predictionsContext,
    );
  }
}

class PredictorChatNotifier extends StateNotifier<PredictorChatState> {
  final Ref ref;

  PredictorChatNotifier(this.ref) : super(PredictorChatState());

  void setPredictionsContext(List<SportsPrediction> predictions) {
    state = state.copyWith(predictionsContext: predictions);
  }

  Future<void> sendMessage(String content) async {
    // Add user message
    final userMessage = PredictorMessage(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      content: content,
      isUser: true,
    );

    state = state.copyWith(
      messages: [...state.messages, userMessage],
      isTyping: true,
      error: null,
    );

    try {
      // Check if user wants live research
      final needsResearch = _needsLiveResearch(content);

      String response;
      if (needsResearch) {
        response = await _generateWithResearch(content);
      } else {
        response = await _generateResponse(content);
      }

      final aiMessage = PredictorMessage(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        content: response,
        isUser: false,
      );

      state = state.copyWith(
        messages: [...state.messages, aiMessage],
        isTyping: false,
      );
    } catch (e) {
      debugPrint('[PredictorChat] Error: $e');

      final errorMessage = PredictorMessage(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        content:
            'Sorry, I encountered an error. Please try again. Error: ${e.toString()}',
        isUser: false,
      );

      state = state.copyWith(
        messages: [...state.messages, errorMessage],
        isTyping: false,
        error: e.toString(),
      );
    }
  }

  bool _needsLiveResearch(String query) {
    final lowerQuery = query.toLowerCase();
    final researchKeywords = [
      'today',
      'tonight',
      'tomorrow',
      'this week',
      'upcoming',
      'latest',
      'current',
      'live',
      'now',
      'recent',
      'predict',
      'prediction',
      'odds',
      'bet',
    ];
    return researchKeywords.any((k) => lowerQuery.contains(k));
  }

  Future<String> _generateWithResearch(String query) async {
    try {
      final deepResearch = ref.read(deepResearchServiceProvider);

      // Quick research for live data
      String researchData = '';
      await for (final update in deepResearch.research(
        '$query sports betting odds predictions',
        notebookId: '',
        depth: ResearchDepth.quick,
        template: ResearchTemplate.general,
      )) {
        if (update.result != null) {
          researchData = update.result!;
        }
      }

      // Generate response with research context
      return await _generateResponse(query, researchContext: researchData);
    } catch (e) {
      debugPrint('[PredictorChat] Research failed, falling back: $e');
      return await _generateResponse(query);
    }
  }

  Future<String> _generateResponse(String userMessage,
      {String? researchContext}) async {
    final settings = await AISettingsService.getSettings();
    final provider = settings.provider;
    final model = settings.getEffectiveModel();

    final creds = ref.read(globalCredentialsServiceProvider);
    String? apiKey;

    if (provider == 'openrouter') {
      apiKey = await creds.getApiKey('openrouter');
    } else {
      apiKey = await creds.getApiKey('gemini');
    }

    // Build conversation history
    final conversationHistory = state.messages.map((m) {
      return '${m.isUser ? "User" : "Assistant"}: ${m.content}';
    }).join('\n');

    // Build predictions context
    String predictionsInfo = '';
    if (state.predictionsContext.isNotEmpty) {
      predictionsInfo = '''
## CURRENT PREDICTIONS IN CONTEXT
${state.predictionsContext.map((p) => '''
- ${p.homeTeam} vs ${p.awayTeam} (${p.league})
  Date: ${p.matchDate}
  Odds: Home ${p.odds.homeWin}, Draw ${p.odds.draw}, Away ${p.odds.awayWin}
  Confidence: ${(p.confidence * 100).round()}%
  Analysis: ${p.analysis}
''').join('\n')}
''';
    }

    final prompt = '''
You are an expert Sports AI Predictor Agent. You specialize in:
- Analyzing sports matches and predicting outcomes
- Understanding betting odds and value bets
- Team form analysis and head-to-head statistics
- Providing insights on various sports (football, basketball, tennis, etc.)

## YOUR PERSONALITY
- Confident but not overconfident
- Data-driven and analytical
- Helpful and engaging
- Use sports terminology appropriately
- Include relevant emojis to make responses engaging

## GUIDELINES
- Always mention that predictions are for entertainment/informational purposes
- Provide reasoning behind predictions
- If asked about specific matches, give odds estimates
- Be honest about uncertainty
- Format responses clearly with bullet points when listing multiple items

$predictionsInfo

${researchContext != null ? '''
## LIVE RESEARCH DATA
$researchContext
''' : ''}

## CONVERSATION HISTORY
$conversationHistory

## CURRENT USER MESSAGE
$userMessage

---
Respond as the Sports AI Predictor Agent. Be helpful, insightful, and engaging.
Keep responses concise but informative (2-4 paragraphs max unless detailed analysis requested).
''';

    String response;
    if (provider == 'openrouter') {
      final service = OpenRouterService(apiKey: apiKey);
      response = await service.generateContent(prompt, model: model);
    } else {
      final service = GeminiService(apiKey: apiKey);
      response = await service.generateContent(prompt, model: model);
    }

    return response;
  }

  void clearChat() {
    state = PredictorChatState(predictionsContext: state.predictionsContext);
  }
}
