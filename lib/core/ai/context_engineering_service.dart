import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'gemini_service.dart';
import 'openrouter_service.dart';
import 'deep_research_service.dart';
import 'ai_settings_service.dart';
import '../search/serper_service.dart';
import '../security/global_credentials_service.dart';

final contextEngineeringServiceProvider =
    Provider<ContextEngineeringService>((ref) {
  final geminiService = GeminiService();
  final openRouterService = OpenRouterService();
  final serperService = SerperService(ref);
  return ContextEngineeringService(
    ref,
    geminiService,
    openRouterService,
    serperService,
  );
});

/// Context Engineering AI Agent that builds comprehensive user profiles
/// using deep search and multi-dimensional analysis
class ContextEngineeringService {
  final Ref ref;
  final GeminiService _geminiService;
  final OpenRouterService _openRouterService;
  final SerperService _serperService;

  ContextEngineeringService(
    this.ref,
    this._geminiService,
    this._openRouterService,
    this._serperService,
  );

  Future<String> _getSelectedProvider() async {
    // Get the selected model first
    final model = await AISettingsService.getModel();

    if (model != null && model.isNotEmpty) {
      // Auto-detect provider from the model
      return await AISettingsService.getProviderForModel(model, ref);
    }

    // Fallback to saved provider if no model selected
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('ai_provider') ?? 'gemini';
  }

