import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../ai/gemini_service.dart';
import '../ai/gemini_image_service.dart';
import '../../features/sources/source_provider.dart';
import '../../features/notebook/notebook_provider.dart';
import '../../core/security/global_credentials_service.dart';
import '../../features/ebook/ebook_provider.dart';
import '../../features/ebook/models/ebook_project.dart';
import '../../features/ebook/models/branding_config.dart';
import 'package:uuid/uuid.dart';

final voiceActionHandlerProvider = Provider<VoiceActionHandler>((ref) {
  return VoiceActionHandler(ref);
});

class VoiceActionResult {
  final String response;
  final bool actionPerformed;
  final String? actionType;
  final String? imageUrl;

  VoiceActionResult({
    required this.response,
    this.actionPerformed = false,
    this.actionType,
    this.imageUrl,
  });
}

class VoiceActionHandler {
  final Ref ref;
  VoiceActionHandler(this.ref);

  Future<GeminiService> _getGeminiService() async {
    final creds = ref.read(globalCredentialsServiceProvider);
    final apiKey = await creds.getApiKey('gemini');
    if (apiKey == null || apiKey.isEmpty) {
      throw Exception('Gemini API key not found');
    }
    return GeminiService(apiKey: apiKey);
  }

  Future<GeminiImageService> _getImageService() async {
    final creds = ref.read(globalCredentialsServiceProvider);
    final apiKey = await creds.getApiKey('gemini');
    if (apiKey == null || apiKey.isEmpty) {
      throw Exception('Gemini API key not found');
    }
    return GeminiImageService(apiKey: apiKey);
  }

  Future<VoiceActionResult> processUserInput(
    String userText,
    List<String> conversationHistory,
  ) async {
    final intent = await _detectIntent(userText);

    switch (intent['action']) {
      case 'create_note':
        return await _createNote(userText, intent);
      case 'search_sources':
        return await _searchSources(userText, intent);
      case 'list_sources':
        return await _listSources();
      case 'create_notebook':
        return await _createNotebook(userText, intent);
      case 'list_notebooks':
        return await _listNotebooks();
      case 'get_summary':
        return await _getSummary();
      case 'generate_image':
        return await _generateImage(userText, intent);
      case 'create_ebook':
        return await _createEbook(userText, intent);
      default:
        return await _handleConversation(userText, conversationHistory);
    }
  }

  Future<Map<String, dynamic>> _detectIntent(String userText) async {
    final prompt = '''
Analyze this user request and determine the intent. Return ONLY a JSON object.

User request: "$userText"

Possible actions:
- create_note: User wants to save/create/write a note
- search_sources: User wants to search or query their sources
- list_sources: User wants to see their sources
- create_notebook: User wants to create a new notebook
- list_notebooks: User wants to see their notebooks
- get_summary: User wants a summary of their content
- generate_image: User wants to create/generate an image
- create_ebook: User wants to create/write/generate an ebook
- conversation: Just normal conversation

Return format:
{
  "action": "action_name",
  "title": "extracted title if creating something",
  "content": "extracted content if creating something",
  "query": "search query if searching"
}
''';

    try {
      final gemini = await _getGeminiService();
      final response = await gemini.generateContent(prompt);
      final jsonMatch = RegExp(r'\{[\s\S]*\}').firstMatch(response);
      if (jsonMatch != null) {
        return jsonDecode(jsonMatch.group(0)!);
      }
    } catch (e) {
      // If parsing fails, default to conversation
    }

    return {'action': 'conversation'};
  }

  Future<VoiceActionResult> _createNote(
    String userText,
    Map<String, dynamic> intent,
  ) async {
    try {
      final title = intent['title'] as String? ?? 'Voice Note';
      final content = intent['content'] as String? ?? userText;

      await ref.read(sourceProvider.notifier).addSource(
            title: title,
            type: 'text',
            content: content,
          );

      return VoiceActionResult(
        response: 'I\'ve saved your note titled "$title" to your sources.',
        actionPerformed: true,
        actionType: 'create_note',
      );
    } catch (e) {
      return VoiceActionResult(
        response: 'Sorry, I couldn\'t save the note. Please try again.',
        actionPerformed: false,
      );
    }
  }

  Future<VoiceActionResult> _searchSources(
    String userText,
    Map<String, dynamic> intent,
  ) async {
    try {
      final query = intent['query'] as String? ?? userText;
      final sources = ref.read(sourceProvider);

      final matches = sources.where((source) {
        final searchText = '${source.title} ${source.content}'.toLowerCase();
        return searchText.contains(query.toLowerCase());
      }).toList();

      if (matches.isEmpty) {
        return VoiceActionResult(
          response: 'I couldn\'t find any sources matching "$query".',
          actionPerformed: true,
          actionType: 'search_sources',
        );
      }

      final summary = matches.take(3).map((s) => s.title).join(', ');
      return VoiceActionResult(
        response:
            'I found ${matches.length} sources. The top matches are: $summary',
        actionPerformed: true,
        actionType: 'search_sources',
      );
    } catch (e) {
      return VoiceActionResult(
        response: 'Sorry, I had trouble searching your sources.',
        actionPerformed: false,
      );
    }
  }

  Future<VoiceActionResult> _listSources() async {
    try {
      final sources = ref.read(sourceProvider);

      if (sources.isEmpty) {
        return VoiceActionResult(
          response: 'You don\'t have any sources yet.',
          actionPerformed: true,
          actionType: 'list_sources',
        );
      }

      final count = sources.length;
      final types = sources.map((s) => s.type).toSet();

      return VoiceActionResult(
        response:
            'You have $count sources including ${types.join(', ')} types.',
        actionPerformed: true,
        actionType: 'list_sources',
      );
    } catch (e) {
      return VoiceActionResult(
        response: 'Sorry, I couldn\'t retrieve your sources.',
        actionPerformed: false,
      );
    }
  }

