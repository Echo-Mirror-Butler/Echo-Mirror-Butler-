import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:lottie/lottie.dart';
import '../../../../core/themes/app_theme.dart';
import 'music_recommendations_screen.dart';

/// Breathing exercise screen with guided breathing and animations
class BreathingExerciseScreen extends ConsumerStatefulWidget {
  const BreathingExerciseScreen({super.key});

  @override
  ConsumerState<BreathingExerciseScreen> createState() =>
      _BreathingExerciseScreenState();
}

class _BreathingExerciseScreenState
    extends ConsumerState<BreathingExerciseScreen>
    with TickerProviderStateMixin {
  late AnimationController _breathController;
  late AnimationController _pulseController;
  late AnimationController _fadeController;
  late Animation<double> _breathAnimation;
  late Animation<double> _pulseAnimation;
  late Animation<double> _fadeAnimation;
  final FlutterTts _tts = FlutterTts();
  final AudioPlayer _audioPlayer = AudioPlayer();

  int _currentCycle = 0;
  final int _totalCycles = 5;
  String _currentPhase = 'Get Ready';
  bool _isPaused = false;
  bool _isCompleted = false;
  bool _hasSpokenForPhase = false;
  bool _isMusicPlaying = true;
  String? _selectedFeeling;

  // Calming ambient music URL (peaceful meditation/ambient track)
  // Using a reliable free ambient sound source
  // Alternative sources if this fails:
  // - https://www.soundhelix.com/examples/mp3/SoundHelix-Song-1.mp3
  // - Or use local asset (add to assets/ folder and pubspec.yaml)
  static const String _ambientMusicUrl =
      'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-1.mp3';

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

    _breathAnimation = Tween<double>(begin: 0.7, end: 1.4).animate(
      CurvedAnimation(parent: _breathController, curve: Curves.easeInOut),
    );

    _pulseAnimation = Tween<double>(begin: 0.95, end: 1.05).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _fadeController, curve: Curves.easeIn));

    _initializeTts();
    _startBackgroundMusic();
    _startBreathing();
  }

  Future<void> _startBackgroundMusic() async {
    try {
      await _audioPlayer.setReleaseMode(ReleaseMode.loop);
      await _audioPlayer.setVolume(
        0.25,
      ); // Low volume so it doesn't overpower voice

      // Try to play the music, with timeout
      await _audioPlayer
          .play(UrlSource(_ambientMusicUrl))
          .timeout(
            const Duration(seconds: 5),
            onTimeout: () {
              debugPrint('Music playback timed out - continuing without music');
              setState(() => _isMusicPlaying = false);
              throw TimeoutException('Music load timeout');
            },
          );

      // Check if playback actually started
      final state = _audioPlayer.state;
      if (state == PlayerState.stopped || state == PlayerState.completed) {
        setState(() => _isMusicPlaying = false);
        debugPrint('Music failed to start - continuing without music');
      }
    } catch (e) {
      // Music is optional, continue without it if it fails
      debugPrint('Could not play background music: $e');
      setState(() => _isMusicPlaying = false);
    }
  }

  Future<void> _toggleMusic() async {
    if (!_isMusicPlaying) {
      // Try to start music if it wasn't playing
      try {
        await _audioPlayer.setReleaseMode(ReleaseMode.loop);
        await _audioPlayer.setVolume(0.25);
        await _audioPlayer
            .play(UrlSource(_ambientMusicUrl))
            .timeout(const Duration(seconds: 3));
        setState(() => _isMusicPlaying = true);
      } catch (e) {
        debugPrint('Could not start music: $e');
        // Keep music off if it fails
      }
    } else {
      await _audioPlayer.pause();
      setState(() => _isMusicPlaying = false);
    }
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

    // Only speak on first cycle to avoid repetition
    final shouldSpeak = _currentCycle == 0;

    // Breathe in (4 seconds)
    setState(() {
      _currentPhase = 'Breathe In';
      _hasSpokenForPhase = false;
    });
    _fadeController.forward().then((_) => _fadeController.reverse());
    if (shouldSpeak && !_hasSpokenForPhase) {
      _hasSpokenForPhase = true;
      await _tts.speak('Breathe in');
    }
    await Future.delayed(const Duration(seconds: 4));

    if (!_isPaused && mounted) {
      // Hold (7 seconds)
      setState(() {
        _currentPhase = 'Hold';
        _hasSpokenForPhase = false;
      });
      _fadeController.forward().then((_) => _fadeController.reverse());
      if (shouldSpeak && !_hasSpokenForPhase) {
        _hasSpokenForPhase = true;
        await _tts.speak('Hold');
      }
      await Future.delayed(const Duration(seconds: 7));
    }

    if (!_isPaused && mounted) {
      // Breathe out (8 seconds)
      setState(() {
        _currentPhase = 'Breathe Out';
        _hasSpokenForPhase = false;
      });
      _fadeController.forward().then((_) => _fadeController.reverse());
      if (shouldSpeak && !_hasSpokenForPhase) {
        _hasSpokenForPhase = true;
        await _tts.speak('Breathe out');
      }
      await Future.delayed(const Duration(seconds: 8));
    }
  }

  void _completeSession() async {
    setState(() {
      _isCompleted = true;
      _currentPhase = 'Complete';
    });
    await _audioPlayer.stop();
    _tts.speak('Well done');
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
    _fadeController.dispose();
    _tts.stop();
    _audioPlayer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (_isCompleted) {
      return _buildCompletionScreen(context, theme);
    }

    return Scaffold(
      backgroundColor: const Color(0xFF1A1A2E),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              const Color(0xFF16213E),
              const Color(0xFF0F3460),
              const Color(0xFF1A1A2E),
            ],
          ),
        ),
        child: Stack(
          children: [
            // Subtle Lottie background animation
            Positioned.fill(
              child: Opacity(
                opacity: 0.1,
                child: Lottie.asset(
                  'assets/lottie/sparkle.json',
                  fit: BoxFit.cover,
                  repeat: true,
                  errorBuilder: (context, error, stackTrace) {
                    return const SizedBox.shrink();
                  },
                ),
              ),
            ),
            Column(
              children: [
                // Custom AppBar with music toggle
                SafeArea(
                  bottom: false,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    child: Row(
                      children: [
                        IconButton(
                          icon: const Icon(
                            Icons.arrow_back,
                            color: Colors.white,
                          ),
                          onPressed: () {
                            _audioPlayer.stop();
                            Navigator.of(context).pop();
                          },
                        ),
                        Expanded(
                          child: Text(
                            'Breathing Exercise',
                            style: GoogleFonts.poppins(
                              fontWeight: FontWeight.w600,
                              fontSize: 18,
                              color: Colors.white,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                        IconButton(
                          icon: Icon(
                            _isMusicPlaying
                                ? FontAwesomeIcons.volumeHigh
                                : FontAwesomeIcons.volumeOff,
                            size: 20,
                            color: Colors.white,
                          ),
                          onPressed: _toggleMusic,
                          tooltip: _isMusicPlaying
                              ? 'Mute music'
                              : 'Play music',
                        ),
                      ],
                    ),
                  ),
                ),
                // Progress indicator
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 16,
                  ),
                  child: Row(
                    children: List.generate(
                      _totalCycles,
                      (index) => Expanded(
                        child: Container(
                          height: 6,
                          margin: EdgeInsets.only(
                            right: index < _totalCycles - 1 ? 8 : 0,
                          ),
                          decoration: BoxDecoration(
                            color: index < _currentCycle
                                ? AppTheme.primaryColor
                                : index == _currentCycle
                                ? AppTheme.primaryColor.withValues(alpha: 0.5)
                                : Colors.white.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(3),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),

                // Breathing circle animation with text outside
                Expanded(
                  child: FadeTransition(
                    opacity: _fadeAnimation,
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        return SingleChildScrollView(
                          child: ConstrainedBox(
                            constraints: BoxConstraints(
                              minHeight: constraints.maxHeight,
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                // Phase text above circle with smooth transitions
                                AnimatedSwitcher(
                                  duration: const Duration(milliseconds: 300),
                                  transitionBuilder: (child, animation) {
                                    return FadeTransition(
                                      opacity: animation,
                                      child: SlideTransition(
                                        position: Tween<Offset>(
                                          begin: const Offset(0, 0.1),
                                          end: Offset.zero,
                                        ).animate(animation),
                                        child: child,
                                      ),
                                    );
                                  },
                                  child: Text(
                                    _currentPhase,
                                    key: ValueKey<String>(_currentPhase),
                                    style: GoogleFonts.poppins(
                                      fontSize: 38,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.white,
                                      letterSpacing: 1.5,
                                      shadows: [
                                        Shadow(
                                          color: _getPhaseColor().withValues(alpha: 
                                            0.5,
                                          ),
                                          blurRadius: 20,
                                        ),
                                      ],
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                                SizedBox(height: constraints.maxHeight * 0.06),
                                // Animated breathing circle with multiple rings
                                AnimatedBuilder(
                                  animation: Listenable.merge([
                                    _breathAnimation,
                                    _pulseAnimation,
                                  ]),
                                  builder: (context, child) {
                                    final scale = _currentPhase == 'Breathe In'
                                        ? _breathAnimation.value
                                        : _currentPhase == 'Hold'
                                        ? 1.4
                                        : _currentPhase == 'Breathe Out'
                                        ? 1.4 -
                                              ((_breathAnimation.value - 0.7) *
                                                  0.7)
                                        : 0.9;

                                    return Stack(
                                      alignment: Alignment.center,
                                      children: [
                                        // Outer glow ring
                                        Container(
                                          width:
                                              220 *
                                              scale *
                                              _pulseAnimation.value,
                                          height:
                                              220 *
                                              scale *
                                              _pulseAnimation.value,
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            gradient: RadialGradient(
                                              colors: [
                                                _getPhaseColor().withValues(alpha: 
                                                  0.15,
                                                ),
                                                _getPhaseColor().withValues(alpha: 
                                                  0.0,
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                        // Main circle
                                        Container(
                                          width: 180 * scale,
                                          height: 180 * scale,
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            gradient: RadialGradient(
                                              colors: [
                                                _getPhaseColor().withValues(alpha: 
                                                  0.9,
                                                ),
                                                _getPhaseColor().withValues(alpha: 
                                                  0.6,
                                                ),
                                              ],
                                            ),
                                            boxShadow: [
                                              BoxShadow(
                                                color: _getPhaseColor()
                                                    .withValues(alpha: 0.5),
                                                blurRadius: 50 * scale,
                                                spreadRadius: 8 * scale,
                                              ),
                                            ],
                                          ),
                                        ),
                                        // Inner highlight
                                        Container(
                                          width: 120 * scale,
                                          height: 120 * scale,
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            color: Colors.white.withValues(alpha: 
                                              0.3,
                                            ),
                                          ),
                                        ),
                                      ],
                                    );
                                  },
                                ),
                                SizedBox(height: constraints.maxHeight * 0.06),
                                // Instruction text below circle
                                AnimatedSwitcher(
                                  duration: const Duration(milliseconds: 300),
                                  child: Text(
                                    _getInstructionText(),
                                    key: ValueKey<String>(_currentPhase),
                                    style: GoogleFonts.poppins(
                                      fontSize: 20,
                                      color: Colors.white.withValues(alpha: 0.9),
                                      fontWeight: FontWeight.w500,
                                      shadows: [
                                        const Shadow(
                                          color: Colors.black26,
                                          blurRadius: 8,
                                        ),
                                      ],
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),

                // Controls and progress
                SafeArea(
                  top: false,
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      children: [
                        Text(
                          'Cycle ${_currentCycle + 1} of $_totalCycles',
                          style: GoogleFonts.poppins(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.white.withValues(alpha: 0.8),
                          ),
                        ),
                        const SizedBox(height: 28),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            // Pause/Play button
                            Container(
                              decoration: BoxDecoration(
                                color: AppTheme.primaryColor,
                                borderRadius: BorderRadius.circular(50),
                                boxShadow: [
                                  BoxShadow(
                                    color: AppTheme.primaryColor.withValues(alpha: 
                                      0.3,
                                    ),
                                    blurRadius: 15,
                                    offset: const Offset(0, 5),
                                  ),
                                ],
                              ),
                              child: Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(50),
                                  onTap: _togglePause,
                                  child: Padding(
                                    padding: const EdgeInsets.all(16),
                                    child: Icon(
                                      _isPaused
                                          ? FontAwesomeIcons.play
                                          : FontAwesomeIcons.pause,
                                      color: Colors.white,
                                      size: 24,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 32),
                            // Exit button
                            TextButton(
                              onPressed: () {
                                _audioPlayer.stop();
                                Navigator.of(context).pop();
                              },
                              style: TextButton.styleFrom(
                                foregroundColor: theme.colorScheme.onSurface
                                    .withValues(alpha: 0.6),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 20,
                                  vertical: 12,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    FontAwesomeIcons.xmark,
                                    size: 18,
                                    color: Colors.white.withValues(alpha: 0.9),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Exit',
                                    style: GoogleFonts.poppins(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w500,
                                      color: Colors.white.withValues(alpha: 0.9),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Color _getPhaseColor() {
    switch (_currentPhase) {
      case 'Breathe In':
        return AppTheme.primaryColor;
      case 'Hold':
        return AppTheme.secondaryColor;
      case 'Breathe Out':
        return const Color(0xFF6B8DD6);
      default:
        return AppTheme.primaryColor;
    }
  }

  String _getInstructionText() {
    switch (_currentPhase) {
      case 'Breathe In':
        return 'Inhale through your nose';
      case 'Hold':
        return 'Hold gently';
      case 'Breathe Out':
        return 'Exhale through your mouth';
      default:
        return 'Follow the circle';
    }
  }

  Widget _buildCompletionScreen(BuildContext context, ThemeData theme) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A2E),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              const Color(0xFF16213E),
              const Color(0xFF0F3460),
              const Color(0xFF1A1A2E),
            ],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
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
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'You\'ve completed your breathing exercise.\nHow did you feel after the breathing exercise?',
                  style: GoogleFonts.poppins(
                    fontSize: 18,
                    color: Colors.white.withValues(alpha: 0.9),
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),

                // Feeling options
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  alignment: WrapAlignment.center,
                  children: [
                    _buildFeelingChip('😌', 'Calm', Colors.blue),
                    _buildFeelingChip('😊', 'Happy', Colors.green),
                    _buildFeelingChip('😐', 'Neutral', Colors.grey),
                    _buildFeelingChip('😟', 'Anxious', Colors.orange),
                    _buildFeelingChip('😔', 'Stressed', Colors.red),
                  ],
                ),

                // Recommendations based on selected feeling
                if (_selectedFeeling != null) ...[
                  const SizedBox(height: 32),
                  _buildRecommendation(),
                ],

                const SizedBox(height: 48),
                ElevatedButton.icon(
                  icon: const Icon(FontAwesomeIcons.music),
                  label: const Text('Listen to Relaxing Music'),
                  onPressed: () {
                    Navigator.of(context).pushReplacement(
                      MaterialPageRoute(
                        builder: (context) =>
                            const MusicRecommendationsScreen(),
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
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.white.withValues(alpha: 0.8),
                  ),
                  child: Text('Done', style: GoogleFonts.poppins(fontSize: 16)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFeelingChip(String emoji, String label, Color color) {
    final isSelected = _selectedFeeling == label;
    return GestureDetector(
      onTap: () => setState(() => _selectedFeeling = label),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected
              ? color.withValues(alpha: 0.3)
              : Colors.white.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(25),
          border: Border.all(
            color: isSelected ? color : Colors.white.withValues(alpha: 0.3),
            width: 2,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(emoji, style: const TextStyle(fontSize: 24)),
            const SizedBox(width: 8),
            Text(
              label,
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecommendation() {
    final recommendations = {
      'Calm': {
        'title': '🌟 Wonderful!',
        'message': 'Your breathing is working! To maintain this calm state:',
        'tips': [
          'Continue practicing deep breathing throughout the day',
          'Try meditation or yoga to deepen relaxation',
          'Listen to calming music or nature sounds',
        ],
      },
      'Happy': {
        'title': '🎉 Excellent!',
        'message': 'You\'re feeling great! Keep up the positive momentum:',
        'tips': [
          'Share your happiness - connect with loved ones',
          'Try energizing activities like dancing or walking',
          'Journal about what made you feel this way',
        ],
      },
      'Neutral': {
        'title': '💙 That\'s okay!',
        'message':
            'Feeling neutral is normal. Try these to feel more energized:',
        'tips': [
          'Take a short walk outdoors for fresh air',
          'Try another breathing exercise later',
          'Listen to uplifting music or podcasts',
        ],
      },
      'Anxious': {
        'title': '🫂 We\'re here for you',
        'message': 'Anxiety can be tough. Let\'s work through it together:',
        'tips': [
          'Repeat the breathing exercise - it helps!',
          'Try progressive muscle relaxation',
          'Write down your worries to process them',
          'Consider talking to a professional if it persists',
        ],
      },
      'Stressed': {
        'title': '💚 Take it easy',
        'message': 'Stress is challenging. Here\'s what can help:',
        'tips': [
          'Take breaks throughout your day',
          'Practice the 4-7-8 breathing technique more often',
          'Try gentle stretching or a warm bath',
          'Reach out for professional support if needed',
        ],
      },
    };

    final rec = recommendations[_selectedFeeling]!;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            rec['title'] as String,
            style: GoogleFonts.poppins(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            rec['message'] as String,
            style: GoogleFonts.poppins(
              fontSize: 14,
              color: Colors.white.withValues(alpha: 0.9),
            ),
          ),
          const SizedBox(height: 16),
          ...(rec['tips'] as List<String>).map(
            (tip) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '• ',
                    style: TextStyle(
                      color: AppTheme.primaryColor,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Expanded(
                    child: Text(
                      tip,
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        color: Colors.white.withValues(alpha: 0.85),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