  Future<String> _getSelectedModel() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('ai_model') ?? 'gemini-2.0-flash-exp';
  }

  Future<String?> _getGeminiKey() async {
    try {
      final creds = ref.read(globalCredentialsServiceProvider);
      return await creds.getApiKey('gemini');
    } catch (e) {
      return null;
    }
  }

  Future<String?> _getOpenRouterKey() async {
    try {
      final creds = ref.read(globalCredentialsServiceProvider);
      return await creds.getApiKey('openrouter');
    } catch (e) {
      return null;
    }
  }

  Future<String> _generateContent(String prompt, {int? maxTokens}) async {
    final provider = await _getSelectedProvider();
    final model = await _getSelectedModel();

    // Get dynamic max_tokens based on model's context window if not specified
    final effectiveMaxTokens =
        maxTokens ?? await AISettingsService.getMaxTokensForModel(model, ref);

    try {
      if (provider == 'openrouter') {
        final apiKey = await _getOpenRouterKey();
        return await _openRouterService
            .generateContent(
              prompt,
              model: model,
              apiKey: apiKey,
              maxTokens: effectiveMaxTokens,
            )
            .timeout(const Duration(seconds: 60));
      } else {
        final apiKey = await _getGeminiKey();
        return await _geminiService
            .generateContent(
              prompt,
              model: model,
              apiKey: apiKey,
              maxTokens: effectiveMaxTokens,
            )
            .timeout(const Duration(seconds: 60));
      }
    } catch (e) {
      debugPrint(
          '[ContextEngineering] _generateContent timed out or failed: $e');
      rethrow;
    }
  }

  /// Build comprehensive user context profile through deep analysis
  Stream<ContextEngineeringUpdate> buildUserContext({
    required String userId,
    required List<UserActivity> activities,
    bool deepSearch = true,
  }) async* {
    try {
      yield ContextEngineeringUpdate(
        'Initializing context analysis...',
        0.05,
      );

      // Step 1: Analyze user activities and extract patterns
      yield ContextEngineeringUpdate(
        'Analyzing user behavior patterns...',
        0.1,
      );
      final behaviorProfile = await _analyzeBehaviorPatterns(activities);

      // Step 2: Extract interest themes
      yield ContextEngineeringUpdate(
        'Identifying interest themes...',
        0.2,
      );
      final interests = await _extractInterestThemes(activities);

      // Step 3: Build knowledge graph
      yield ContextEngineeringUpdate(
        'Building knowledge graph...',
        0.3,
      );
      final knowledgeGraph = await _buildKnowledgeGraph(activities, interests);

      // Step 4: Deep search for user interests (if enabled)
      Map<String, DeepSearchResult> deepSearchResults = {};
      if (deepSearch && interests.isNotEmpty) {
        int searchCount = 0;
        final topInterests = interests.take(3).toList();

        for (final interest in topInterests) {
          yield ContextEngineeringUpdate(
            'Deep searching: "${interest.topic}"...',
            0.4 + (0.3 * (searchCount / topInterests.length)),
          );

          try {
            final searchResult = await _performDeepSearch(interest);
            deepSearchResults[interest.topic] = searchResult;
          } catch (e) {
            debugPrint(
                '[ContextEngineering] Deep search error for ${interest.topic}: $e');
          }
          searchCount++;
        }
      }

      // Step 5: Analyze temporal patterns
      yield ContextEngineeringUpdate(
        'Analyzing temporal patterns...',
        0.75,
      );
      final temporalPatterns = await _analyzeTemporalPatterns(activities);

      // Step 6: Predict future interests
      yield ContextEngineeringUpdate(
        'Predicting future interests...',
        0.85,
      );
      final predictions = await _predictFutureInterests(
        behaviorProfile,
        interests,
        temporalPatterns,
      );

      // Step 7: Synthesize comprehensive context profile
      yield ContextEngineeringUpdate(
        'Synthesizing context profile...',
        0.95,
      );
      final contextProfile = await _synthesizeContextProfile(
        userId: userId,
        behaviorProfile: behaviorProfile,
        interests: interests,
        knowledgeGraph: knowledgeGraph,
        deepSearchResults: deepSearchResults,
        temporalPatterns: temporalPatterns,
        predictions: predictions,
      );

      yield ContextEngineeringUpdate(
        'Context engineering complete!',
        1.0,
        contextProfile: contextProfile,
      );
    } catch (e) {
      debugPrint('[ContextEngineering] Error: $e');
      rethrow;
    }
  }

  /// Analyze user behavior patterns
  Future<BehaviorProfile> _analyzeBehaviorPatterns(
    List<UserActivity> activities,
  ) async {
    final activitiesSummary = activities.take(50).map((a) {
      return '${a.type}: ${a.description} (${a.timestamp})';
    }).join('\n');

    final prompt = '''
Analyze the following user activities and identify behavioral patterns:

Activities:
$activitiesSummary

Provide a JSON analysis with:
{
  "engagement_level": "low|medium|high",
  "primary_behaviors": ["list of main behaviors"],
  "interaction_style": "description of how user interacts",
  "learning_style": "visual|auditory|kinesthetic|reading",
  "focus_areas": ["main areas of focus"],
  "complexity_preference": "simple|moderate|advanced"
}
''';

    try {
      final response = await _generateContent(prompt, maxTokens: 2048);
      final jsonMatch = RegExp(r'\{[\s\S]*\}').firstMatch(response);
      if (jsonMatch != null) {
        final jsonData = json.decode(jsonMatch.group(0)!);
        return BehaviorProfile.fromJson(jsonData);
      }
    } catch (e) {
      debugPrint('[ContextEngineering] Behavior analysis error: $e');
    }

    return BehaviorProfile.empty();
  }

  /// Extract interest themes from user activities
  Future<List<InterestTheme>> _extractInterestThemes(
    List<UserActivity> activities,
  ) async {
    final contentSample = activities
        .where((a) => a.content != null && a.content!.isNotEmpty)
        .take(30)
        .map((a) => a.content)
        .join('\n\n');

    final prompt = '''
Extract interest themes from the following user content and activities:

Content:
${contentSample.isNotEmpty ? contentSample : 'Limited content available'}

Activity types: ${activities.map((a) => a.type).toSet().join(', ')}

Provide a JSON array of interest themes:
[
  {
    "topic": "topic name",
    "confidence": 0.0-1.0,
    "category": "category",
    "keywords": ["related", "keywords"],
    "depth": "beginner|intermediate|advanced"
  }
]

Return at least 3-5 themes, ordered by confidence.
''';

    try {
      final response = await _generateContent(prompt, maxTokens: 3072);
      final jsonMatch = RegExp(r'\[[\s\S]*\]').firstMatch(response);
      if (jsonMatch != null) {
        final List<dynamic> jsonData = json.decode(jsonMatch.group(0)!);
        return jsonData.map((item) => InterestTheme.fromJson(item)).toList();
      }
    } catch (e) {
      debugPrint('[ContextEngineering] Interest extraction error: $e');
    }

    return [];
  }

  /// Build knowledge graph of user's domain knowledge
  Future<KnowledgeGraph> _buildKnowledgeGraph(
    List<UserActivity> activities,
    List<InterestTheme> interests,
  ) async {
    final interestsSummary = interests.map((i) => i.topic).join(', ');
    final activitiesSummary = activities
        .take(20)
        .map((a) => '${a.type}: ${a.description}')
        .join('\n');

    final prompt = '''
Build a knowledge graph representing the user's domain knowledge:

User Interests: $interestsSummary

Recent Activities:
$activitiesSummary

Provide a JSON knowledge graph:
{
  "nodes": [
    {"id": "node_id", "label": "concept", "type": "domain|skill|interest"}
  ],
  "edges": [
    {"from": "node_id", "to": "node_id", "relationship": "relates_to|requires|explores"}
  ],
  "central_themes": ["main themes"],
  "knowledge_gaps": ["identified gaps in knowledge"]
}
''';

    try {
      final response = await _generateContent(prompt, maxTokens: 4096);
      final jsonMatch = RegExp(r'\{[\s\S]*\}').firstMatch(response);
      if (jsonMatch != null) {
        final jsonData = json.decode(jsonMatch.group(0)!);
        return KnowledgeGraph.fromJson(jsonData);
      }
    } catch (e) {
      debugPrint('[ContextEngineering] Knowledge graph error: $e');
    }

    return KnowledgeGraph.empty();
  }

  /// Perform deep search for specific interest
  Future<DeepSearchResult> _performDeepSearch(InterestTheme interest) async {
    debugPrint('[ContextEngineering] Deep searching: ${interest.topic}');

    final searchResults = <ResearchSource>[];
    final relatedConcepts = <String>[];

    try {
      // Search for topic
      final items = await _serperService.search(interest.topic, num: 5);

      for (final item in items.take(3)) {
        try {
          final content = await _serperService.fetchPageContent(item.link);
          searchResults.add(ResearchSource(
            title: item.title,
            url: item.link,
            content:
                content.length > 1000 ? content.substring(0, 1000) : content,
            snippet: item.snippet,
          ));
        } catch (e) {
          debugPrint('[ContextEngineering] Failed to fetch ${item.link}: $e');
        }
      }

      // Extract related concepts
      if (searchResults.isNotEmpty) {
        final contentSample = searchResults
            .take(2)
            .map((s) => s.content)
            .join('\n\n')
            .substring(0, 1500.clamp(0, searchResults.first.content.length));

        final prompt = '''
Extract 5-7 related concepts from this content about "${interest.topic}":

$contentSample

Return only a comma-separated list of related concepts.
''';

        final response = await _generateContent(prompt, maxTokens: 512);
        relatedConcepts.addAll(
          response.split(',').map((c) => c.trim()).where((c) => c.isNotEmpty),
        );
      }
    } catch (e) {
      debugPrint('[ContextEngineering] Deep search error: $e');
    }

    return DeepSearchResult(
      topic: interest.topic,
      sources: searchResults,
      relatedConcepts: relatedConcepts,
      timestamp: DateTime.now(),
    );
  }

  /// Analyze temporal patterns in user behavior
  Future<TemporalPatterns> _analyzeTemporalPatterns(
    List<UserActivity> activities,
  ) async {
    final activitiesByTime = <String, int>{};
    final activitiesByDay = <String, int>{};

    for (final activity in activities) {
      final hour = activity.timestamp.hour;
      final hourKey = '${hour.toString().padLeft(2, '0')}:00';
      activitiesByTime[hourKey] = (activitiesByTime[hourKey] ?? 0) + 1;

      final dayKey = _getDayName(activity.timestamp.weekday);
      activitiesByDay[dayKey] = (activitiesByDay[dayKey] ?? 0) + 1;
    }

    final peakHours = activitiesByTime.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final peakDays = activitiesByDay.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return TemporalPatterns(
      peakHours: peakHours.take(3).map((e) => e.key).toList(),
      peakDays: peakDays.take(3).map((e) => e.key).toList(),
      activityTrend: _calculateTrend(activities),
      averageSessionDuration: _calculateAverageSessionDuration(activities),
    );
  }

  String _getDayName(int weekday) {
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return days[weekday - 1];
  }

  String _calculateTrend(List<UserActivity> activities) {
    if (activities.length < 7) return 'stable';

    final recent = activities.take(7).length;
    final older = activities.skip(7).take(7).length;

    if (recent > older * 1.2) return 'increasing';
    if (recent < older * 0.8) return 'decreasing';
    return 'stable';
  }

  Duration _calculateAverageSessionDuration(List<UserActivity> activities) {
    if (activities.isEmpty) return Duration.zero;

    // Simple heuristic: group activities within 30 minutes as same session
    final sessions = <Duration>[];
    DateTime? sessionStart;
    DateTime? lastActivity;

    for (final activity in activities.reversed) {
      if (sessionStart == null) {
        sessionStart = activity.timestamp;
        lastActivity = activity.timestamp;
      } else if (lastActivity!.difference(activity.timestamp).inMinutes > 30) {
        sessions.add(lastActivity.difference(sessionStart));
        sessionStart = activity.timestamp;
        lastActivity = activity.timestamp;
      } else {
        lastActivity = activity.timestamp;
      }
    }

    if (sessionStart != null && lastActivity != null) {
      sessions.add(lastActivity.difference(sessionStart));
    }

    if (sessions.isEmpty) return Duration.zero;

    final totalMinutes = sessions.fold<int>(
      0,
      (sum, duration) => sum + duration.inMinutes,
    );

    return Duration(minutes: totalMinutes ~/ sessions.length);
  }

  /// Predict future interests based on current patterns
  Future<List<InterestPrediction>> _predictFutureInterests(
    BehaviorProfile behavior,
    List<InterestTheme> currentInterests,
    TemporalPatterns temporalPatterns,
  ) async {
    final interestsSummary = currentInterests
        .take(5)
        .map((i) => '${i.topic} (${i.confidence.toStringAsFixed(2)})')
        .join(', ');

    final prompt = '''
Predict future interests based on current user profile:

Current Interests: $interestsSummary
Engagement Level: ${behavior.engagementLevel}
Learning Style: ${behavior.learningStyle}
Complexity Preference: ${behavior.complexityPreference}
Activity Trend: ${temporalPatterns.activityTrend}

Provide 3-5 predicted future interests as JSON:
[
  {
    "topic": "predicted interest",
    "reasoning": "why this prediction",
    "confidence": 0.0-1.0,
    "time_frame": "short_term|medium_term|long_term"
  }
]
''';

    try {
      final response = await _generateContent(prompt, maxTokens: 2048);
      final jsonMatch = RegExp(r'\[[\s\S]*\]').firstMatch(response);
      if (jsonMatch != null) {
        final List<dynamic> jsonData = json.decode(jsonMatch.group(0)!);
        return jsonData
            .map((item) => InterestPrediction.fromJson(item))
            .toList();
      }
    } catch (e) {
      debugPrint('[ContextEngineering] Prediction error: $e');
    }

    return [];
  }

  /// Synthesize comprehensive context profile
  Future<UserContextProfile> _synthesizeContextProfile({
    required String userId,
    required BehaviorProfile behaviorProfile,
    required List<InterestTheme> interests,
    required KnowledgeGraph knowledgeGraph,
    required Map<String, DeepSearchResult> deepSearchResults,
    required TemporalPatterns temporalPatterns,
    required List<InterestPrediction> predictions,
  }) async {
    final interestsSummary = interests.map((i) => i.topic).join(', ');
    final deepSearchSummary = deepSearchResults.entries
        .map((e) => '${e.key}: ${e.value.sources.length} sources, '
            '${e.value.relatedConcepts.length} concepts')
        .join('\n');

    final prompt = '''
Create a comprehensive user context profile summary:

User ID: $userId

Behavior Profile:
- Engagement: ${behaviorProfile.engagementLevel}
- Learning Style: ${behaviorProfile.learningStyle}
- Complexity: ${behaviorProfile.complexityPreference}
- Primary Behaviors: ${behaviorProfile.primaryBehaviors.join(', ')}

Interests: $interestsSummary

Knowledge Graph:
- Central Themes: ${knowledgeGraph.centralThemes.join(', ')}
- Knowledge Gaps: ${knowledgeGraph.knowledgeGaps.join(', ')}

Deep Search Results:
$deepSearchSummary

Temporal Patterns:
- Peak Hours: ${temporalPatterns.peakHours.join(', ')}
- Peak Days: ${temporalPatterns.peakDays.join(', ')}
- Trend: ${temporalPatterns.activityTrend}

Predicted Interests: ${predictions.map((p) => p.topic).join(', ')}

Provide a detailed markdown summary that:
1. Describes the user's profile comprehensively
2. Highlights key strengths and knowledge areas
3. Identifies learning opportunities
4. Suggests personalized content recommendations
5. Outlines engagement strategies

Make it insightful, actionable, and personalized.
''';

    final summary = await _generateContent(prompt, maxTokens: 4096);

    return UserContextProfile(
      userId: userId,
      behaviorProfile: behaviorProfile,
      interests: interests,
      knowledgeGraph: knowledgeGraph,
      deepSearchResults: deepSearchResults,
      temporalPatterns: temporalPatterns,
      predictions: predictions,
      summary: summary,
      generatedAt: DateTime.now(),
    );
  }

  /// Generate personalized recommendations based on context profile
  Future<List<String>> generatePersonalizedRecommendations(
    UserContextProfile profile,
  ) async {
    final prompt = '''
Based on this user context profile, generate 5-7 highly personalized recommendations:

Interests: ${profile.interests.map((i) => i.topic).join(', ')}
Knowledge Gaps: ${profile.knowledgeGraph.knowledgeGaps.join(', ')}
Learning Style: ${profile.behaviorProfile.learningStyle}
Predicted Interests: ${profile.predictions.map((p) => p.topic).join(', ')}

Return recommendations as a simple numbered list.
''';

    final response = await _generateContent(prompt, maxTokens: 1024);
    return response
        .split('\n')
        .where((line) => line.trim().isNotEmpty)
        .map((line) => line.replaceFirst(RegExp(r'^\d+\.\s*'), '').trim())
        .where((line) => line.isNotEmpty)
        .toList();
  }

  /// Save context profile to persistent storage
  Future<void> saveContextProfile(UserContextProfile profile) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final profileJson = profile.toJson();
      await prefs.setString(
        'context_profile_${profile.userId}',
        json.encode(profileJson),
      );
      debugPrint('[ContextEngineering] Profile saved for ${profile.userId}');
    } catch (e) {
      debugPrint('[ContextEngineering] Error saving profile: $e');
    }
  }

  /// Load context profile from persistent storage
  Future<UserContextProfile?> loadContextProfile(String userId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final profileData = prefs.getString('context_profile_$userId');
      if (profileData != null) {
        final jsonData = json.decode(profileData);
        return UserContextProfile.fromJson(jsonData);
      }
    } catch (e) {
      debugPrint('[ContextEngineering] Error loading profile: $e');
    }
    return null;
  }

  /// Analyze a specific research topic to provide deep context
  Future<TopicContextAnalysis> analyzeResearchTopic(String topic) async {
    debugPrint('[ContextEngineering] Analyzing topic context: $topic');

    final prompt = '''
Analyze the following research topic and provide a comprehensive context analysis:

Topic: "$topic"

Provide a JSON analysis with:
{
  "core_concepts": ["list of fundamental concepts required to understand this"],
  "prerequisites": ["what user needs to know before"],
  "complexity_level": "beginner|intermediate|advanced",
  "learning_path": ["detailed step-by-step roadmap to master this, from beginner to advanced"],
  "common_pitfalls": ["specific mistakes and misconceptions to avoid"],
  "related_technologies": ["tools, libraries, frameworks, or technologies often used with this"],
  "industry_standards": ["current best practices and professional standards"],
  "key_thought_leaders": ["names of experts, researchers, or pioneers in this field"],
  "seminal_works": ["important papers, books, or articles that defined this field"],
  "practical_applications": ["real-world use cases and examples"],
  "controversies": ["current debates, open questions, or criticisms"],
  "tools_and_ecosystem": ["specific software, hardware, or platforms used"],
  "mindmap": "mermaid js code for a comprehensive mindmap of this topic, showing hierarchy and relationships"
}
''';

    try {
      // _generateContent already has 60s timeout, so this should complete quickly
      final response = await _generateContent(prompt, maxTokens: 2048);
      final jsonMatch = RegExp(r'\{[\s\S]*\}').firstMatch(response);
      if (jsonMatch != null) {
        final jsonData = json.decode(jsonMatch.group(0)!);
        debugPrint('[ContextEngineering] Topic analysis parsed successfully');
        return TopicContextAnalysis.fromJson(jsonData);
      }
      debugPrint('[ContextEngineering] No JSON found in response');
    } catch (e) {
      debugPrint('[ContextEngineering] Topic analysis error: $e');
    }

    return TopicContextAnalysis.empty();
  }
}

