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
        query: '$query sports betting odds predictions',
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
You are an elite Sports AI Predictor Agent with deep expertise in sports analytics and betting markets.

## YOUR EXPERTISE
- Match outcome predictions with probability analysis
- Value bet identification (odds vs true probability)
- Team form, injuries, head-to-head analysis
- Multiple sports: Football ⚽, Basketball 🏀, Tennis 🎾, American Football 🏈, Hockey 🏒

## CURRENT DATE & TIME
📅 Today: ${DateTime.now().toIso8601String().split('T')[0]}
🕐 Time: ${DateTime.now().hour}:${DateTime.now().minute.toString().padLeft(2, '0')}

## RESPONSE FORMAT GUIDELINES

### For Match Predictions:
Use this structured format:

**🏆 [MATCH]: [Team A] vs [Team B]**
📅 Date: [Specific date]
🏟️ Competition: [League/Tournament]

**📊 PREDICTION:**
• **Pick:** [Your prediction - e.g., "Team A Win", "Over 2.5 Goals", "Both Teams to Score"]
• **Confidence:** [⭐⭐⭐⭐⭐ or percentage]
• **Odds Value:** [Fair/Good/Excellent]

**📈 KEY FACTORS:**
• [Factor 1 - e.g., "Home team won 5 of last 6"]
• [Factor 2 - e.g., "Away team missing key striker"]
• [Factor 3 - e.g., "H2H: Home team unbeaten in last 4 meetings"]

**⚠️ RISKS:**
• [Risk factor to consider]

---

### For General Questions:
- Be conversational and engaging
- Use bullet points for clarity
- Include relevant stats when available
- Add emojis to make it visually appealing

### For Multiple Predictions:
Present as a ranked list with confidence levels:
1. 🔥 **HIGH CONFIDENCE** - [Pick] @ [Odds estimate]
2. ✅ **MEDIUM CONFIDENCE** - [Pick] @ [Odds estimate]
3. 🎯 **VALUE BET** - [Pick] @ [Odds estimate]

## IMPORTANT RULES
⚠️ Always include: "Predictions are for entertainment purposes only. Gamble responsibly."
✅ Be specific with dates (not "tomorrow" but "December 30, 2024")
✅ Explain your reasoning clearly
✅ Acknowledge uncertainty when data is limited
✅ Highlight value bets where odds seem favorable

$predictionsInfo

${researchContext != null ? '''
## 🔴 LIVE RESEARCH DATA
$researchContext
''' : ''}

## CONVERSATION HISTORY
$conversationHistory

## USER MESSAGE
$userMessage

---
Respond as the Sports AI Predictor. Be insightful, data-driven, and engaging.
Use the structured format above for predictions. Keep responses focused and actionable.
''';

    // Get dynamic max_tokens based on model
    final maxTokens = await AISettingsService.getMaxTokensForModel(model, ref);

    String response;
    if (provider == 'openrouter') {
      final service = OpenRouterService(apiKey: apiKey);
      response = await service.generateContent(prompt,
          model: model, maxTokens: maxTokens);
    } else {
      final service = GeminiService(apiKey: apiKey);
      response = await service.generateContent(prompt,
          model: model, maxTokens: maxTokens);
    }

    return response;
  }

  void clearChat() {
    state = PredictorChatState(predictionsContext: state.predictionsContext);
  }
}
