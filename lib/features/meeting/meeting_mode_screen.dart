import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:intl/intl.dart';
import 'package:just_audio/just_audio.dart';
import '../../core/ai/gemini_service.dart';
import '../../core/ai/openrouter_service.dart';
import '../../core/security/global_credentials_service.dart';
import '../../core/audio/ai_transcription_service.dart';
import '../../core/audio/meeting_recorder_service.dart';
import '../sources/source_provider.dart';
import '../../core/ai/ai_settings_service.dart';

class MeetingModeScreen extends ConsumerStatefulWidget {
  const MeetingModeScreen({super.key});

  @override
  ConsumerState<MeetingModeScreen> createState() => _MeetingModeScreenState();
}

class _MeetingModeScreenState extends ConsumerState<MeetingModeScreen> {
  final SpeechToText _speech = SpeechToText();
  final List<TranscriptSegment> _transcript = [];
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _titleController = TextEditingController();

  bool _isRecording = false;
  bool _isInitialized = false;
  bool _isGeneratingSummary = false;
  bool _permissionGranted = false;
  String _currentText = '';
  DateTime? _meetingStartTime;
  String? _generatedSummary;
  String? _errorMessage;
  String _initStatus = 'Checking permissions...';

  // Speaker management
  final List<Speaker> _speakers = [];
  String _activeSpeaker = 'Unknown';
  final List<Color> _speakerColors = [
    Colors.blue,
    Colors.green,
    Colors.orange,
    Colors.purple,
    Colors.teal,
    Colors.pink,
    Colors.indigo,
    Colors.amber,
  ];

  // AI Transcription
  bool _useAITranscription = true; // Default to AI for better quality
  String _selectedLanguage = 'multi'; // Auto-detect by default

  // Audio Recording
  bool _recordAudio = true; // Record playable audio file
  bool _noiseReduction = true; // Enable noise filtering
  MeetingRecording? _currentRecording;
  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _isPlayingRecording = false;
  Duration _playbackPosition = Duration.zero;
  Duration _playbackDuration = Duration.zero;

  @override
  void initState() {
    super.initState();
    _initSpeech();
    _titleController.text =
        'Meeting ${DateFormat('MMM d, yyyy HH:mm').format(DateTime.now())}';
    _setupAudioPlayer();
  }

  void _setupAudioPlayer() {
    _audioPlayer.positionStream.listen((position) {
      if (mounted) setState(() => _playbackPosition = position);
    });
    _audioPlayer.durationStream.listen((duration) {
      if (mounted && duration != null) {
        setState(() => _playbackDuration = duration);
      }
    });
    _audioPlayer.playerStateStream.listen((state) {
      if (mounted) {
        setState(() {
          _isPlayingRecording = state.playing;
        });
      }
    });
  }

  Future<void> _initSpeech() async {
    try {
      setState(() => _initStatus = 'Requesting microphone permission...');

      // Request microphone permission first
      final permissionStatus = await Permission.microphone.request();
      debugPrint('Microphone permission status: $permissionStatus');

      if (permissionStatus.isDenied || permissionStatus.isPermanentlyDenied) {
        setState(() {
          _errorMessage =
              'Microphone permission denied. Please enable it in settings.';
          _initStatus = 'Permission denied';
        });
        return;
      }

      _permissionGranted = true;
      setState(() => _initStatus = 'Initializing speech recognition...');

      _isInitialized = await _speech.initialize(
        onError: (error) {
          debugPrint('Speech error: ${error.errorMsg}');
          if (mounted) {
            setState(() {
              _errorMessage = 'Speech error: ${error.errorMsg}';
            });
          }
        },
        onStatus: (status) {
          debugPrint('Speech status: $status');
          // INFINITE LISTENING: Auto-restart immediately when stopped
          if (_isRecording &&
              mounted &&
              !_useAITranscription &&
              (status == 'notListening' || status == 'done')) {
            // Immediate restart for continuous recording
            Future.delayed(const Duration(milliseconds: 100), () {
              if (_isRecording && mounted && !_speech.isListening) {
                debugPrint('Auto-restarting listening for infinite mode...');
                _startDeviceListening();
              }
            });
          }
        },
      );

      debugPrint('Speech initialized: $_isInitialized');
      debugPrint('Speech available: ${_speech.isAvailable}');
      debugPrint('Locales: ${await _speech.locales()}');

      if (!_isInitialized) {
        setState(() {
          _errorMessage = 'Speech recognition not available on this device.';
          _initStatus = 'Not available';
        });
      } else {
        setState(() => _initStatus = 'Ready');
      }
    } catch (e) {
      debugPrint('Init speech error: $e');
      setState(() {
        _errorMessage = 'Failed to initialize speech: $e';
        _initStatus = 'Error';
      });
    }
  }