// ============================================================================
// Data Models
// ============================================================================

class ContextEngineeringUpdate {
  final String status;
  final double progress;
  final UserContextProfile? contextProfile;

  ContextEngineeringUpdate(
    this.status,
    this.progress, {
    this.contextProfile,
  });
}

class UserActivity {
  final String type;
  final String description;
  final String? content;
  final DateTime timestamp;
  final Map<String, dynamic>? metadata;

  UserActivity({
    required this.type,
    required this.description,
    this.content,
    required this.timestamp,
    this.metadata,
  });

  Map<String, dynamic> toJson() => {
        'type': type,
        'description': description,
        'content': content,
        'timestamp': timestamp.toIso8601String(),
        'metadata': metadata,
      };

  factory UserActivity.fromJson(Map<String, dynamic> json) => UserActivity(
        type: json['type'],
        description: json['description'],
        content: json['content'],
        timestamp: DateTime.parse(json['timestamp']),
        metadata: json['metadata'],
      );
}

class BehaviorProfile {
  final String engagementLevel;
  final List<String> primaryBehaviors;
  final String interactionStyle;
  final String learningStyle;
  final List<String> focusAreas;
  final String complexityPreference;

  BehaviorProfile({
    required this.engagementLevel,
    required this.primaryBehaviors,
    required this.interactionStyle,
    required this.learningStyle,
    required this.focusAreas,
    required this.complexityPreference,
  });

