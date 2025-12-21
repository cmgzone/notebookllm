import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../core/api/api_service.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  List<OnboardingPage> _pages = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadPages();
  }

  Future<void> _loadPages() async {
    try {
      final dbScreens =
          await ref.read(apiServiceProvider).getOnboardingScreens();

      if (dbScreens.isNotEmpty) {
        setState(() {
          _pages = dbScreens
              .map((data) => OnboardingPage(
                    title: data['title'] ?? '',
                    description: data['description'] ?? '',
                    imageUrl: data['image_url'] ?? '',
                    icon: _getIconByName(data['icon_name']),
                  ))
              .toList();
          _isLoading = false;
        });
      } else {
        _useDefaultPages();
      }
    } catch (e) {
      debugPrint('Error loading onboarding screens: $e');
      _useDefaultPages();
    }
  }

  void _useDefaultPages() {
    setState(() {
      _pages = [
        OnboardingPage(
          title: 'Welcome to Notebook AI',
          description:
              'Your intelligent companion for organizing, understanding, and creating knowledge from any source.',
          imageUrl:
              'https://trae-api-sg.mchost.guru/api/ide/v1/text_to_image?prompt=A%20beautiful%20minimalist%20illustration%20of%20a%20premium%20notebook%20with%20glowing%20AI%20elements%2C%20elegant%20design%2C%20modern%20aesthetic%2C%20soft%20gradient%20background%2C%20professional%20and%20clean%20style&image_size=portrait_4_3',
          icon: Icons.auto_awesome,
        ),
        OnboardingPage(
          title: 'Add Your Sources',
          description:
              'Upload PDFs, paste text, or add web links. Our AI will analyze and organize your content intelligently.',
          imageUrl:
              'https://trae-api-sg.mchost.guru/api/ide/v1/text_to_image?prompt=A%20modern%20mobile%20interface%20showing%20document%20upload%20with%20PDF%20files%2C%20text%20snippets%2C%20and%20web%20links%20floating%20elegantly%2C%20premium%20UI%20design%2C%20soft%20blue%20gradient%20background%2C%20minimalist%20style&image_size=portrait_4_3',
          icon: Icons.upload_file,
        ),
        OnboardingPage(
          title: 'Chat with Your Knowledge',
          description:
              'Ask questions about your sources and get instant, contextual answers with citations.',
          imageUrl:
              'https://trae-api-sg.mchost.guru/api/ide/v1/text_to_image?prompt=A%20premium%20chat%20interface%20with%20AI%20assistant%2C%20elegant%20message%20bubbles%2C%20citations%20and%20references%20floating%20around%2C%20modern%20design%2C%20soft%20purple%20gradient%2C%20professional%20aesthetic&image_size=portrait_4_3',
          icon: Icons.chat_bubble_outline,
        ),
        OnboardingPage(
          title: 'Create Amazing Content',
          description:
              'Generate study guides, briefs, FAQs, timelines, and audio overviews from your knowledge base.',
          imageUrl:
              'https://trae-api-sg.mchost.guru/api/ide/v1/text_to_image?prompt=A%20premium%20studio%20workspace%20with%20study%20guides%2C%20documents%2C%20audio%20waveforms%2C%20and%20creative%20tools%2C%20elegant%20layout%2C%20soft%20gradient%20background%2C%20modern%20professional%20design&image_size=portrait_4_3',
          icon: Icons.create,
        ),
        OnboardingPage(
          title: 'Ready to Start',
          description:
              'Your AI-powered notebook is ready. Let\'s organize your knowledge and unlock new insights!',
          imageUrl:
              'https://trae-api-sg.mchost.guru/api/ide/v1/text_to_image?prompt=A%20premium%20mobile%20app%20launch%20screen%2C%20elegant%20checkmark%20or%20completion%20symbol%2C%20soft%20green%20gradient%20background%2C%20modern%20minimalist%20design%2C%20professional%20and%20clean%20style&image_size=portrait_4_3',
          icon: Icons.rocket_launch,
        ),
      ];
      _isLoading = false;
    });
  }

  IconData _getIconByName(String? name) {
    switch (name) {
      case 'upload_file':
        return Icons.upload_file;
      case 'chat_bubble_outline':
        return Icons.chat_bubble_outline;
      case 'create':
        return Icons.create;
      case 'rocket_launch':
        return Icons.rocket_launch;
      case 'auto_awesome':
        return Icons.auto_awesome;
      case 'school':
        return Icons.school;
      case 'book':
        return Icons.book;
      case 'lightbulb':
        return Icons.lightbulb;
      default:
        return Icons.auto_awesome;
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _onPageChanged(int page) {
    setState(() {
      _currentPage = page;
    });
  }

  void _nextPage() {
    if (_currentPage < _pages.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOut,
      );
    } else {
      _finishOnboarding();
    }
  }

  void _skipOnboarding() {
    _finishOnboarding();
  }

  void _finishOnboarding() {
    // Navigate to completion screen
    context.go('/onboarding-completion');
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    return Scaffold(
      body: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.light.copyWith(
          statusBarColor: Colors.transparent,
          systemNavigationBarColor: scheme.surface,
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Skip button
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: _skipOnboarding,
                  child: Text(
                    'Skip',
                    style: text.bodyMedium?.copyWith(
                      color: scheme.onSurface.withValues(alpha: 0.6),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ).animate().fadeIn(delay: 500.ms),

              // Page content
              Expanded(
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : PageView.builder(
                        controller: _pageController,
                        itemCount: _pages.length,
                        onPageChanged: _onPageChanged,
                        itemBuilder: (context, index) {
                          final page = _pages[index];
                          return _buildPage(page, scheme, text);
                        },
                      ),
              ),

              // Page indicators
              // Hide indicators if loading
              if (!_isLoading)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(
                      _pages.length,
                      (index) => Container(
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        width: _currentPage == index ? 24 : 8,
                        height: 8,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(4),
                          color: _currentPage == index
                              ? scheme.primary
                              : scheme.onSurface.withValues(alpha: 0.3),
                        ),
                      )
                          .animate()
                          .scale(duration: 300.ms, curve: Curves.easeOut),
                    ),
                  ),
                ),

              // Action button
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
                child: SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: _nextPage,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: scheme.primary,
                      foregroundColor: scheme.onPrimary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      elevation: 4,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          _currentPage == _pages.length - 1
                              ? 'Get Started'
                              : 'Next',
                          style: text.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: scheme.onPrimary,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Icon(
                          _currentPage == _pages.length - 1
                              ? Icons.check
                              : Icons.arrow_forward,
                          color: scheme.onPrimary,
                        ),
                      ],
                    ),
                  ).animate().slideY(begin: 0.2, delay: 300.ms).fadeIn(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPage(OnboardingPage page, ColorScheme scheme, TextTheme text) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Icon badge
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: scheme.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(24),
            ),
            child: Icon(
              page.icon,
              size: 48,
              color: scheme.primary,
            ),
          ).animate().scale(duration: 600.ms, curve: Curves.easeOut),

          const SizedBox(height: 32),

          // Title
          Text(
            page.title,
            style: text.headlineMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: scheme.onSurface,
            ),
            textAlign: TextAlign.center,
          ).animate().slideY(begin: 0.2, delay: 100.ms).fadeIn(),

          const SizedBox(height: 16),

          // Description
          Text(
            page.description,
            style: text.bodyLarge?.copyWith(
              color: scheme.onSurface.withValues(alpha: 0.7),
              height: 1.5,
            ),
            textAlign: TextAlign.center,
          ).animate().slideY(begin: 0.2, delay: 200.ms).fadeIn(),

          const SizedBox(height: 48),

          // Generated image
          Container(
            height: 240,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: scheme.primary.withValues(alpha: 0.2),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: Image.network(
                page.imageUrl,
                fit: BoxFit.cover,
                width: double.infinity,
                loadingBuilder: (context, child, loadingProgress) {
                  if (loadingProgress == null) return child;
                  return Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          scheme.primary.withValues(alpha: 0.1),
                          scheme.secondary.withValues(alpha: 0.1),
                        ],
                      ),
                    ),
                    child: Center(
                      child: CircularProgressIndicator(
                        value: loadingProgress.expectedTotalBytes != null
                            ? loadingProgress.cumulativeBytesLoaded /
                                loadingProgress.expectedTotalBytes!
                            : null,
                        color: scheme.primary,
                      ),
                    ),
                  );
                },
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          scheme.primary.withValues(alpha: 0.1),
                          scheme.secondary.withValues(alpha: 0.1),
                        ],
                      ),
                    ),
                    child: Center(
                      child: Icon(
                        page.icon,
                        size: 64,
                        color: scheme.primary.withValues(alpha: 0.5),
                      ),
                    ),
                  );
                },
              ),
            ),
          ).animate().slideY(begin: 0.3, delay: 300.ms).fadeIn(),
        ],
      ),
    );
  }
}

class OnboardingPage {
  final String title;
  final String description;
  final String imageUrl;
  final IconData icon;

  OnboardingPage({
    required this.title,
    required this.description,
    required this.imageUrl,
    required this.icon,
  });
}
