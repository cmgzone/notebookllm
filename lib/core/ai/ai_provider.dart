import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'gemini_service.dart';
import 'openrouter_service.dart';
import 'ai_settings_service.dart';
import '../security/global_credentials_service.dart';

enum AIStatus { idle, loading, success, error }

enum ChatStyle { standard, tutor, deepDive, concise, creative }

class AINotifier extends StateNotifier<AIState> {
  AINotifier(this.ref) : super(AIState());
  final Ref ref;
  final GeminiService _geminiService = GeminiService();
  final OpenRouterService _openRouterService = OpenRouterService();

  Future<String> _getSelectedProvider() async {
    // Get the selected model first
    final model = await AISettingsService.getModel();

    if (model != null && model.isNotEmpty) {
      // Auto-detect provider from the model
      return await AISettingsService.getProviderForModel(model, ref);
    }

    // Fallback to saved provider if no model selected
    return await AISettingsService.getProvider();
  }

  Future<String> _getSelectedModel() async {
    final model = await AISettingsService.getModel();
    if (model == null || model.isEmpty) {
      // Optional: try to get the first available model from provider as last resort?
      // But user asked to remove hardcoded fallbacks.
      // Letting it fail or return empty string might be better if we want to force selection.
      // But existing code expects a string.
      // Let's throw to indicate need for configuration.
      throw Exception(
          'No AI model selected. Please configure a model in settings.');
    }
    return model;
  }

  Future<String?> _getOpenRouterKey() async {
    try {
      final creds = ref.read(globalCredentialsServiceProvider);
      return await creds.getApiKey('openrouter');
    } catch (e) {
      return null;
    }
  }

  Future<String?> _getGeminiKey() async {
    try {
      final creds = ref.read(globalCredentialsServiceProvider);
      return await creds.getApiKey('gemini');
    } catch (e) {
      return null;
    }
  }