  factory BehaviorProfile.empty() => BehaviorProfile(
        engagementLevel: 'medium',
        primaryBehaviors: [],
        interactionStyle: 'balanced',
        learningStyle: 'reading',
        focusAreas: [],
        complexityPreference: 'moderate',
      );

  factory BehaviorProfile.fromJson(Map<String, dynamic> json) =>
      BehaviorProfile(
        engagementLevel: json['engagement_level'] ?? 'medium',
        primaryBehaviors: List<String>.from(json['primary_behaviors'] ?? []),
        interactionStyle: json['interaction_style'] ?? 'balanced',
        learningStyle: json['learning_style'] ?? 'reading',
        focusAreas: List<String>.from(json['focus_areas'] ?? []),
        complexityPreference: json['complexity_preference'] ?? 'moderate',
      );

  Map<String, dynamic> toJson() => {
        'engagement_level': engagementLevel,
        'primary_behaviors': primaryBehaviors,
        'interaction_style': interactionStyle,
        'learning_style': learningStyle,
        'focus_areas': focusAreas,
        'complexity_preference': complexityPreference,
      };
}

class InterestTheme {
  final String topic;
  final double confidence;
  final String category;
  final List<String> keywords;
  final String depth;

  InterestTheme({
    required this.topic,
    required this.confidence,
    required this.category,
    required this.keywords,
    required this.depth,
  });

