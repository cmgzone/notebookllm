import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import '../api/api_service.dart';

class SerperSearchResult {
  final String title;
  final String link;
  final String snippet;
  final String? date;
  final String? source;
  final String? imageUrl;

  SerperSearchResult({
    required this.title,
    required this.link,
    required this.snippet,
    this.date,
    this.source,
    this.imageUrl,
  });

  factory SerperSearchResult.fromJson(Map<String, dynamic> json) {
    return SerperSearchResult(
      title: json['title'] as String? ?? '',
      link: json['link'] as String? ?? '',
      snippet: json['snippet'] as String? ?? '',
      date: json['date'] as String?,
      source: json['source'] as String?,
      imageUrl: json['imageUrl'] as String?,
    );
  }
}

class SerperService {
  final Ref ref;

  SerperService(this.ref);

  /// Search Google using Serper.dev
  Future<List<SerperSearchResult>> search(
    String query, {
    String type = 'search',
    int num = 10,
    int page = 1,
  }) async {
    return _searchDirect(query, type: type, num: num, page: page);
  }

  /// Direct search using Serper API key
  Future<List<SerperSearchResult>> _searchDirect(
    String query, {
    String type = 'search',
    int num = 10,
    int page = 1,
  }) async {
    try {
      final api = ref.read(apiServiceProvider);
      final data = await api.searchProxy(
        query: query,
        type: type,
        num: num,
        page: page,
      );

      List<dynamic> results = [];
      if (type == 'search') {
        results = (data['organic'] as List?) ?? [];
      } else if (type == 'news') {
        results = (data['news'] as List?) ?? [];
      } else if (type == 'images') {
        results = (data['images'] as List?) ?? [];
      } else if (type == 'videos') {
        results = (data['videos'] as List?) ?? [];
      }

      return results
          .map((e) => SerperSearchResult.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('[SerperService] Proxy search error: $e');
      throw Exception('Search failed: $e');
    }
  }

  /// Fetch page content and strip HTML
  Future<String> fetchPageContent(String url) async {
    try {
      debugPrint('[SerperService] Fetching content from: $url');
      final response = await http.get(
        Uri.parse(url),
        headers: {
          'User-Agent':
              'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36'
        },
      ).timeout(const Duration(seconds: 10));

      debugPrint('[SerperService] Response status: ${response.statusCode}');

      if (response.statusCode == 200) {
        String html = response.body;

        // Remove scripts and styles
        html = html.replaceAll(
            RegExp(r'<script\b[^>]*>([\s\S]*?)<\/script>',
                caseSensitive: false),
            '');
        html = html.replaceAll(
            RegExp(r'<style\b[^>]*>([\s\S]*?)<\/style>', caseSensitive: false),
            '');

        // Remove HTML tags
        html = html.replaceAll(RegExp(r'<[^>]*>'), ' ');

        // Decode HTML entities (basic ones)
        html = html
            .replaceAll('&nbsp;', ' ')
            .replaceAll('&amp;', '&')
            .replaceAll('&lt;', '<')
            .replaceAll('&gt;', '>')
            .replaceAll('&quot;', '"')
            .replaceAll('&#39;', "'");

        // Clean up whitespace
        html = html.replaceAll(RegExp(r'\s+'), ' ').trim();

        debugPrint('[SerperService] Extracted ${html.length} characters');
        return html;
      }
      debugPrint('[SerperService] Failed with status ${response.statusCode}');
      return '';
    } catch (e) {
      debugPrint('[SerperService] Error fetching $url: $e');
      return '';
    }
  }
}

final serperServiceProvider = Provider((ref) => SerperService(ref));
