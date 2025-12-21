import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import '../../core/services/feature_tour_service.dart';

/// Animated feature tour that showcases all app features
class FeatureTourScreen extends ConsumerStatefulWidget {
  const FeatureTourScreen({super.key});

  @override
  ConsumerState<FeatureTourScreen> createState() => _FeatureTourScreenState();
}

class _FeatureTourScreenState extends ConsumerState<FeatureTourScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  final List<_TourFeature> _features = const [
    _TourFeature(
      title: 'Welcome to NotebookLLM',
      description:
          'Your AI-powered learning companion. Let\'s explore what you can do!',
      icon: Icons.auto_awesome,
      color: Color(0xFF6366F1),
      gradient: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
    ),
    _TourFeature(
      title: 'Smart Notebooks',
      description:
          'Create notebooks to organize your sources. Add PDFs, web pages, YouTube videos, and more.',
      icon: Icons.folder_special,
      color: Color(0xFF10B981),
      gradient: [Color(0xFF10B981), Color(0xFF34D399)],
    ),
    _TourFeature(
      title: 'AI Chat',
      description:
          'Chat with your sources! Ask questions and get answers grounded in your content.',
      icon: Icons.chat_bubble_outline,
      color: Color(0xFF3B82F6),
      gradient: [Color(0xFF3B82F6), Color(0xFF60A5FA)],
    ),
    _TourFeature(
      title: 'Studio Artifacts',
      description:
          'Generate study guides, FAQs, timelines, and executive briefs from your sources.',
      icon: Icons.auto_stories,
      color: Color(0xFFF59E0B),
      gradient: [Color(0xFFF59E0B), Color(0xFFFBBF24)],
    ),
    _TourFeature(
      title: 'Voice Mode',
      description:
          'Talk to your AI assistant! Use voice commands and get spoken responses.',
      icon: Icons.mic,
      color: Color(0xFFEC4899),
      gradient: [Color(0xFFEC4899), Color(0xFFF472B6)],
    ),
    _TourFeature(
      title: 'Deep Research',
      description:
          'Let AI conduct comprehensive research on any topic with web search integration.',
      icon: Icons.science,
      color: Color(0xFF8B5CF6),
      gradient: [Color(0xFF8B5CF6), Color(0xFFA78BFA)],
    ),
    _TourFeature(
      title: 'Ebook Creator',
      description:
          'Generate complete ebooks with AI agents handling research, writing, and design.',
      icon: Icons.menu_book,
      color: Color(0xFF14B8A6),
      gradient: [Color(0xFF14B8A6), Color(0xFF2DD4BF)],
    ),
    _TourFeature(
      title: 'Audio Overview',
      description:
          'Create podcast-style audio summaries of your content with AI narration.',
      icon: Icons.headphones,
      color: Color(0xFFEF4444),
      gradient: [Color(0xFFEF4444), Color(0xFFF87171)],
    ),
    _TourFeature(
      title: 'You\'re All Set!',
      description:
          'Start by creating a notebook and adding your first source. Happy learning!',
      icon: Icons.rocket_launch,
      color: Color(0xFF6366F1),
      gradient: [Color(0xFF6366F1), Color(0xFFEC4899)],
    ),
  ];

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _nextPage() {
    if (_currentPage < _features.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
      );
    } else {
      _completeTour();
    }
  }

  void _completeTour() async {
    await featureTourService.completeTour();
    if (mounted) {
      context.go('/home');
    }
  }

  void _skipTour() async {
    await featureTourService.completeTour();
    if (mounted) {
      context.go('/home');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Animated background
          AnimatedContainer(
            duration: const Duration(milliseconds: 500),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: _features[_currentPage].gradient,
              ),
            ),
          ),

          // Content
          SafeArea(
            child: Column(
              children: [
                // Skip button
                Align(
                  alignment: Alignment.topRight,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: TextButton(
                      onPressed: _skipTour,
                      child: const Text(
                        'Skip',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ),
                ),

                // Page view
                Expanded(
                  child: PageView.builder(
                    controller: _pageController,
                    onPageChanged: (index) {
                      setState(() => _currentPage = index);
                    },
                    itemCount: _features.length,
                    itemBuilder: (context, index) {
                      return _FeaturePage(feature: _features[index]);
                    },
                  ),
                ),

                // Page indicators
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(
                      _features.length,
                      (index) => AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        width: _currentPage == index ? 24 : 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: _currentPage == index
                              ? Colors.white
                              : Colors.white38,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                  ),
                ),

                // Next/Get Started button
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
                  child: SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      onPressed: _nextPage,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: _features[_currentPage].color,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        elevation: 0,
                      ),
                      child: Text(
                        _currentPage == _features.length - 1
                            ? 'Get Started'
                            : 'Next',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TourFeature {
  final String title;
  final String description;
  final IconData icon;
  final Color color;
  final List<Color> gradient;

  const _TourFeature({
    required this.title,
    required this.description,
    required this.icon,
    required this.color,
    required this.gradient,
  });
}

class _FeaturePage extends StatelessWidget {
  final _TourFeature feature;

  const _FeaturePage({required this.feature});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Animated icon
          Container(
            width: 140,
            height: 140,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: Icon(
              feature.icon,
              size: 70,
              color: Colors.white,
            ),
          )
              .animate(onPlay: (c) => c.repeat(reverse: true))
              .scale(
                begin: const Offset(1, 1),
                end: const Offset(1.1, 1.1),
                duration: 2.seconds,
                curve: Curves.easeInOut,
              )
              .shimmer(
                duration: 2.seconds,
                color: Colors.white24,
              ),

          const SizedBox(height: 48),

          // Title
          Text(
            feature.title,
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
            textAlign: TextAlign.center,
          ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.3),

          const SizedBox(height: 16),

          // Description
          Text(
            feature.description,
            style: TextStyle(
              fontSize: 16,
              color: Colors.white.withValues(alpha: 0.9),
              height: 1.5,
            ),
            textAlign: TextAlign.center,
          )
              .animate()
              .fadeIn(duration: 400.ms, delay: 200.ms)
              .slideY(begin: 0.3),
        ],
      ),
    );
  }
}