  factory InterestTheme.fromJson(Map<String, dynamic> json) => InterestTheme(
        topic: json['topic'],
        confidence: (json['confidence'] as num).toDouble(),
        category: json['category'] ?? 'general',
        keywords: List<String>.from(json['keywords'] ?? []),
        depth: json['depth'] ?? 'intermediate',
      );

  Map<String, dynamic> toJson() => {
        'topic': topic,
        'confidence': confidence,
        'category': category,
        'keywords': keywords,
        'depth': depth,
      };
}

class KnowledgeGraph {
  final List<KnowledgeNode> nodes;
  final List<KnowledgeEdge> edges;
  final List<String> centralThemes;
  final List<String> knowledgeGaps;

  KnowledgeGraph({
    required this.nodes,
    required this.edges,
    required this.centralThemes,
    required this.knowledgeGaps,
  });

  factory KnowledgeGraph.empty() => KnowledgeGraph(
        nodes: [],
        edges: [],
        centralThemes: [],
        knowledgeGaps: [],
      );

  factory KnowledgeGraph.fromJson(Map<String, dynamic> json) => KnowledgeGraph(
        nodes: (json['nodes'] as List?)
                ?.map((n) => KnowledgeNode.fromJson(n))
                .toList() ??
            [],
        edges: (json['edges'] as List?)
                ?.map((e) => KnowledgeEdge.fromJson(e))
                .toList() ??
            [],
        centralThemes: List<String>.from(json['central_themes'] ?? []),
        knowledgeGaps: List<String>.from(json['knowledge_gaps'] ?? []),
      );

