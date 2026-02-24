import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/themes/app_theme.dart';

/// Floating microphone button for voice input
class VoiceInputButton extends StatefulWidget {
  final Function(String) onTranscriptionComplete;
  final TextEditingController? notesController;
  final Function(bool)? onListeningStateChanged;

  const VoiceInputButton({
    super.key,
    required this.onTranscriptionComplete,
    this.notesController,
    this.onListeningStateChanged,
  });

  @override
  State<VoiceInputButton> createState() => _VoiceInputButtonState();
}

class _VoiceInputButtonState extends State<VoiceInputButton>
    with TickerProviderStateMixin {
  late stt.SpeechToText _speech;
  bool _isListening = false;
  bool _isAvailable = false;
  bool _hasInitialized = false; // Track if we've tried to initialize
  bool _hasPermanentError =
      false; // Track if we've encountered a permanent error
  String _transcription = '';
  late AnimationController _pulseController;
  late AnimationController _waveController;

  @override
  void initState() {
    super.initState();
    _speech = stt.SpeechToText();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);

    _waveController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();

    // Don't initialize speech immediately - wait until button is first pressed
    // This prevents crashes on app startup if permissions aren't set
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _waveController.dispose();
    _speech.cancel();
    super.dispose();
  }

  Future<void> _initializeSpeech() async {
    bool available = false;
    try {
      available = await _speech.initialize(
        onError: (error) {
          debugPrint('[VoiceInput] Speech recognition error: $error');

          // Check if it's a permanent error
          if (error.permanent) {
            debugPrint(
              '[VoiceInput] Permanent error detected: ${error.errorMsg}',
            );
            if (mounted) {
              setState(() {
                _isListening = false;
                _isAvailable = false;
                _hasPermanentError = true;
              });
            }
            widget.onListeningStateChanged?.call(false);

            // Provide helpful error message based on error type
            String errorMessage = 'Speech recognition unavailable. ';
            if (error.errorMsg.contains('permission') ||
                error.errorMsg.contains('denied') ||
                error.errorMsg.contains('error_listen_failed')) {
              errorMessage +=
                  'Please check microphone permissions in Settings.';
            } else if (error.errorMsg.contains('error_retry')) {
              errorMessage += 'Speech service temporarily unavailable.';
            } else {
              errorMessage += 'Using text input instead.';
            }

            _showError(errorMessage);

            // Switch to mock mode for this session
            if (_isListening) {
              _startMockListening();
            }
          } else {
            // Temporary error - just stop listening
            if (mounted) {
              setState(() {
                _isListening = false;
              });
            }
            widget.onListeningStateChanged?.call(false);
            _showError('Speech recognition error: ${error.errorMsg}');
          }
        },
        onStatus: (status) {
          debugPrint('[VoiceInput] Speech status: $status');
          if (status == 'done' || status == 'notListening') {
            if (mounted) {
              setState(() {
                _isListening = false;
              });
            }
            widget.onListeningStateChanged?.call(false);
            if (_transcription.isNotEmpty) {
              widget.onTranscriptionComplete(_transcription);
              _transcription = '';
            }
          }
        },
      );
    } catch (e) {
      debugPrint('[VoiceInput] Failed to initialize speech: $e');
      // Plugin not available (desktop/web or not properly linked)
      // Will use mock mode instead
      available = false;
    }

    if (mounted) {
      setState(() {
        _isAvailable = available && !_hasPermanentError;
      });
    }
  }

  Future<void> _startListening() async {
    // If we've encountered a permanent error, use mock mode
    if (_hasPermanentError) {
      await _startMockListening();
      return;
    }

    // Initialize speech on first use (lazy initialization)
    if (!_hasInitialized) {
      await _initializeSpeech();
      _hasInitialized = true;
      // If still not available after initialization, use mock mode
      if (!_isAvailable || _hasPermanentError) {
        await _startMockListening();
        return;
      }
    } else if (!_isAvailable || _hasPermanentError) {
      // Already initialized but not available, use mock mode
      await _startMockListening();
      return;
    }

    // Note: Permission check happens automatically when listen() is called
    // If permission is denied, it will trigger onError with a permanent error

    try {
      setState(() {
        _isListening = true;
        _transcription = '';
      });
      widget.onListeningStateChanged?.call(true);

      await _speech.listen(
        onResult: (result) {
          if (mounted) {
            setState(() {
              _transcription = result.recognizedWords;
            });

            // Update notes controller if provided
            if (widget.notesController != null) {
              widget.notesController!.text = result.recognizedWords;
            }
          }
        },
        listenFor: const Duration(seconds: 30),
        pauseFor: const Duration(seconds: 3),
        localeId: 'en_US',
        cancelOnError: true,
        partialResults: true,
      );
    } catch (e) {
      debugPrint('[VoiceInput] Error starting listening: $e');
      if (mounted) {
        setState(() {
          _isListening = false;
          _hasPermanentError = true;
        });
      }
      widget.onListeningStateChanged?.call(false);
      _showError('Failed to start listening. Using text input instead.');
      // Fall back to mock mode
      await _startMockListening();
    }
  }

  Future<void> _stopListening() async {
    if (_isListening) {
      await _speech.stop();
      setState(() {
        _isListening = false;
      });
      widget.onListeningStateChanged?.call(false);
    }
  }

  void _showError(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: AppTheme.errorColor,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // Always show button - will initialize speech on first press
    return FloatingActionButton(
      onPressed: _isListening ? _stopListening : _startListening,
      backgroundColor: _isListening
          ? AppTheme.errorColor
          : AppTheme.primaryColor,
      child: _isListening
          ? _buildListeningState()
          : const Icon(FontAwesomeIcons.microphone, color: Colors.white),
    );
  }

  Future<void> _startMockListening() async {
    // Mock listening for desktop/web or when plugin not available
    setState(() {
      _isListening = true;
    });
    widget.onListeningStateChanged?.call(true);

    // Simulate listening for 2 seconds
    await Future.delayed(const Duration(seconds: 2));

    if (!mounted) return;

    // Generate mock transcription
    final mockText =
        'This is a mock transcription. On a real device with microphone access, '
        'this would be your spoken words. Try saying: "I had a great day today, feeling positive and energized!"';

    setState(() {
      _isListening = false;
      _transcription = mockText;
    });

    widget.onListeningStateChanged?.call(false);
    widget.onTranscriptionComplete(mockText);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Mock transcription (speech_to_text not available on this platform)',
          ),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  Widget _buildListeningState() {
    return Stack(
      alignment: Alignment.center,
      children: [
        // Pulsing circle
        AnimatedBuilder(
          animation: _pulseController,
          builder: (context, child) {
            return Container(
              width: 40 + (_pulseController.value * 10),
              height: 40 + (_pulseController.value * 10),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppTheme.errorColor.withValues(alpha: 
                  0.3 - (_pulseController.value * 0.2),
                ),
              ),
            );
          },
        ),
        // Microphone icon
        const Icon(
          FontAwesomeIcons.microphoneLines,
          color: Colors.white,
          size: 24,
        ),
      ],
    );
  }
}

/// Voice input overlay showing live transcription
class VoiceInputOverlay extends StatelessWidget {
  final bool isListening;
  final String transcription;
  final VoidCallback onStop;

  const VoiceInputOverlay({
    super.key,
    required this.isListening,
    required this.transcription,
    required this.onStop,
  });

  @override
  Widget build(BuildContext context) {
    if (!isListening) return const SizedBox.shrink();

    return Container(
      color: Colors.black.withValues(alpha: 0.7),
      child: SafeArea(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Sound wave animation placeholder
            Container(
              width: 200,
              height: 100,
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Center(
                child: Icon(
                  FontAwesomeIcons.waveSquare,
                  size: 48,
                  color: AppTheme.primaryColor,
                ),
              ),
            ),
            const SizedBox(height: 24),
            // Transcription text
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Text(
                transcription.isEmpty ? 'Listening...' : transcription,
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  color: Colors.white,
                  fontWeight: FontWeight.w500,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 32),
            // Stop button
            ElevatedButton.icon(
              onPressed: onStop,
              icon: const Icon(FontAwesomeIcons.stop),
              label: const Text('Stop'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.errorColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 32,
                  vertical: 16,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
