import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// Service to fetch team logos from various sports APIs
class TeamLogoService {
  // Using logo.clearbit.com for company/team logos (free, no API key needed)
  // and thesportsdb.com for sports-specific logos

  static const String _sportsDbBaseUrl =
      'https://www.thesportsdb.com/api/v1/json/3';

  /// Get team logo URL using multiple fallback sources
  static Future<String?> getTeamLogo(String teamName, String sport) async {
    // Try TheSportsDB first (best for sports teams)
    final sportsDbLogo = await _searchSportsDb(teamName, sport);
    if (sportsDbLogo != null) return sportsDbLogo;

    // Fallback to generated avatar with team initials
    return _generateAvatarUrl(teamName);
  }

  /// Search TheSportsDB for team logo
  static Future<String?> _searchSportsDb(String teamName, String sport) async {
    try {
      final encodedName = Uri.encodeComponent(teamName);
      final response = await http
          .get(
            Uri.parse('$_sportsDbBaseUrl/searchteams.php?t=$encodedName'),
          )
          .timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final teams = data['teams'] as List?;

        if (teams != null && teams.isNotEmpty) {
          // Try to find exact or close match
          for (final team in teams) {
            final badge = team['strBadge'] ?? team['strTeamBadge'];
            if (badge != null && badge.toString().isNotEmpty) {
              return badge.toString();
            }
          }
        }
      }
    } catch (e) {
      debugPrint('[TeamLogoService] SportsDB search failed: $e');
    }
    return null;
  }

  /// Generate a UI Avatars URL as fallback
  static String _generateAvatarUrl(String teamName) {
    final initials = _getInitials(teamName);
    final color = _getColorForTeam(teamName);
    return 'https://ui-avatars.com/api/?name=$initials&background=$color&color=fff&size=128&bold=true&format=png';
  }

  /// Get initials from team name (max 3 chars)
  static String _getInitials(String name) {
    final words = name.split(' ').where((w) => w.isNotEmpty).toList();
    if (words.isEmpty) return '??';

    if (words.length == 1) {
      return words[0].substring(0, words[0].length.clamp(0, 3)).toUpperCase();
    }

    // Get first letter of each word (max 3)
    return words.take(3).map((w) => w[0].toUpperCase()).join();
  }

  /// Generate a consistent color based on team name
  static String _getColorForTeam(String name) {
    final colors = [
      '1e88e5', // Blue
      'e53935', // Red
      '43a047', // Green
      'fb8c00', // Orange
      '8e24aa', // Purple
      '00acc1', // Cyan
      '3949ab', // Indigo
      'd81b60', // Pink
      '5e35b1', // Deep Purple
      '039be5', // Light Blue
    ];

    // Hash the name to get consistent color
    int hash = 0;
    for (int i = 0; i < name.length; i++) {
      hash = name.codeUnitAt(i) + ((hash << 5) - hash);
    }

    return colors[hash.abs() % colors.length];
  }

  /// Batch fetch logos for multiple teams
  static Future<Map<String, String>> getTeamLogos(
    List<String> teamNames,
    String sport,
  ) async {
    final logos = <String, String>{};

    // Fetch in parallel with limit
    final futures = teamNames.map((name) async {
      final logo = await getTeamLogo(name, sport);
      if (logo != null) {
        logos[name] = logo;
      }
    });

    await Future.wait(futures);
    return logos;
  }
}
