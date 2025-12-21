import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Service to manage feature tour/walkthrough
class FeatureTourService {
  static const String _hasSeenTourKey = 'has_seen_feature_tour';
  static const String _tourVersionKey = 'feature_tour_version';
  static const int _currentTourVersion = 1;

  /// Check if user has seen the current tour version
  Future<bool> hasSeenTour() async {
    final prefs = await SharedPreferences.getInstance();
    final hasSeen = prefs.getBool(_hasSeenTourKey) ?? false;
    final seenVersion = prefs.getInt(_tourVersionKey) ?? 0;
    return hasSeen && seenVersion >= _currentTourVersion;
  }

  /// Mark tour as completed
  Future<void> completeTour() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_hasSeenTourKey, true);
    await prefs.setInt(_tourVersionKey, _currentTourVersion);
  }

  /// Reset tour (for testing or showing again)
  Future<void> resetTour() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_hasSeenTourKey, false);
  }
}

/// Global instance
final featureTourService = FeatureTourService();

/// Provider
final featureTourServiceProvider = Provider((ref) => featureTourService);

/// Feature tour data model
class TourStep {
  final GlobalKey key;
  final String title;
  final String description;
  final IconData icon;
  final Color color;

  const TourStep({
    required this.key,
    required this.title,
    required this.description,
    required this.icon,
    required this.color,
  });
}

/// Custom showcase tooltip widget
class TourTooltip extends StatelessWidget {
  final String title;
  final String description;
  final IconData icon;
  final Color color;
  final VoidCallback? onNext;
  final VoidCallback? onSkip;
  final bool isLast;

  const TourTooltip({
    super.key,
    required this.title,
    required this.description,
    required this.icon,
    required this.color,
    this.onNext,
    this.onSkip,
    this.isLast = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.3),
            blurRadius: 20,
            spreadRadius: 5,
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            description,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[700],
              height: 1.5,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              if (!isLast)
                TextButton(
                  onPressed: onSkip,
                  child: Text(
                    'Skip Tour',
                    style: TextStyle(color: Colors.grey[500]),
                  ),
                )
              else
                const SizedBox(),
              ElevatedButton(
                onPressed: onNext,
                style: ElevatedButton.styleFrom(
                  backgroundColor: color,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(isLast ? 'Get Started!' : 'Next'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