  Map<String, dynamic> toJson() => {
        'nodes': nodes.map((n) => n.toJson()).toList(),
        'edges': edges.map((e) => e.toJson()).toList(),
        'central_themes': centralThemes,
        'knowledge_gaps': knowledgeGaps,
      };
}

class KnowledgeNode {
  final String id;
  final String label;
  final String type;

  KnowledgeNode({required this.id, required this.label, required this.type});

  factory KnowledgeNode.fromJson(Map<String, dynamic> json) => KnowledgeNode(
        id: json['id'],
        label: json['label'],
        type: json['type'] ?? 'concept',
      );

  Map<String, dynamic> toJson() => {'id': id, 'label': label, 'type': type};
}

class KnowledgeEdge {
  final String from;
  final String to;
  final String relationship;

  KnowledgeEdge(
      {required this.from, required this.to, required this.relationship});

  factory KnowledgeEdge.fromJson(Map<String, dynamic> json) => KnowledgeEdge(
        from: json['from'],
        to: json['to'],
        relationship: json['relationship'] ?? 'relates_to',
      );

  Map<String, dynamic> toJson() =>
      {'from': from, 'to': to, 'relationship': relationship};
}

class DeepSearchResult {
  final String topic;
  final List<ResearchSource> sources;
  final List<String> relatedConcepts;
  final DateTime timestamp;

