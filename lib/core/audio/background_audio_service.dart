import 'package:flutter/foundation.dart';

class BackgroundAudioService {
  static final BackgroundAudioService _instance = BackgroundAudioService._internal();
  factory BackgroundAudioService() => _instance;
  BackgroundAudioService._internal();

  bool _isPlaying = false;
  String? _currentUrl;

  bool get isPlaying => _isPlaying;
  String? get currentUrl => _currentUrl;

  Future<void> play(String url) async {
    _isPlaying = true;
    _currentUrl = url;
    debugPrint('BackgroundAudioService: playing $url');
  }

  Future<void> pause() async {
    _isPlaying = false;
    debugPrint('BackgroundAudioService: paused');
  }

  Future<void> stop() async {
    _isPlaying = false;
    _currentUrl = null;
    debugPrint('BackgroundAudioService: stopped');
  }
}