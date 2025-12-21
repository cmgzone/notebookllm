import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class SerperConfig {
  static String get apiKey {
    final envKey = dotenv.env['SERPER_API_KEY'];
    if (envKey != null && envKey.isNotEmpty) return envKey;
    // In debug, allow missing key to surface clearly
    if (kDebugMode) return '';
    return '';
  }
  
  static const String baseUrl = 'https://google.serper.dev/search';
  
  // Search configuration
  static const int defaultResultsCount = 10;
  static const int maxResultsCount = 20;
  
  // Rate limiting (requests per minute)
  static const int freeTierLimit = 100;
  static const int paidTierLimit = 5000;
  
  // Search filters
  static const Map<String, String> dateRanges = {
    'Any time': '',
    'Past hour': 'h',
    'Past day': 'd',
    'Past week': 'w',
    'Past month': 'm',
    'Past year': 'y',
  };
  
  // Content extraction settings
  static const int maxContentLength = 5000;
  static const bool extractMainContent = true;
  static const bool removeAds = true;
}