  DeepSearchResult({
    required this.topic,
    required this.sources,
    required this.relatedConcepts,
    required this.timestamp,
  });

  Map<String, dynamic> toJson() => {
        'topic': topic,
        'sources': sources
            .map((s) => {
                  'title': s.title,
                  'url': s.url,
                  'snippet': s.snippet,
                })
            .toList(),
        'related_concepts': relatedConcepts,
        'timestamp': timestamp.toIso8601String(),
      };

  factory DeepSearchResult.fromJson(Map<String, dynamic> json) =>
      DeepSearchResult(
        topic: json['topic'],
        sources: (json['sources'] as List?)
                ?.map((s) => ResearchSource(
                      title: s['title'],
                      url: s['url'],
                      content: '',
                      snippet: s['snippet'],
                    ))
                .toList() ??
            [],
        relatedConcepts: List<String>.from(json['related_concepts'] ?? []),
        timestamp: DateTime.parse(json['timestamp']),
      );
}

class TemporalPatterns {
  final List<String> peakHours;
  final List<String> peakDays;
  final String activityTrend;
  final Duration averageSessionDuration;

  TemporalPatterns({
    required this.peakHours,
    required this.peakDays,
    required this.activityTrend,
    required this.averageSessionDuration,
  });

  Map<String, dynamic> toJson() => {
        'peak_hours': peakHours,
        'peak_days': peakDays,
        'activity_trend': activityTrend,
        'average_session_minutes': averageSessionDuration.inMinutes,
      };

  factory TemporalPatterns.fromJson(Map<String, dynamic> json) =>
      TemporalPatterns(
        peakHours: List<String>.from(json['peak_hours'] ?? []),
        peakDays: List<String>.from(json['peak_days'] ?? []),
        activityTrend: json['activity_trend'] ?? 'stable',
        averageSessionDuration:
            Duration(minutes: json['average_session_minutes'] ?? 0),
      );
}

class InterestPrediction {
  final String topic;
  final String reasoning;
  final double confidence;
  final String timeFrame;

  InterestPrediction({
    required this.topic,
    required this.reasoning,
    required this.confidence,
    required this.timeFrame,
  });

  factory InterestPrediction.fromJson(Map<String, dynamic> json) =>
      InterestPrediction(
        topic: json['topic'],
        reasoning: json['reasoning'] ?? '',
        confidence: (json['confidence'] as num).toDouble(),
        timeFrame: json['time_frame'] ?? 'medium_term',
      );

  Map<String, dynamic> toJson() => {
        'topic': topic,
        'reasoning': reasoning,
        'confidence': confidence,
        'time_frame': timeFrame,
      };
}

class UserContextProfile {
  final String userId;
  final BehaviorProfile behaviorProfile;
  final List<InterestTheme> interests;
  final KnowledgeGraph knowledgeGraph;
  final Map<String, DeepSearchResult> deepSearchResults;
  final TemporalPatterns temporalPatterns;
  final List<InterestPrediction> predictions;
  final String summary;
  final DateTime generatedAt;

  UserContextProfile({
    required this.userId,
    required this.behaviorProfile,
    required this.interests,
    required this.knowledgeGraph,
    required this.deepSearchResults,
    required this.temporalPatterns,
    required this.predictions,
    required this.summary,
    required this.generatedAt,
  });

