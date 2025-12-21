import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../features/studio/audio_overview.dart';
import 'package:dio/dio.dart';
import 'dart:io';
import 'package:path/path.dart' as p;

class AudioCacheNotifier extends StateNotifier<List<AudioOverview>> {
  AudioCacheNotifier() : super([]);

  Future<void> cache(AudioOverview overview) async {
    if (overview.isOffline) return;
    if (overview.url.isEmpty) return;
    final dir = Directory.systemTemp.path;
    final safeTitle = overview.title.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
    final fileName = '${safeTitle}_${overview.id}.mp3';
    final outPath = p.join(dir, fileName);
    await Dio().download(overview.url, outPath);
    final localUrl = 'file://$outPath';
    final cached = overview.copyWith(isOffline: true, url: localUrl);
    state = [...state.where((a) => a.id != overview.id), cached];
  }

  Future<void> remove(AudioOverview overview) async {
    state = state.where((a) => a.id != overview.id).toList();
  }
}

final audioCacheProvider = StateNotifierProvider<AudioCacheNotifier, List<AudioOverview>>((ref) => AudioCacheNotifier());