  Future<void> generateContent(
    String prompt, {
    List<String> context = const [],
    ChatStyle style = ChatStyle.standard,
    List<AIPromptResponse>? externalHistory,
  }) async {
    state = state.copyWith(status: AIStatus.loading, clearError: true);

    try {
      final provider = await _getSelectedProvider();
      final model = await _getSelectedModel();

      // Build context string with clear delimiters
      final contextText = context.isNotEmpty
          ? context.join('\n\n')
          : "No specific sources provided.";

      // Build history string (last 8 turns for larger context window)
      final historyBuffer = StringBuffer();
      final targetHistory = externalHistory ?? state.history;
      final recentHistory = targetHistory.length > 8
          ? targetHistory.sublist(targetHistory.length - 8)
          : targetHistory;

      if (recentHistory.isNotEmpty) {
        historyBuffer.writeln('--- Conversation History ---');
        for (final item in recentHistory) {
          historyBuffer.writeln('User: ${item.prompt}');
          historyBuffer.writeln('AI: ${item.response}');
        }
        historyBuffer.writeln('--- End History ---');
      }

      // Persona Instructions with enhanced behavioral patterns
      String personaInstruction = '';
      String formattingGuidelines = '';

      switch (style) {
        case ChatStyle.tutor:
          personaInstruction = '''
🎓 **PERSONA: Socratic Tutor**

**Core Philosophy**: Never give answers directly. Guide discovery through questions.

**Behavioral Patterns**:
• Start with "What do you think about..." or "Have you considered..."
• Break complex topics into smaller, digestible questions
• Celebrate partial understanding: "That's a great start! Now consider..."
• Use analogies from everyday life to explain concepts
• Ask "Why?" and "How?" frequently to deepen understanding
• Validate feelings: "It's natural to find this challenging..."

**Response Structure**:
1. Acknowledge the question warmly
2. Ask 1-2 clarifying or probing questions
3. Provide a gentle hint or framework for thinking
4. End with an encouraging follow-up question

**Tone**: Warm, patient, genuinely curious, never condescending''';
          formattingGuidelines = '''
• Use **bold** for key concepts the user should focus on
• Include 💡 for hints and 🤔 for thought-provoking questions
• Keep paragraphs short and digestible''';
          break;

        case ChatStyle.deepDive:
          personaInstruction = '''
🔬 **PERSONA: Research Analyst**

**Core Philosophy**: Leave no stone unturned. Provide comprehensive, scholarly analysis.

**Behavioral Patterns**:
• Begin with a high-level overview before diving deep
• Explore multiple perspectives and interpretations
• Reference specific parts of sources with precision
• Identify patterns, contradictions, and gaps
• Discuss implications, edge cases, and nuances
• Connect ideas across different sources

**Response Structure**:
1. **Executive Summary** (2-3 sentences)
2. **Detailed Analysis** with subheadings
3. **Key Insights** (bullet points)
4. **Considerations & Caveats**
5. **Suggested Deep Dive Topics**

**Tone**: Scholarly, precise, objective, intellectually rigorous''';
          formattingGuidelines = '''
• Use headers (##, ###) to organize sections
• Include bullet points for key findings
• Use > blockquotes when citing sources directly
• Add horizontal rules (---) between major sections''';
          break;

        case ChatStyle.concise:
          personaInstruction = '''
⚡ **PERSONA: Executive Briefer**

**Core Philosophy**: Time is precious. Every word must add value.

**Behavioral Patterns**:
• Lead with the answer, then provide context if needed
• Use bullet points extensively
• Avoid filler words, transitions, and pleasantries
• If it can be said in 10 words, don't use 20
• Prioritize: What? So what? Now what?

**Response Structure**:
1. **TL;DR**: One-sentence answer
2. **Key Points**: 3-5 bullets maximum
3. **Action Item** (if relevant)

**Tone**: Direct, efficient, no-nonsense, respectful''';
          formattingGuidelines = '''
• Bold the most critical information
• Use numbered lists for sequential steps
• Maximum 2-3 sentences per paragraph
• Eliminate all unnecessary words''';
          break;

        case ChatStyle.creative:
          personaInstruction = '''
🎨 **PERSONA: Creative Catalyst**

**Core Philosophy**: Spark imagination. Find unexpected connections.

**Behavioral Patterns**:
• Use vivid metaphors and analogies
• Ask "What if..." and "Imagine..."
• Connect seemingly unrelated ideas
• Suggest unconventional applications
• Encourage experimentation and play
• Celebrate wild ideas before evaluating them

**Response Structure**:
1. An intriguing hook or provocative question
2. Creative exploration with colorful language
3. Unexpected connections or insights
4. An inspiring call to creative action

**Tone**: Enthusiastic, playful, imaginative, inspiring''';
          formattingGuidelines = '''
• Use emojis strategically to add energy 🚀
• Include creative formatting like *italics* for emphasis
• Short, punchy paragraphs that flow like a conversation
• End with an inspiring question or creative prompt''';
          break;

        case ChatStyle.standard:
          personaInstruction = '''
🤖 **PERSONA: Intelligent Notebook Companion**

**Core Philosophy**: Be genuinely helpful, clear, and engaging.

**Behavioral Patterns**:
• Understand the question fully before responding
• Provide context-appropriate depth
• Anticipate follow-up questions
• Be conversational but informative
• Admit uncertainty when appropriate
• Suggest related topics proactively

**Response Structure**:
1. Clear, direct answer to the question
2. Supporting details or context
3. Relevant examples from sources
4. Helpful follow-up suggestion

**Tone**: Friendly, knowledgeable, balanced, genuinely helpful''';
          formattingGuidelines = '''
• Use **bold** for emphasis on key terms
• Include bullet points for lists
• Keep a conversational but organized flow
• Use emojis sparingly for warmth''';
          break;
      }

      // Construct optimized conversational prompt with enhanced guidelines
      final fullPrompt = '''
═══════════════════════════════════════════════════════════
                    SYSTEM CONFIGURATION
═══════════════════════════════════════════════════════════

$personaInstruction

═══════════════════════════════════════════════════════════
                    RESPONSE GUIDELINES
═══════════════════════════════════════════════════════════

**Source Integration**:
• PRIORITIZE the user's notes/sources as primary truth
• When using sources: "Based on your notes on [Topic]..." or "Your [Source Name] mentions..."
• When going beyond sources: "While not in your notes, here's additional insight..."
• Never fabricate source content

**Formatting Requirements**:
$formattingGuidelines

**Quality Standards**:
• Be accurate - never make up information
• Be specific - avoid vague generalities
• Be actionable - give practical value
• Be engaging - make learning enjoyable
• Be structured - organize for easy scanning

**Engagement**:
• End with a thought-provoking question, insight, or suggested exploration
• Make the user feel their notes are valuable and well-organized

═══════════════════════════════════════════════════════════
                    USER'S NOTEBOOK CONTEXT
═══════════════════════════════════════════════════════════

$contextText

═══════════════════════════════════════════════════════════
                    CONVERSATION HISTORY
═══════════════════════════════════════════════════════════

$historyBuffer

═══════════════════════════════════════════════════════════
                    CURRENT USER QUERY
═══════════════════════════════════════════════════════════

$prompt

═══════════════════════════════════════════════════════════
                    YOUR RESPONSE
═══════════════════════════════════════════════════════════
''';

      final String response;
      if (provider == 'openrouter') {
        final apiKey = await _getOpenRouterKey();
        response = await _openRouterService.generateContent(
          fullPrompt,
          model: model,
          apiKey: apiKey,
        );
      } else {
        // Use Gemini
        final apiKey = await _getGeminiKey();
        response = await _geminiService.generateContent(
          fullPrompt,
          model: model,
          apiKey: apiKey,
        );
      }

      state = state.copyWith(
        status: AIStatus.success,
        lastResponse: response,
        history: [
          ...state.history,
          AIPromptResponse(prompt: prompt, response: response)
        ],
      );
    } catch (e) {
      state = state.copyWith(
        status: AIStatus.error,
        error: e.toString(),
      );
    }
  }