  void _startMeeting() async {
    setState(() {
      _isRecording = true;
      _meetingStartTime = DateTime.now();
      _transcript.clear();
      _generatedSummary = null;
      _currentRecording = null;
    });

    if (_useAITranscription) {
      // AI transcription handles audio recording internally
      _startAIListening();
    } else {
      // For device transcription, start separate audio recording if enabled
      if (_recordAudio) {
        try {
          final recorder = ref.read(meetingRecorderProvider);
          final path = await recorder.startRecording(
            title: _titleController.text,
            noiseReduction: _noiseReduction,
          );
          debugPrint('Audio recording started: $path');
        } catch (e) {
          debugPrint('Failed to start audio recording: $e');
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Audio recording failed: $e')),
            );
          }
        }
      }
      _startDeviceListening();
    }
  }

  /// AI-powered transcription (Deepgram/Gemini) - faster, multi-language
  void _startAIListening() async {
    if (!_isRecording) return;

    try {
      debugPrint('Starting AI transcription (saveAudio=$_recordAudio)...');
      final aiService = ref.read(aiTranscriptionServiceProvider);

      // Initialize the recorder first
      final initialized = await aiService.initialize();
      if (!initialized) {
        debugPrint('AI transcription: Failed to initialize recorder');
        if (mounted && _isRecording) {
          setState(() {
            _useAITranscription = false;
            _errorMessage = 'Microphone not available for AI transcription';
          });
          _startDeviceListening();
        }
        return;
      }

      await aiService.startListening(
        onResult: (text, isFinal) {
          if (!mounted) return;

          debugPrint('Meeting: Received transcript (final=$isFinal): "$text"');

          setState(() {
            _currentText = text;
          });

          // For streaming mode, add segment when final
          // For chunked mode, all results are final
          if (isFinal && text.isNotEmpty) {
            _addTranscriptSegment(text);
            setState(() => _currentText = '');
          }
        },
        onErrorCallback: (error) {
          debugPrint('AI transcription error: $error');
          // Fallback to device transcription
          if (mounted && _isRecording) {
            setState(() {
              _useAITranscription = false;
              _errorMessage =
                  'AI transcription unavailable, using device. $error';
            });
            _startDeviceListening();
          }
        },
        language: _selectedLanguage,
        saveAudioFile: _recordAudio,
        audioFileName: _titleController.text,
      );

      debugPrint('AI transcription started');
    } catch (e) {
      debugPrint('AI listen error: $e');
      // Fallback to device
      if (mounted && _isRecording) {
        setState(() => _useAITranscription = false);
        _startDeviceListening();
      }
    }
  }

  /// Device-based transcription (speech_to_text) - fallback
  void _startDeviceListening() async {
    if (!_isInitialized || !_isRecording) {
      debugPrint(
          'Cannot start listening: initialized=$_isInitialized, recording=$_isRecording');
      return;
    }

    // Check if already listening
    if (_speech.isListening) {
      debugPrint('Already listening, skipping');
      return;
    }

    try {
      debugPrint('Starting device transcription...');

      await _speech.listen(
        onResult: (result) {
          debugPrint(
              'Speech result: ${result.recognizedWords} (final: ${result.finalResult})');
          setState(() {
            _currentText = result.recognizedWords;
          });

          if (result.finalResult && result.recognizedWords.isNotEmpty) {
            _addTranscriptSegment(result.recognizedWords);
            setState(() => _currentText = '');

            // INFINITE MODE: Immediately restart after getting final result
            if (_isRecording && mounted) {
              Future.delayed(const Duration(milliseconds: 50), () {
                if (_isRecording && mounted && !_speech.isListening) {
                  _startDeviceListening();
                }
              });
            }
          }
        },
        listenFor: const Duration(hours: 1),
        pauseFor: const Duration(seconds: 10),
        listenOptions: SpeechListenOptions(
          partialResults: true,
          cancelOnError: false,
          listenMode: ListenMode.dictation,
          autoPunctuation: true,
        ),
      );

      debugPrint('Device transcription started');
    } catch (e) {
      debugPrint('Device listen error: $e');
      if (mounted) {
        setState(() {
          _errorMessage = 'Listen error: $e';
        });
      }
    }
  }

  void _addTranscriptSegment(String text) {
    final segment = TranscriptSegment(
      text: text,
      timestamp: DateTime.now(),
      speakerLabel: _activeSpeaker,
    );

    setState(() {
      _transcript.add(segment);
    });

    _scrollToBottom();
  }

  void _addSpeaker(String name) {
    if (name.trim().isEmpty) return;
    if (_speakers.any((s) => s.name.toLowerCase() == name.toLowerCase())) {
      return;
    }

    final colorIndex = _speakers.length % _speakerColors.length;
    setState(() {
      _speakers
          .add(Speaker(name: name.trim(), color: _speakerColors[colorIndex]));
      _activeSpeaker = name.trim();
    });
  }

  void _setActiveSpeaker(String name) {
    setState(() => _activeSpeaker = name);
  }

  void _showAddSpeakerDialog() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Speaker'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Speaker Name',
            hintText: 'e.g., John, Sarah, CEO',
            border: OutlineInputBorder(),
          ),
          onSubmitted: (value) {
            _addSpeaker(value);
            Navigator.pop(context);
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              _addSpeaker(controller.text);
              Navigator.pop(context);
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  void _editTranscriptSpeaker(int index) {
    if (_speakers.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Add speakers first using the + button')),
      );
      return;
    }

    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Assign to Speaker',
                style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: Theme.of(context).colorScheme.onSurface)),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _speakers.map((speaker) {
                return ActionChip(
                  avatar: CircleAvatar(
                    backgroundColor: speaker.color,
                    radius: 12,
                    child: Text(speaker.name[0].toUpperCase(),
                        style:
                            const TextStyle(color: Colors.white, fontSize: 10)),
                  ),
                  label: Text(speaker.name),
                  onPressed: () {
                    setState(() {
                      _transcript[index] = TranscriptSegment(
                        text: _transcript[index].text,
                        timestamp: _transcript[index].timestamp,
                        speakerLabel: speaker.name,
                      );
                    });
                    Navigator.pop(context);
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _stopMeeting() async {
    // Stop recording immediately - don't process remaining audio
    setState(() => _isRecording = false);

    String? savedAudioPath;

    if (_useAITranscription) {
      // AI transcription service saves audio internally when _recordAudio is true
      final aiService = ref.read(aiTranscriptionServiceProvider);
      final duration = aiService.recordingDuration;
      savedAudioPath = await aiService.stopListening(processRemaining: false);

      // Create MeetingRecording from the saved audio file
      if (savedAudioPath != null && _recordAudio) {
        try {
          final file = File(savedAudioPath);
          if (await file.exists()) {
            final fileSize = await file.length();
            setState(() {
              _currentRecording = MeetingRecording(
                id: DateTime.now().millisecondsSinceEpoch.toString(),
                title: _titleController.text,
                filePath: savedAudioPath!,
                duration: duration,
                fileSize: fileSize,
                createdAt: _meetingStartTime ?? DateTime.now(),
                isTranscribed: _transcript.isNotEmpty,
              );
            });
            debugPrint('AI audio saved: $savedAudioPath ($fileSize bytes)');
          }
        } catch (e) {
          debugPrint('Failed to create recording from AI audio: $e');
        }
      }
    } else {
      await _speech.stop();

      // Stop audio recording from meeting recorder (device transcription mode)
      if (_recordAudio) {
        try {
          final recorder = ref.read(meetingRecorderProvider);
          final recording =
              await recorder.stopRecording(title: _titleController.text);
          if (recording != null) {
            setState(() => _currentRecording = recording);
            debugPrint('Audio saved: ${recording.filePath}');
          }
        } catch (e) {
          debugPrint('Failed to stop audio recording: $e');
        }
      }
    }

    if (_transcript.isNotEmpty || _currentRecording != null) {
      _showSaveDialog();
    }
  }

  void _pauseMeeting() async {
    // Stop recording immediately
    setState(() => _isRecording = false);

    if (_useAITranscription) {
      await ref
          .read(aiTranscriptionServiceProvider)
          .stopListening(processRemaining: false);
    } else {
      await _speech.stop();
    }

    // Pause audio recording
    if (_recordAudio) {
      await ref.read(meetingRecorderProvider).pauseRecording();
    }
  }

  void _resumeMeeting() async {
    setState(() => _isRecording = true);

    // Resume audio recording
    if (_recordAudio) {
      await ref.read(meetingRecorderProvider).resumeRecording();
    }

    if (_useAITranscription) {
      _startAIListening();
    } else {
      _startDeviceListening();
    }
  }

  Future<void> _generateSummary() async {
    if (_transcript.isEmpty) return;

    setState(() => _isGeneratingSummary = true);

    try {
      final fullTranscript = _transcript
          .map((s) =>
              '[${DateFormat('HH:mm:ss').format(s.timestamp)}] ${s.speakerLabel}: ${s.text}')
          .join('\n');

      final prompt = '''
You are an expert meeting assistant. Analyze this meeting transcript and generate comprehensive meeting minutes.

TRANSCRIPT:
$fullTranscript

Generate meeting minutes with the following sections:
1. **Meeting Summary** - 2-3 sentence overview
2. **Key Discussion Points** - Main topics discussed (bullet points)
3. **Decisions Made** - Any decisions or agreements reached
4. **Action Items** - Tasks assigned with owners if mentioned
5. **Follow-up Items** - Topics that need further discussion
6. **Notable Quotes** - Important statements (if any)

Format in clean Markdown. Be concise but comprehensive.
''';

      final summary = await _generateWithAI(prompt);
      setState(() => _generatedSummary = summary);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to generate summary: $e')),
        );
      }
    } finally {
      setState(() => _isGeneratingSummary = false);
    }
  }

  Future<String> _generateWithAI(String prompt) async {
    final settings = await AISettingsService.getSettings();
    final model = settings.model;

    if (model == null || model.isEmpty) {
      throw Exception(
          'No AI model selected. Please configure a model in settings.');
    }

    final creds = ref.read(globalCredentialsServiceProvider);

    if (settings.provider == 'openrouter') {
      final apiKey = await creds.getApiKey('openrouter');
      return await OpenRouterService()
          .generateContent(prompt, model: model, apiKey: apiKey);
    } else {
      final apiKey = await creds.getApiKey('gemini');
      return await GeminiService()
          .generateContent(prompt, apiKey: apiKey, model: model);
    }
  }

  void _showSaveDialog() {
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Save Meeting Notes'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: _titleController,
                  decoration: const InputDecoration(
                    labelText: 'Meeting Title',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),

                // Audio recording info and playback
                if (_currentRecording != null) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Theme.of(context)
                          .colorScheme
                          .primaryContainer
                          .withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(LucideIcons.fileAudio,
                                size: 16,
                                color: Theme.of(context).colorScheme.primary),
                            const SizedBox(width: 8),
                            const Text('Audio Recording',
                                style: TextStyle(fontWeight: FontWeight.bold)),
                            const Spacer(),
                            Text(_currentRecording!.formattedSize,
                                style: const TextStyle(fontSize: 12)),
                          ],
                        ),
                        const SizedBox(height: 8),
                        // Playback controls
                        Row(
                          children: [
                            IconButton(
                              icon: Icon(_isPlayingRecording
                                  ? Icons.pause
                                  : Icons.play_arrow),
                              onPressed: () => _togglePlayback(setDialogState),
                            ),
                            Expanded(
                              child: Slider(
                                value:
                                    _playbackPosition.inMilliseconds.toDouble(),
                                max: _playbackDuration.inMilliseconds
                                    .toDouble()
                                    .clamp(1, double.infinity),
                                onChanged: (value) {
                                  _audioPlayer.seek(
                                      Duration(milliseconds: value.toInt()));
                                },
                              ),
                            ),
                            Text(
                              '${_formatDuration(_playbackPosition)} / ${_formatDuration(_playbackDuration)}',
                              style: const TextStyle(fontSize: 11),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        // Transcribe button
                        OutlinedButton.icon(
                          onPressed: _isGeneratingSummary
                              ? null
                              : () => _transcribeRecording(setDialogState),
                          icon: _isGeneratingSummary
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child:
                                      CircularProgressIndicator(strokeWidth: 2))
                              : const Icon(Icons.transcribe, size: 16),
                          label: Text(_isGeneratingSummary
                              ? 'Transcribing...'
                              : 'AI Transcribe Audio'),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                if (_generatedSummary == null && _transcript.isNotEmpty)
                  OutlinedButton.icon(
                    onPressed: _isGeneratingSummary ? null : _generateSummary,
                    icon: _isGeneratingSummary
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.auto_awesome),
                    label: Text(_isGeneratingSummary
                        ? 'Generating...'
                        : 'Generate AI Summary'),
                  ),
                if (_generatedSummary != null)
                  const Row(
                    children: [
                      Icon(Icons.check_circle, color: Colors.green, size: 16),
                      SizedBox(width: 8),
                      Text('Summary generated!',
                          style: TextStyle(color: Colors.green)),
                    ],
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                _audioPlayer.stop();
                Navigator.pop(context);
              },
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                _audioPlayer.stop();
                Navigator.pop(context);
                _saveMeetingNotes();
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _togglePlayback(StateSetter setDialogState) async {
    if (_currentRecording == null) return;

    if (_isPlayingRecording) {
      await _audioPlayer.pause();
    } else {
      if (_audioPlayer.audioSource == null) {
        await _audioPlayer.setFilePath(_currentRecording!.filePath);
      }
      await _audioPlayer.play();
    }
    setDialogState(() {});
  }

  Future<void> _transcribeRecording(StateSetter setDialogState) async {
    if (_currentRecording == null) return;

    setDialogState(() => _isGeneratingSummary = true);
    setState(() => _isGeneratingSummary = true);

    try {
      // Check if file exists and has content
      final file = File(_currentRecording!.filePath);
      if (!await file.exists()) {
        throw Exception(
            'Recording file not found at: ${_currentRecording!.filePath}');
      }

      final fileSize = await file.length();
      if (fileSize < 1000) {
        throw Exception(
            'Recording file is too small ($fileSize bytes). No audio was captured.');
      }

      debugPrint(
          'Transcribing file: ${_currentRecording!.filePath} ($fileSize bytes)');

      final recorder = ref.read(meetingRecorderProvider);
      final transcript = await recorder.transcribeRecording(
        _currentRecording!,
        language: _selectedLanguage == 'multi' ? 'en' : _selectedLanguage,
        detectLanguage: _selectedLanguage == 'multi',
        onProgress: (progress) {
          debugPrint('Transcription progress: ${(progress * 100).toInt()}%');
        },
      );

      if (transcript.isEmpty) {
        throw Exception(
            'Transcription returned empty result. The audio may not contain speech.');
      }

      // Add transcribed segments
      final lines = transcript.split('\n').where((l) => l.trim().isNotEmpty);
      for (final line in lines) {
        _addTranscriptSegment(line);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Audio transcribed successfully!'),
              backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      debugPrint('Transcription error: $e');
      if (mounted) {
        String errorMsg = e.toString();
        if (errorMsg.contains('Exception:')) {
          errorMsg = errorMsg.replaceFirst('Exception:', '').trim();
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Transcription failed: $errorMsg'),
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } finally {
      setDialogState(() => _isGeneratingSummary = false);
      setState(() => _isGeneratingSummary = false);
    }
  }

  String _formatDuration(Duration d) {
    final mins = d.inMinutes;
    final secs = d.inSeconds % 60;
    return '$mins:${secs.toString().padLeft(2, '0')}';
  }

  Future<void> _saveMeetingNotes() async {
    final duration = _meetingStartTime != null
        ? DateTime.now().difference(_meetingStartTime!)
        : Duration.zero;

    final fullTranscript = _transcript
        .map((s) =>
            '[${DateFormat('HH:mm:ss').format(s.timestamp)}] ${s.speakerLabel}: ${s.text}')
        .join('\n');

    final content = '''
# ${_titleController.text}

**Date:** ${DateFormat('MMMM d, yyyy').format(_meetingStartTime ?? DateTime.now())}
**Duration:** ${duration.inMinutes} minutes
**Segments:** ${_transcript.length}

${_generatedSummary != null ? '## AI Summary\n$_generatedSummary\n' : ''}

## Full Transcript

$fullTranscript
''';

    try {
      await ref.read(sourceProvider.notifier).addSource(
            title: _titleController.text,
            type: 'text',
            content: content,
          );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Meeting notes saved to sources!'),
            backgroundColor: Colors.green,
          ),
        );

        // Clear for next meeting
        setState(() {
          _transcript.clear();
          _generatedSummary = null;
          _meetingStartTime = null;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save: $e')),
        );
      }
    }
  }

  void _showTranscriptionSettings() {
    showModalBottomSheet(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) => Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Recording Settings',
                  style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.onSurface)),
              const SizedBox(height: 20),

              // Audio recording toggle
              SwitchListTile(
                title: const Text('Record Audio File'),
                subtitle: Text(_recordAudio
                    ? 'Saves playable audio for later transcription'
                    : 'Live transcription only, no audio saved'),
                value: _recordAudio,
                onChanged: (value) {
                  setState(() => _recordAudio = value);
                  setSheetState(() {});
                },
                secondary: Icon(
                    _recordAudio ? LucideIcons.fileAudio : LucideIcons.micOff),
              ),

              // Noise reduction toggle
              if (_recordAudio)
                SwitchListTile(
                  title: const Text('Noise Reduction'),
                  subtitle:
                      const Text('Filter background noise for clearer audio'),
                  value: _noiseReduction,
                  onChanged: (value) {
                    setState(() => _noiseReduction = value);
                    setSheetState(() {});
                  },
                  secondary: Icon(_noiseReduction
                      ? LucideIcons.waves
                      : LucideIcons.volume2),
                ),

              const Divider(),

              // Provider toggle
              SwitchListTile(
                title: const Text('AI Transcription'),
                subtitle: Text(_useAITranscription
                    ? 'Using Deepgram/Gemini (faster, multi-language)'
                    : 'Using device speech recognition'),
                value: _useAITranscription,
                onChanged: (value) {
                  setState(() => _useAITranscription = value);
                  setSheetState(() {});
                },
                secondary: Icon(_useAITranscription
                    ? Icons.auto_awesome
                    : Icons.smartphone),
              ),

              const Divider(),

              // Language selection
              const Text('Language',
                  style: TextStyle(fontWeight: FontWeight.w500)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _buildLanguageChip('multi', 'Auto-detect', setSheetState),
                  _buildLanguageChip('en', 'English', setSheetState),
                  _buildLanguageChip('sw', 'Swahili', setSheetState),
                  _buildLanguageChip('es', 'Spanish', setSheetState),
                  _buildLanguageChip('zh', 'Chinese', setSheetState),
                  _buildLanguageChip('ja', 'Japanese', setSheetState),
                  _buildLanguageChip('ko', 'Korean', setSheetState),
                  _buildLanguageChip('fr', 'French', setSheetState),
                  _buildLanguageChip('de', 'German', setSheetState),
                  _buildLanguageChip('ar', 'Arabic', setSheetState),
                  _buildLanguageChip('hi', 'Hindi', setSheetState),
                  _buildLanguageChip('pt', 'Portuguese', setSheetState),
                  _buildLanguageChip('ru', 'Russian', setSheetState),
                  _buildLanguageChip('id', 'Indonesian', setSheetState),
                ],
              ),

              const SizedBox(height: 20),

              if (_recordAudio)
                Text(
                  '💡 Audio files are saved locally and can be transcribed later using AI.',
                  style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).colorScheme.outline),
                ),

              if (_useAITranscription && !_recordAudio)
                Text(
                  'Note: AI transcription requires Deepgram or Gemini API key configured in settings.',
                  style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).colorScheme.outline),
                ),

              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLanguageChip(
      String code, String label, StateSetter setSheetState) {
    final isSelected = _selectedLanguage == code;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        if (selected) {
          setState(() => _selectedLanguage = code);
          setSheetState(() {});
        }
      },
    );
  }

  @override
  void dispose() {
    _speech.stop();
    ref.read(aiTranscriptionServiceProvider).dispose();
    _audioPlayer.dispose();
    _scrollController.dispose();
    _titleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final duration = _meetingStartTime != null
        ? DateTime.now().difference(_meetingStartTime!)
        : Duration.zero;

    return Scaffold(
      backgroundColor: scheme.surface,
      appBar: AppBar(
        title: const Text('Meeting Mode'),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () {
            if (_isRecording) {
              _showExitConfirmation();
            } else {
              Navigator.pop(context);
            }
          },
        ),
        actions: [
          // AI/Device toggle
          IconButton(
            icon: Icon(
                _useAITranscription ? Icons.auto_awesome : Icons.smartphone),
            tooltip: _useAITranscription
                ? 'AI Transcription (multi-language)'
                : 'Device Transcription',
            onPressed: _isRecording ? null : _showTranscriptionSettings,
          ),
          if (_transcript.isNotEmpty && !_isRecording)
            IconButton(
              icon: const Icon(Icons.save),
              onPressed: _showSaveDialog,
              tooltip: 'Save meeting notes',
            ),
        ],
      ),
      body: Column(
        children: [
          // Recording status bar
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: _isRecording
                    ? [Colors.red.shade700, Colors.red.shade500]
                    : [scheme.surfaceContainerHighest, scheme.surface],
              ),
            ),
            child: Row(
              children: [
                if (_isRecording)
                  Container(
                    width: 12,
                    height: 12,
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                  )
                      .animate(onPlay: (c) => c.repeat(reverse: true))
                      .fadeIn(duration: 500.ms)
                      .then()
                      .fadeOut(duration: 500.ms),
                if (_isRecording) const SizedBox(width: 12),
                Icon(
                  _isRecording ? LucideIcons.mic : LucideIcons.micOff,
                  color: _isRecording ? Colors.white : scheme.onSurface,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            _isRecording ? 'Recording...' : 'Ready to record',
                            style: TextStyle(
                              color: _isRecording
                                  ? Colors.white
                                  : scheme.onSurface,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          if (_isRecording && _recordAudio) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(LucideIcons.fileAudio,
                                      size: 10,
                                      color:
                                          Colors.white.withValues(alpha: 0.9)),
                                  const SizedBox(width: 4),
                                  Text(
                                    'Audio',
                                    style: TextStyle(
                                      color:
                                          Colors.white.withValues(alpha: 0.9),
                                      fontSize: 10,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                      if (_meetingStartTime != null)
                        Text(
                          '${duration.inMinutes}:${(duration.inSeconds % 60).toString().padLeft(2, '0')} • ${_transcript.length} segments',
                          style: TextStyle(
                            color: _isRecording
                                ? Colors.white.withValues(alpha: 0.8)
                                : scheme.onSurface.withValues(alpha: 0.6),
                            fontSize: 12,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Speaker selection bar
          if (_isRecording || _transcript.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: scheme.surfaceContainerHighest,
                border: Border(
                    bottom: BorderSide(
                        color: scheme.outline.withValues(alpha: 0.2))),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.record_voice_over,
                          size: 14, color: scheme.primary),
                      const SizedBox(width: 8),
                      Text('Speaking: ',
                          style: TextStyle(
                              fontSize: 12,
                              color: scheme.onSurface.withValues(alpha: 0.7))),
                      Text(_activeSpeaker,
                          style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: scheme.primary)),
                      const Spacer(),
                      TextButton.icon(
                        onPressed: _showAddSpeakerDialog,
                        icon: const Icon(Icons.person_add, size: 16),
                        label:
                            const Text('Add', style: TextStyle(fontSize: 12)),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                      ),
                    ],
                  ),
                  if (_speakers.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: _speakers.map((speaker) {
                          final isActive = speaker.name == _activeSpeaker;
                          return Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: GestureDetector(
                              onTap: () => _setActiveSpeaker(speaker.name),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: isActive
                                      ? speaker.color
                                      : speaker.color.withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(20),
                                  border: isActive
                                      ? null
                                      : Border.all(color: speaker.color),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    if (isActive) ...[
                                      const Icon(Icons.mic,
                                          size: 14, color: Colors.white),
                                      const SizedBox(width: 4),
                                    ],
                                    Text(
                                      speaker.name,
                                      style: TextStyle(
                                        color: isActive
                                            ? Colors.white
                                            : speaker.color,
                                        fontWeight: isActive
                                            ? FontWeight.bold
                                            : FontWeight.normal,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ],
                ],
              ),
            ),

          // Current speech indicator
          if (_isRecording && _currentText.isNotEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              color: scheme.primaryContainer.withValues(alpha: 0.3),
              child: Row(
                children: [
                  Icon(Icons.hearing, size: 16, color: scheme.primary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '$_activeSpeaker: $_currentText',
                      style: TextStyle(
                        fontStyle: FontStyle.italic,
                        color: scheme.onSurface.withValues(alpha: 0.8),
                      ),
                    ),
                  ),
                ],
              ),
            ).animate().fadeIn(),

          // Transcript list
          Expanded(
            child: _transcript.isEmpty
                ? _buildEmptyState(scheme)
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(16),
                    itemCount: _transcript.length,
                    itemBuilder: (context, index) {
                      final segment = _transcript[index];
                      return GestureDetector(
                        onTap: () => _editTranscriptSpeaker(index),
                        child: _TranscriptCard(
                          segment: segment,
                          speakerColor: _speakers
                              .firstWhere(
                                (s) => s.name == segment.speakerLabel,
                                orElse: () => Speaker(
                                    name: segment.speakerLabel,
                                    color: Colors.grey),
                              )
                              .color,
                        ),
                      ).animate().fadeIn(duration: 300.ms).slideX(begin: 0.1);
                    },
                  ),
          ),

          // Control buttons
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: scheme.surface,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 10,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                if (!_isRecording && _meetingStartTime == null)
                  _buildControlButton(
                    icon: Icons.fiber_manual_record,
                    label: 'Start Meeting',
                    color: Colors.red,
                    onTap: (_isInitialized && _permissionGranted)
                        ? _startMeeting
                        : null,
                  ),
                if (_isRecording) ...[
                  _buildControlButton(
                    icon: Icons.pause,
                    label: 'Pause',
                    color: scheme.secondary,
                    onTap: _pauseMeeting,
                  ),
                  _buildControlButton(
                    icon: Icons.stop,
                    label: 'End Meeting',
                    color: Colors.red,
                    onTap: _stopMeeting,
                  ),
                ],
                if (!_isRecording && _meetingStartTime != null)
                  _buildControlButton(
                    icon: Icons.play_arrow,
                    label: 'Resume',
                    color: Colors.green,
                    onTap: _resumeMeeting,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(ColorScheme scheme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: scheme.primaryContainer.withValues(alpha: 0.3),
            ),
            child: Icon(
              LucideIcons.users,
              size: 64,
              color: scheme.primary,
            ),
          ).animate().scale(duration: 600.ms, curve: Curves.elasticOut),
          const SizedBox(height: 24),
          Text(
            'Meeting Mode',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ).animate().fadeIn(delay: 200.ms),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 48),
            child: Text(
              _isInitialized
                  ? 'Tap "Start Meeting" to begin recording.\nI\'ll transcribe everything and generate meeting minutes.'
                  : _initStatus,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: scheme.onSurface.withValues(alpha: 0.6),
                  ),
              textAlign: TextAlign.center,
            ),
          ).animate().fadeIn(delay: 400.ms),
          if (!_isInitialized && _errorMessage == null) ...[
            const SizedBox(height: 16),
            const CircularProgressIndicator(),
          ],
          if (_errorMessage != null) ...[
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Text(
                _errorMessage!,
                style: TextStyle(color: scheme.error),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: () {
                setState(() {
                  _errorMessage = null;
                  _initStatus = 'Retrying...';
                });
                _initSpeech();
              },
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
            if (_errorMessage!.contains('permission')) ...[
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => openAppSettings(),
                child: const Text('Open Settings'),
              ),
            ],
          ],
        ],
      ),
    );
  }

  Widget _buildControlButton({
    required IconData icon,
    required String label,
    required Color color,
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: onTap != null ? color : color.withValues(alpha: 0.3),
              boxShadow: onTap != null
                  ? [
                      BoxShadow(
                        color: color.withValues(alpha: 0.3),
                        blurRadius: 12,
                        spreadRadius: 2,
                      ),
                    ]
                  : null,
            ),
            child: Icon(
              icon,
              color: Colors.white,
              size: 28,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: onTap != null ? null : Colors.grey,
            ),
          ),
        ],
      ),
    );
  }

  void _showExitConfirmation() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('End Meeting?'),
        content: const Text(
          'You have an active recording. Do you want to save the meeting notes before leaving?',
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context);
            },
            child: const Text('Discard'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(context);
              _stopMeeting();
            },
            child: const Text('Save & Exit'),
          ),
        ],
      ),
    );
  }
}

class Speaker {
  final String name;
  final Color color;

  Speaker({required this.name, required this.color});
}

class TranscriptSegment {
  final String text;
  final DateTime timestamp;
  final String speakerLabel;

  TranscriptSegment({
    required this.text,
    required this.timestamp,
    required this.speakerLabel,
  });
}

class _TranscriptCard extends StatelessWidget {
  final TranscriptSegment segment;
  final Color speakerColor;

  const _TranscriptCard({
    required this.segment,
    required this.speakerColor,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 12,
                  backgroundColor: speakerColor,
                  child: Text(
                    segment.speakerLabel.isNotEmpty
                        ? segment.speakerLabel[0].toUpperCase()
                        : '?',
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  segment.speakerLabel,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: speakerColor,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(width: 8),
                Icon(Icons.edit,
                    size: 12, color: scheme.onSurface.withValues(alpha: 0.3)),
                const Spacer(),
                Text(
                  DateFormat('HH:mm:ss').format(segment.timestamp),
                  style: TextStyle(
                    fontSize: 11,
                    color: scheme.onSurface.withValues(alpha: 0.5),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              segment.text,
              style: TextStyle(fontSize: 14, color: scheme.onSurface),
            ),
          ],
        ),
      ),
    );
  }
}
