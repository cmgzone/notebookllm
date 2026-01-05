import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

/// Time Context Service
/// Provides current date/time information to reduce AI hallucinations
/// and help with planning accurate timelines.
class TimeContextService {
  /// Get comprehensive time context for AI prompts
  String getTimeContext() {
    final now = DateTime.now();
    final utcNow = now.toUtc();

    return '''
**Current Date & Time Context:**
- Local Date: ${DateFormat('EEEE, MMMM d, yyyy').format(now)}
- Local Time: ${DateFormat('h:mm a').format(now)}
- UTC Time: ${DateFormat('yyyy-MM-dd HH:mm:ss').format(utcNow)} UTC
- Timezone: ${now.timeZoneName} (UTC${now.timeZoneOffset.isNegative ? '' : '+'}${now.timeZoneOffset.inHours}:${(now.timeZoneOffset.inMinutes % 60).toString().padLeft(2, '0')})
- Week Number: ${_getWeekNumber(now)}
- Quarter: Q${((now.month - 1) ~/ 3) + 1} ${now.year}
- Days Until End of Month: ${_daysUntilEndOfMonth(now)}
- Days Until End of Year: ${_daysUntilEndOfYear(now)}
''';
  }

  /// Get short time context (for inline use)
  String getShortTimeContext() {
    final now = DateTime.now();
    return 'Today is ${DateFormat('EEEE, MMMM d, yyyy').format(now)} at ${DateFormat('h:mm a').format(now)}';
  }

  /// Get current date in ISO format
  String getCurrentDateISO() {
    return DateTime.now().toIso8601String();
  }

  /// Get current year
  int getCurrentYear() => DateTime.now().year;

  /// Get current month
  int getCurrentMonth() => DateTime.now().month;

  /// Get current quarter
  int getCurrentQuarter() => ((DateTime.now().month - 1) ~/ 3) + 1;

  /// Calculate days between two dates
  int daysBetween(DateTime from, DateTime to) {
    return to.difference(from).inDays;
  }

  /// Get deadline context for planning
  String getDeadlineContext(DateTime deadline) {
    final now = DateTime.now();
    final daysUntil = deadline.difference(now).inDays;
    final hoursUntil = deadline.difference(now).inHours;

    String urgency;
    if (daysUntil < 0) {
      urgency = '⚠️ OVERDUE by ${-daysUntil} days';
    } else if (daysUntil == 0) {
      urgency = '🔴 DUE TODAY ($hoursUntil hours remaining)';
    } else if (daysUntil <= 3) {
      urgency = '🟠 URGENT: $daysUntil days remaining';
    } else if (daysUntil <= 7) {
      urgency = '🟡 Due this week: $daysUntil days remaining';
    } else if (daysUntil <= 30) {
      urgency = '🟢 Due in $daysUntil days';
    } else {
      urgency = '📅 Due in ${(daysUntil / 7).round()} weeks';
    }

    return '''
**Deadline: ${DateFormat('EEEE, MMMM d, yyyy').format(deadline)}**
$urgency
''';
  }

  /// Get sprint/iteration context
  String getSprintContext({int sprintLengthDays = 14}) {
    final now = DateTime.now();
    final startOfYear = DateTime(now.year, 1, 1);
    final dayOfYear = now.difference(startOfYear).inDays;
    final currentSprint = (dayOfYear ~/ sprintLengthDays) + 1;
    final daysIntoSprint = dayOfYear % sprintLengthDays;
    final daysRemainingInSprint = sprintLengthDays - daysIntoSprint;

    return '''
**Sprint Context ($sprintLengthDays-day sprints):**
- Current Sprint: Sprint $currentSprint
- Days into Sprint: $daysIntoSprint
- Days Remaining: $daysRemainingInSprint
''';
  }

  /// Get technology version context (helps with dependency recommendations)
  Map<String, String> getRecommendedVersions() {
    // These should be updated periodically or fetched from web
    // For now, provide reasonable defaults that can be overridden by web search
    return {
      'flutter': '3.24.x (stable)',
      'dart': '3.5.x',
      'node': '20.x LTS or 22.x',
      'python': '3.12.x',
      'react': '18.x',
      'typescript': '5.x',
      'note': 'Use web search to verify latest stable versions',
    };
  }

  int _getWeekNumber(DateTime date) {
    final firstDayOfYear = DateTime(date.year, 1, 1);
    final dayOfYear = date.difference(firstDayOfYear).inDays;
    return ((dayOfYear - date.weekday + 10) / 7).floor();
  }

  int _daysUntilEndOfMonth(DateTime date) {
    final lastDayOfMonth = DateTime(date.year, date.month + 1, 0);
    return lastDayOfMonth.day - date.day;
  }

  int _daysUntilEndOfYear(DateTime date) {
    final lastDayOfYear = DateTime(date.year, 12, 31);
    return lastDayOfYear.difference(date).inDays;
  }
}

final timeContextServiceProvider = Provider((ref) => TimeContextService());