  Future<VoiceActionResult> _createNotebook(
    String userText,
    Map<String, dynamic> intent,
  ) async {
    try {
      final title = intent['title'] as String? ?? 'New Notebook';

      await ref.read(notebookProvider.notifier).addNotebook(title);

      return VoiceActionResult(
        response: 'I\'ve created a new notebook called "$title".',
        actionPerformed: true,
        actionType: 'create_notebook',
      );
    } catch (e) {
      return VoiceActionResult(
        response: 'Sorry, I couldn\'t create the notebook.',
        actionPerformed: false,
      );
    }
  }

  Future<VoiceActionResult> _listNotebooks() async {
    try {
      final notebooks = ref.read(notebookProvider);

      if (notebooks.isEmpty) {
        return VoiceActionResult(
          response: 'You don\'t have any notebooks yet.',
          actionPerformed: true,
          actionType: 'list_notebooks',
        );
      }

      final names = notebooks.take(5).map((n) => n.title).join(', ');
      return VoiceActionResult(
        response:
            'You have ${notebooks.length} notebooks. Here are some: $names',
        actionPerformed: true,
        actionType: 'list_notebooks',
      );
    } catch (e) {
      return VoiceActionResult(
        response: 'Sorry, I couldn\'t retrieve your notebooks.',
        actionPerformed: false,
      );
    }
  }

  Future<VoiceActionResult> _getSummary() async {
    try {
      final sources = ref.read(sourceProvider);

      if (sources.isEmpty) {
        return VoiceActionResult(
          response: 'You don\'t have any sources to summarize yet.',
          actionPerformed: true,
          actionType: 'get_summary',
        );
      }

      final recentSources = sources.take(5).toList();
      final context = recentSources
          .map((s) =>
              '${s.title}: ${s.content.substring(0, s.content.length > 200 ? 200 : s.content.length)}')
          .join('\n\n');

      final summaryPrompt = '''
Provide a brief spoken summary of these sources in 2-3 sentences:

$context
''';

      final gemini = await _getGeminiService();
      final summary = await gemini.generateContent(summaryPrompt);

      return VoiceActionResult(
        response: summary,
        actionPerformed: true,
        actionType: 'get_summary',
      );
    } catch (e) {
      return VoiceActionResult(
        response: 'Sorry, I couldn\'t generate a summary.',
        actionPerformed: false,
      );
    }
  }

  Future<VoiceActionResult> _handleConversation(
    String userText,
    List<String> conversationHistory,
  ) async {
    try {
      final gemini = await _getGeminiService();
      final response = await gemini.generateContentWithContext(
        userText,
        [
          'You are a helpful AI voice assistant for a notebook app.',
          'Keep responses concise and conversational.',
          'No markdown formatting - this will be spoken aloud.',
          ...conversationHistory.take(10),
        ],
      );

      return VoiceActionResult(
        response: response,
        actionPerformed: false,
      );
    } catch (e) {
      return VoiceActionResult(
        response: 'Sorry, I didn\'t catch that. Could you try again?',
        actionPerformed: false,
      );
    }
  }

  Future<VoiceActionResult> _generateImage(
    String userText,
    Map<String, dynamic> intent,
  ) async {
    try {
      final prompt = intent['content'] as String? ?? userText;

      // Use Gemini to enhance the prompt for better image generation
      final gemini = await _getGeminiService();
      final enhancedPrompt = await gemini.generateContent('''
Convert this user request into a detailed, vivid image generation prompt (max 2 sentences):
"$prompt"

Return only the enhanced prompt, nothing else.
''');

      // Generate image using Gemini Imagen
      final imageGen = await _getImageService();
      final imageUrl = await imageGen.generateImage(enhancedPrompt.trim());

      return VoiceActionResult(
        response: 'I\'ve generated your image!',
        actionPerformed: true,
        actionType: 'generate_image',
        imageUrl: imageUrl,
      );
    } catch (e) {
      return VoiceActionResult(
        response: 'Sorry, I couldn\'t generate the image. ${e.toString()}',
        actionPerformed: false,
      );
    }
  }

  Future<VoiceActionResult> _createEbook(
    String userText,
    Map<String, dynamic> intent,
  ) async {
    try {
      final title = intent['title'] as String? ?? 'New Ebook';
      final topic = intent['content'] as String? ?? 'General Topic';

      final prefs = await SharedPreferences.getInstance();
      final currentModel = prefs.getString('ai_model') ?? 'gemini-1.5-flash';

      final id = const Uuid().v4();
      final now = DateTime.now();
      final ebook = EbookProject(
        id: id,
        title: title,
        topic: topic,
        targetAudience: 'General Audience',
        branding: const BrandingConfig(
          primaryColorValue: 0xFF000000,
          fontFamily: 'Roboto',
        ),
        selectedModel: currentModel,
        createdAt: now,
        updatedAt: now,
        status: EbookStatus.draft,
      );

      await ref.read(ebookProvider.notifier).addEbook(ebook);

      return VoiceActionResult(
        response:
            'I\'ve created a new ebook project titled "$title" about "$topic".',
        actionPerformed: true,
        actionType: 'create_ebook',
      );
    } catch (e) {
      return VoiceActionResult(
        response: 'Sorry, I couldn\'t create the ebook.',
        actionPerformed: false,
      );
    }
  }
}
