import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:animated_text_kit/animated_text_kit.dart';
import '../../../../core/themes/app_theme.dart';
import 'music_recommendations_screen.dart';

/// Breathing exercise screen with guided breathing and animations
class BreathingExerciseScreen extends StatefulWidget {
  const BreathingExerciseScreen({super.key});

  @override
  State<BreathingExerciseScreen> createState() =>
      _BreathingExerciseScreenState();
}

class _BreathingExerciseScreenState extends State<BreathingExerciseScreen>
    with TickerProviderStateMixin {
  late AnimationController _breathController;
  late AnimationController _pulseController;
  late Animation<double> _breathAnimation;
  late Animation<double> _pulseAnimation;
  final FlutterTts _tts = FlutterTts();

  int _currentCycle = 0;
  final int _totalCycles = 5;
  String _currentPhase = 'Breathe In';
  bool _isPaused = false;
  bool _isCompleted = false;

  @override
  void initState() {
    super.initState();

    // Breathing animation (4-7-8 technique: 4s in, 7s hold, 8s out)
    _breathController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 19), // Total cycle time
    );

    // Pulse animation for visual feedback
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    _breathAnimation = Tween<double>(begin: 0.5, end: 1.5).animate(
      CurvedAnimation(parent: _breathController, curve: Curves.easeInOut),
    );

    _pulseAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _initializeTts();
    _startBreathing();
  }

  Future<void> _initializeTts() async {
    await _tts.setLanguage('en-US');
    await _tts.setSpeechRate(0.5);
    await _tts.setVolume(1.0);
    await _tts.setPitch(1.0);
  }

  void _startBreathing() {
    _breathController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _breathController.reset();
        _currentCycle++;
        if (_currentCycle < _totalCycles) {
          _startBreathing();
        } else {
          _completeSession();
        }
      }
    });

    _breathController.forward();
    _speakInstructions();
  }

  Future<void> _speakInstructions() async {
    if (_isPaused) return;

    // Breathe in (4 seconds)
    setState(() => _currentPhase = 'Breathe In');
    await _tts.speak('Breathe in slowly through your nose');
    await Future.delayed(const Duration(seconds: 4));

    if (!_isPaused && mounted) {
      // Hold (7 seconds)
      setState(() => _currentPhase = 'Hold');
      await _tts.speak('Hold your breath');
      await Future.delayed(const Duration(seconds: 7));
    }

    if (!_isPaused && mounted) {
      // Breathe out (8 seconds)
      setState(() => _currentPhase = 'Breathe Out');
      await _tts.speak('Breathe out slowly through your mouth');
      await Future.delayed(const Duration(seconds: 8));
    }
  }

  void _completeSession() {
    setState(() {
      _isCompleted = true;
      _currentPhase = 'Complete';
    });
    _tts.speak('Great job! You\'ve completed your breathing exercise.');
  }

  void _togglePause() {
    setState(() => _isPaused = !_isPaused);
    if (_isPaused) {
      _breathController.stop();
      _tts.stop();
    } else {
      _breathController.forward();
      _speakInstructions();
    }
  }

  @override
  void dispose() {
    _breathController.dispose();
    _pulseController.dispose();
    _tts.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (_isCompleted) {
      return _buildCompletionScreen(context, theme);
    }

    return Scaffold(
      backgroundColor: AppTheme.primaryColor.withOpacity(0.05),
      appBar: AppBar(
        title: Text(
          'Breathing Exercise',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Progress indicator
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: List.generate(
                  _totalCycles,
                  (index) => Expanded(
                    child: Container(
                      height: 4,
                      margin: EdgeInsets.only(
                        right: index < _totalCycles - 1 ? 8 : 0,
                      ),
                      decoration: BoxDecoration(
                        color: index < _currentCycle
                            ? AppTheme.primaryColor
                            : Colors.grey[300],
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                ),
              ),
            ),

            // Breathing circle animation
            Expanded(
              child: Center(
                child: AnimatedBuilder(
                  animation: Listenable.merge([
                    _breathAnimation,
                    _pulseAnimation,
                  ]),
                  builder: (context, child) {
                    final scale = _currentPhase == 'Breathe In'
                        ? _breathAnimation.value
                        : _currentPhase == 'Hold'
                        ? 1.5
                        : 0.5;
                    final pulse = _pulseAnimation.value;

                    return Container(
                      width: 200 * scale * pulse,
                      height: 200 * scale * pulse,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: [
                            AppTheme.primaryColor.withOpacity(0.8),
                            AppTheme.secondaryColor.withOpacity(0.6),
                          ],
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: AppTheme.primaryColor.withOpacity(0.3),
                            blurRadius: 30 * scale,
                            spreadRadius: 10 * scale,
                          ),
                        ],
                      ),
                      child: Center(
                        child: Text(
                          _currentPhase,
                          style: GoogleFonts.poppins(
                            fontSize: 24,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),

            // Instructions
            Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                children: [
                  AnimatedTextKit(
                    animatedTexts: [
                      TypewriterAnimatedText(
                        _getInstructionText(),
                        textStyle: GoogleFonts.poppins(
                          fontSize: 18,
                          color: theme.colorScheme.onSurface,
                        ),
                        speed: const Duration(milliseconds: 50),
                      ),
                    ],
                    totalRepeatCount: 1,
                    displayFullTextOnTap: true,
                  ),
                  const SizedBox(height: 32),
                  Text(
                    'Cycle ${_currentCycle + 1} of $_totalCycles',
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      color: theme.colorScheme.onSurface.withOpacity(0.6),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      IconButton(
                        icon: Icon(
                          _isPaused
                              ? FontAwesomeIcons.play
                              : FontAwesomeIcons.pause,
                        ),
                        onPressed: _togglePause,
                        iconSize: 32,
                        color: AppTheme.primaryColor,
                      ),
                      const SizedBox(width: 24),
                      TextButton.icon(
                        icon: const Icon(FontAwesomeIcons.xmark),
                        label: const Text('Skip'),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getInstructionText() {
    switch (_currentPhase) {
      case 'Breathe In':
        return 'Breathe in slowly through your nose...';
      case 'Hold':
        return 'Hold your breath...';
      case 'Breathe Out':
        return 'Breathe out slowly through your mouth...';
      default:
        return 'Follow the circle and breathe naturally...';
    }
  }

  Widget _buildCompletionScreen(BuildContext context, ThemeData theme) {
    return Scaffold(
      backgroundColor: AppTheme.primaryColor.withOpacity(0.05),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                FontAwesomeIcons.circleCheck,
                size: 80,
                color: AppTheme.primaryColor,
              ),
              const SizedBox(height: 24),
              Text(
                'Great Job!',
                style: GoogleFonts.poppins(
                  fontSize: 32,
                  fontWeight: FontWeight.w700,
                  color: theme.colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'You\'ve completed your breathing exercise. How do you feel?',
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  color: theme.colorScheme.onSurface.withOpacity(0.7),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 48),
              ElevatedButton.icon(
                icon: const Icon(FontAwesomeIcons.music),
                label: const Text('Listen to Relaxing Music'),
                onPressed: () {
                  Navigator.of(context).pushReplacement(
                    MaterialPageRoute(
                      builder: (context) => const MusicRecommendationsScreen(),
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 32,
                    vertical: 16,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Done'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