  Future<void> generateStream(String prompt) async {
    state = state.copyWith(status: AIStatus.loading, clearError: true);
    try {
      final provider = await _getSelectedProvider();
      final model = await _getSelectedModel();

      final String aggregated;
      if (provider == 'openrouter') {
        final apiKey = await _getOpenRouterKey();
        // OpenRouter streaming returns a Stream, but we need String for now
        // Convert stream to full string
        final stream = await _openRouterService.generateStream(
          prompt,
          model: model,
          apiKey: apiKey,
        );
        final buffer = StringBuffer();
        await for (final chunk in stream) {
          buffer.write(chunk);
        }
        aggregated = buffer.toString();
      } else {
        final apiKey = await _getGeminiKey();
        aggregated = await _geminiService.generateStream(prompt,
            model: model, apiKey: apiKey);
      }

      state = state.copyWith(
        status: AIStatus.success,
        lastResponse: aggregated,
        history: [
          ...state.history,
          AIPromptResponse(prompt: prompt, response: aggregated)
        ],
      );
    } catch (e) {
      state = state.copyWith(status: AIStatus.error, error: e.toString());
    }
  }

  Future<Map<String, dynamic>> improveNote(String noteText,
      {String title = 'Improved Note'}) async {
    try {
      final provider = await _getSelectedProvider();
      final model = await _getSelectedModel();

      final prompt = '''
Please improve the following note by:
1. Fixing grammar and spelling
2. Improving clarity and structure
3. Enhancing readability
4. Maintaining the original meaning

Note Title: $title
Note Content:
$noteText

Return the improved note in a clear, well-structured format.
''';

      final String improved;
      if (provider == 'openrouter') {
        final apiKey = await _getOpenRouterKey();
        improved = await _openRouterService.generateContent(
          prompt,
          model: model,
          apiKey: apiKey,
        );
      } else {
        final apiKey = await _getGeminiKey();
        improved = await _geminiService.generateContent(prompt,
            model: model, apiKey: apiKey);
      }

      return {
        'success': true,
        'title': title,
        'content': improved,
      };
    } catch (e) {
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }

  Future<Map<String, dynamic>> moderate(String content,
      {double strictness = 0.5, String inputType = 'text'}) async {
    try {
      final provider = await _getSelectedProvider();
      final model = await _getSelectedModel();

      final prompt = '''
Analyze the following $inputType content for:
1. Inappropriate language or hate speech
2. Spam or promotional content
3. Harmful or dangerous information
4. Personal information that should be redacted

Strictness level: ${(strictness * 10).toInt()}/10

Content:
$content

Respond in JSON format with:
{
  "safe": true/false,
  "issues": ["list of issues found"],
  "severity": "low/medium/high",
  "recommendation": "action to take"
}
''';

      final String response;
      if (provider == 'openrouter') {
        final apiKey = await _getOpenRouterKey();
        response = await _openRouterService.generateContent(
          prompt,
          model: model,
          apiKey: apiKey,
        );
      } else {
        final apiKey = await _getGeminiKey();
        response = await _geminiService.generateContent(prompt,
            model: model, apiKey: apiKey);
      }

      // Try to parse JSON response
      try {
        final jsonStart = response.indexOf('{');
        final jsonEnd = response.lastIndexOf('}') + 1;
        if (jsonStart >= 0 && jsonEnd > jsonStart) {
          final jsonStr = response.substring(jsonStart, jsonEnd);
          return {
            'success': true,
            'moderation': jsonStr,
          };
        }
      } catch (_) {}

      // Fallback if JSON parsing fails
      return {
        'success': true,
        'moderation': response,
      };
    } catch (e) {
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }

  void clearHistory() {
    state = state.copyWith(history: []);
  }

  void clearError() {
    state = state.copyWith(clearError: true);
  }
}

class AIState {
  final AIStatus status;
  final String? lastResponse;
  final String? error;
  final List<AIPromptResponse> history;

  AIState({
    this.status = AIStatus.idle,
    this.lastResponse,
    this.error,
    this.history = const [],
  });

  AIState copyWith({
    AIStatus? status,
    String? lastResponse,
    String? error,
    bool clearError = false,
    List<AIPromptResponse>? history,
  }) {
    return AIState(
      status: status ?? this.status,
      lastResponse: lastResponse ?? this.lastResponse,
      error: clearError ? null : (error ?? this.error),
      history: history ?? this.history,
    );
  }
}

class AIPromptResponse {
  final String prompt;
  final String response;
  final DateTime timestamp;

  AIPromptResponse({
    required this.prompt,
    required this.response,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();
}

final aiProvider = StateNotifierProvider<AINotifier, AIState>((ref) {
  return AINotifier(ref);
});
