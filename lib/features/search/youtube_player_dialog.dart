import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';

class YouTubePlayerDialog extends StatefulWidget {
  const YouTubePlayerDialog({super.key, required this.videoId});
  final String videoId;

  @override
  State<YouTubePlayerDialog> createState() => _YouTubePlayerDialogState();
}

class _YouTubePlayerDialogState extends State<YouTubePlayerDialog> {
  YoutubePlayerController? _controller;

  @override
  void initState() {
    super.initState();
    if (!kIsWeb) {
      _controller = YoutubePlayerController(
        initialVideoId: widget.videoId,
        flags: const YoutubePlayerFlags(
          autoPlay: true,
          mute: false,
          enableCaption: true,
        ),
      );
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (kIsWeb) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Align(
            alignment: Alignment.topRight,
            child: IconButton(
              icon: const Icon(Icons.close, color: Colors.white, size: 32),
              onPressed: () => Navigator.pop(context),
            ),
          ),
          const SizedBox(height: 24),
          const Icon(Icons.play_circle_filled,
              color: Colors.white, size: 64),
          const SizedBox(height: 16),
          const Text(
            'YouTube playback opens in a new tab on web.',
            style: TextStyle(color: Colors.white),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: () {
              final url =
                  Uri.parse('https://www.youtube.com/watch?v=${widget.videoId}');
              launchUrl(url, mode: LaunchMode.externalApplication);
            },
            icon: const Icon(Icons.open_in_new),
            label: const Text('Open on YouTube'),
          ),
          const SizedBox(height: 24),
        ],
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Close button
        Align(
          alignment: Alignment.topRight,
          child: IconButton(
            icon: const Icon(Icons.close, color: Colors.white, size: 32),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        // YouTube Player
        YoutubePlayer(
          controller: _controller!,
          showVideoProgressIndicator: true,
          progressIndicatorColor: Colors.red,
          progressColors: const ProgressBarColors(
            playedColor: Colors.red,
            handleColor: Colors.redAccent,
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }
}