  Map<String, dynamic> toJson() => {
        'user_id': userId,
        'behavior_profile': behaviorProfile.toJson(),
        'interests': interests.map((i) => i.toJson()).toList(),
        'knowledge_graph': knowledgeGraph.toJson(),
        'deep_search_results': deepSearchResults.map(
          (key, value) => MapEntry(key, value.toJson()),
        ),
        'temporal_patterns': temporalPatterns.toJson(),
        'predictions': predictions.map((p) => p.toJson()).toList(),
        'summary': summary,
        'generated_at': generatedAt.toIso8601String(),
      };

  factory UserContextProfile.fromJson(Map<String, dynamic> json) =>
      UserContextProfile(
        userId: json['user_id'],
        behaviorProfile: BehaviorProfile.fromJson(json['behavior_profile']),
        interests: (json['interests'] as List)
            .map((i) => InterestTheme.fromJson(i))
            .toList(),
        knowledgeGraph: KnowledgeGraph.fromJson(json['knowledge_graph']),
        deepSearchResults: (json['deep_search_results'] as Map<String, dynamic>)
            .map((key, value) =>
                MapEntry(key, DeepSearchResult.fromJson(value))),
        temporalPatterns: TemporalPatterns.fromJson(json['temporal_patterns']),
        predictions: (json['predictions'] as List)
            .map((p) => InterestPrediction.fromJson(p))
            .toList(),
        summary: json['summary'],
        generatedAt: DateTime.parse(json['generated_at']),
      );
}

class TopicContextAnalysis {
  final List<String> coreConcepts;
  final List<String> prerequisites;
  final String complexityLevel;
  final List<String> learningPath;
  final List<String> commonPitfalls;
  final List<String> relatedTechnologies;
  final List<String> industryStandards;
  final List<String> keyThoughtLeaders;
  final List<String> seminalWorks;
  final List<String> practicalApplications;
  final List<String> controversies;
  final List<String> toolsAndEcosystem;
  final String? mindmap;

  TopicContextAnalysis({
    required this.coreConcepts,
    required this.prerequisites,
    required this.complexityLevel,
    required this.learningPath,
    required this.commonPitfalls,
    required this.relatedTechnologies,
    required this.industryStandards,
    required this.keyThoughtLeaders,
    required this.seminalWorks,
    required this.practicalApplications,
    required this.controversies,
    required this.toolsAndEcosystem,
    this.mindmap,
  });

  factory TopicContextAnalysis.empty() => TopicContextAnalysis(
        coreConcepts: [],
        prerequisites: [],
        complexityLevel: 'intermediate',
        learningPath: [],
        commonPitfalls: [],
        relatedTechnologies: [],
        industryStandards: [],
        keyThoughtLeaders: [],
        seminalWorks: [],
        practicalApplications: [],
        controversies: [],
        toolsAndEcosystem: [],
      );

  factory TopicContextAnalysis.fromJson(Map<String, dynamic> json) =>
      TopicContextAnalysis(
        coreConcepts: List<String>.from(json['core_concepts'] ?? []),
        prerequisites: List<String>.from(json['prerequisites'] ?? []),
        complexityLevel: json['complexity_level'] ?? 'intermediate',
        learningPath: List<String>.from(json['learning_path'] ?? []),
        commonPitfalls: List<String>.from(json['common_pitfalls'] ?? []),
        relatedTechnologies:
            List<String>.from(json['related_technologies'] ?? []),
        industryStandards: List<String>.from(json['industry_standards'] ?? []),
        keyThoughtLeaders: List<String>.from(json['key_thought_leaders'] ?? []),
        seminalWorks: List<String>.from(json['seminal_works'] ?? []),
        practicalApplications:
            List<String>.from(json['practical_applications'] ?? []),
        controversies: List<String>.from(json['controversies'] ?? []),
        toolsAndEcosystem: List<String>.from(json['tools_and_ecosystem'] ?? []),
        mindmap: json['mindmap'],
      );

  Map<String, dynamic> toJson() => {
        'core_concepts': coreConcepts,
        'prerequisites': prerequisites,
        'complexity_level': complexityLevel,
        'learning_path': learningPath,
        'common_pitfalls': commonPitfalls,
        'related_technologies': relatedTechnologies,
        'industry_standards': industryStandards,
        'key_thought_leaders': keyThoughtLeaders,
        'seminal_works': seminalWorks,
        'practical_applications': practicalApplications,
        'controversies': controversies,
        'tools_and_ecosystem': toolsAndEcosystem,
        'mindmap': mindmap,
      };
}
