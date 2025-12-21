import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import '../../core/ai/context_engineering_service.dart';
import '../../core/audio/universal_tts_service.dart';
import '../sources/source_provider.dart';
import '../notebook/notebook_provider.dart';

class ContextProfileScreen extends ConsumerStatefulWidget {
  const ContextProfileScreen({super.key});

  @override
  ConsumerState<ContextProfileScreen> createState() =>
      _ContextProfileScreenState();
}

class _ContextProfileScreenState extends ConsumerState<ContextProfileScreen> {
  bool _isBuilding = false;
  double _progress = 0.0;
  String _status = '';
  UserContextProfile? _profile;
  List<String>? _recommendations;

  @override
  void initState() {
    super.initState();
    _loadExistingProfile();
  }

  Future<void> _loadExistingProfile() async {
    final service = ref.read(contextEngineeringServiceProvider);
    final profile = await service.loadContextProfile('current_user');
    if (profile != null && mounted) {
      setState(() {
        _profile = profile;
      });
    }
  }

  Future<void> _buildContextProfile() async {
    setState(() {
      _isBuilding = true;
      _progress = 0.0;
      _status = 'Initializing...';
    });

    try {
      final service = ref.read(contextEngineeringServiceProvider);
      final activities = await _gatherUserActivities();

      await for (final update in service.buildUserContext(
        userId: 'current_user',
        activities: activities,
        deepSearch: true,
      )) {
        if (!mounted) break;
        setState(() {
          _progress = update.progress;
          _status = update.status;
          if (update.contextProfile != null) {
            _profile = update.contextProfile;
          }
        });
      }

      if (_profile != null) {
        // Save profile
        await service.saveContextProfile(_profile!);

        // Generate recommendations
        final recs =
            await service.generatePersonalizedRecommendations(_profile!);
        setState(() {
          _recommendations = recs;
        });
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error building profile: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isBuilding = false;
        });
      }
    }
  }

  Future<List<UserActivity>> _gatherUserActivities() async {
    final activities = <UserActivity>[];

    try {
      // Gather notebook activities
      final notebooks = ref.read(notebookProvider);
      for (final notebook in notebooks) {
        activities.add(UserActivity(
          type: 'notebook_created',
          description: 'Created notebook: ${notebook.title}',
          content: notebook.description,
          timestamp: notebook.createdAt,
        ));
      }

      // Gather source activities
      final sources = ref.read(sourceProvider);
      for (final source in sources.take(50)) {
        activities.add(UserActivity(
          type: source.type,
          description: 'Added ${source.type}: ${source.title}',
          content: source.content.length > 500
              ? source.content.substring(0, 500)
              : source.content,
          timestamp: source.addedAt,
        ));
      }

      // Sort by timestamp (most recent first)
      activities.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    } catch (e) {
      debugPrint('[ContextProfile] Error gathering activities: $e');
    }

    return activities;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0E27),
      appBar: AppBar(
        title: const Text(
          'User Context Profile',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        backgroundColor: const Color(0xFF1A1F3A),
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: _isBuilding
          ? _buildLoadingView()
          : _profile == null
              ? _buildEmptyView()
              : _buildProfileView(),
      floatingActionButton: _isBuilding
          ? null
          : FloatingActionButton.extended(
              onPressed: _buildContextProfile,
              backgroundColor: const Color(0xFF6C5CE7),
              icon: const Icon(Icons.psychology, color: Colors.white),
              label: Text(
                _profile == null ? 'Build Profile' : 'Rebuild Profile',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
    );
  }

  Widget _buildLoadingView() {
    return Center(
      child: Container(
        padding: const EdgeInsets.all(32),
        margin: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: const Color(0xFF1A1F3A),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF6C5CE7).withValues(alpha: 0.3),
              blurRadius: 20,
              spreadRadius: 2,
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: 120,
                  height: 120,
                  child: CircularProgressIndicator(
                    value: _progress,
                    strokeWidth: 8,
                    valueColor: const AlwaysStoppedAnimation(Color(0xFF6C5CE7)),
                    backgroundColor: const Color(0xFF2D3250),
                  ),
                ),
                Text(
                  '${(_progress * 100).toInt()}%',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            const Icon(
              Icons.psychology,
              color: Color(0xFF6C5CE7),
              size: 48,
            ),
            const SizedBox(height: 16),
            Text(
              _status,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 16,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyView() {
    return Center(
      child: Container(
        padding: const EdgeInsets.all(32),
        margin: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: const Color(0xFF1A1F3A),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: const Color(0xFF6C5CE7).withValues(alpha: 0.2),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.psychology,
                size: 64,
                color: Color(0xFF6C5CE7),
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'No Context Profile',
              style: TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Build a comprehensive AI-powered\nprofile to personalize your experience',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white70,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'The Context Engineering Agent will:\n'
              '• Analyze your behavior patterns\n'
              '• Identify your interests\n'
              '• Build a knowledge graph\n'
              '• Perform deep research\n'
              '• Predict future interests\n'
              '• Generate recommendations',
              textAlign: TextAlign.left,
              style: TextStyle(
                color: Colors.white60,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileView() {
    if (_profile == null) return const SizedBox();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildProfileHeader(),
          const SizedBox(height: 16),
          _buildBehaviorCard(),
          const SizedBox(height: 16),
          _buildInterestsCard(),
          const SizedBox(height: 16),
          _buildKnowledgeGraphCard(),
          const SizedBox(height: 16),
          _buildTemporalPatternsCard(),
          const SizedBox(height: 16),
          _buildPredictionsCard(),
          const SizedBox(height: 16),
          if (_recommendations != null) _buildRecommendationsCard(),
          if (_recommendations != null) const SizedBox(height: 16),
          _buildSummaryCard(),
          const SizedBox(height: 80),
        ],
      ),
    );
  }

  Widget _buildProfileHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF6C5CE7), Color(0xFF5348C7)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF6C5CE7).withValues(alpha: 0.3),
            blurRadius: 15,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.psychology,
              size: 40,
              color: Colors.white,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Context Profile',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Generated ${_formatDateTime(_profile!.generatedAt)}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBehaviorCard() {
    final behavior = _profile!.behaviorProfile;
    return _buildCard(
      title: 'Behavior Profile',
      icon: Icons.person_outline,
      color: const Color(0xFF00B894),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildInfoRow('Engagement', behavior.engagementLevel),
          _buildInfoRow('Learning Style', behavior.learningStyle),
          _buildInfoRow('Complexity', behavior.complexityPreference),
          _buildInfoRow('Interaction', behavior.interactionStyle),
          const SizedBox(height: 12),
          if (behavior.primaryBehaviors.isNotEmpty) ...[
            const Text(
              'Primary Behaviors:',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: behavior.primaryBehaviors
                  .map((b) => _buildChip(b, const Color(0xFF00B894)))
                  .toList(),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildInterestsCard() {
    final interests = _profile!.interests;
    return _buildCard(
      title: 'Interest Themes',
      icon: Icons.interests,
      color: const Color(0xFFFF7675),
      child: Column(
        children: interests.take(5).map((interest) {
          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        interest.topic,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    Text(
                      '${(interest.confidence * 100).toInt()}%',
                      style: const TextStyle(
                        color: Color(0xFFFF7675),
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                LinearProgressIndicator(
                  value: interest.confidence,
                  backgroundColor: const Color(0xFF2D3250),
                  valueColor: const AlwaysStoppedAnimation(Color(0xFFFF7675)),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    _buildSmallChip(interest.category, const Color(0xFFFF7675)),
                    _buildSmallChip(interest.depth, const Color(0xFFFF7675)),
                    ...interest.keywords.take(3).map(
                        (k) => _buildSmallChip(k, const Color(0xFFFF7675))),
                  ],
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildKnowledgeGraphCard() {
    final graph = _profile!.knowledgeGraph;
    return _buildCard(
      title: 'Knowledge Graph',
      icon: Icons.hub,
      color: const Color(0xFF74B9FF),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (graph.centralThemes.isNotEmpty) ...[
            const Text(
              'Central Themes:',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: graph.centralThemes
                  .map((t) => _buildChip(t, const Color(0xFF74B9FF)))
                  .toList(),
            ),
          ],
          if (graph.knowledgeGaps.isNotEmpty) ...[
            const SizedBox(height: 16),
            const Text(
              'Knowledge Gaps:',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: graph.knowledgeGaps
                  .map((g) => _buildChip(g, const Color(0xFFFDCB6E)))
                  .toList(),
            ),
          ],
          if (graph.nodes.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text(
              '${graph.nodes.length} nodes, ${graph.edges.length} connections',
              style: const TextStyle(
                color: Colors.white60,
                fontSize: 12,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTemporalPatternsCard() {
    final patterns = _profile!.temporalPatterns;
    return _buildCard(
      title: 'Temporal Patterns',
      icon: Icons.schedule,
      color: const Color(0xFFA29BFE),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildInfoRow('Activity Trend', patterns.activityTrend),
          _buildInfoRow(
            'Avg Session',
            '${patterns.averageSessionDuration.inMinutes} min',
          ),
          const SizedBox(height: 12),
          const Text(
            'Peak Hours:',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: patterns.peakHours
                .map((h) => _buildChip(h, const Color(0xFFA29BFE)))
                .toList(),
          ),
          const SizedBox(height: 12),
          const Text(
            'Peak Days:',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: patterns.peakDays
                .map((d) => _buildChip(d, const Color(0xFFA29BFE)))
                .toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildPredictionsCard() {
    final predictions = _profile!.predictions;
    if (predictions.isEmpty) return const SizedBox();

    return _buildCard(
      title: 'Interest Predictions',
      icon: Icons.trending_up,
      color: const Color(0xFFFD79A8),
      child: Column(
        children: predictions.map((pred) {
          return Container(
            margin: const EdgeInsets.only(bottom: 16),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF2D3250),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        pred.topic,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    _buildSmallChip(pred.timeFrame, const Color(0xFFFD79A8)),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  pred.reasoning,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 8),
                LinearProgressIndicator(
                  value: pred.confidence,
                  backgroundColor: const Color(0xFF1A1F3A),
                  valueColor: const AlwaysStoppedAnimation(Color(0xFFFD79A8)),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildRecommendationsCard() {
    if (_recommendations == null || _recommendations!.isEmpty) {
      return const SizedBox();
    }

    return _buildCard(
      title: 'Personalized Recommendations',
      icon: Icons.recommend,
      color: const Color(0xFF55EFC4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: _recommendations!.asMap().entries.map((entry) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 24,
                  height: 24,
                  decoration: const BoxDecoration(
                    color: Color(0xFF55EFC4),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      '${entry.key + 1}',
                      style: const TextStyle(
                        color: Color(0xFF0A0E27),
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    entry.value,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                    ),
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildSummaryCard() {
    return _buildCard(
      title: 'Profile Summary',
      icon: Icons.summarize,
      color: const Color(0xFF6C5CE7),
      ttsText: _profile!.summary,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFF0A0E27),
          borderRadius: BorderRadius.circular(8),
        ),
        child: MarkdownBody(
          data: _profile!.summary,
          styleSheet: MarkdownStyleSheet(
            p: const TextStyle(color: Colors.white70, fontSize: 14),
            h1: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
            h2: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
            h3: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
            listBullet: const TextStyle(color: Color(0xFF6C5CE7)),
            strong: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCard({
    required String title,
    required IconData icon,
    required Color color,
    required Widget child,
    String? ttsText,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1F3A),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: color.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 24),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    color: color,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              if (ttsText != null && ttsText.isNotEmpty)
                TTSButton(
                  text: ttsText,
                  mini: true,
                  color: color,
                  tooltip: 'Listen to $title',
                ),
            ],
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Text(
            '$label:',
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 14,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.5), width: 1),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildSmallChip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11,
        ),
      ),
    );
  }

  String _formatDateTime(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);

    if (diff.inMinutes < 1) return 'just now';
    if (diff.inHours < 1) return '${diff.inMinutes}m ago';
    if (diff.inDays < 1) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${dt.day}/${dt.month}/${dt.year}';
  }
}
