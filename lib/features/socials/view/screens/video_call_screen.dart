import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:animate_do/animate_do.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import '../../../../core/themes/app_theme.dart';
import '../../../../core/services/pip_service.dart';
import '../../../../core/services/pip_overlay_service.dart';
import '../../viewmodel/providers/socials_provider.dart';
import '../../../auth/viewmodel/providers/auth_provider.dart';

/// Video call screen with Agora WebRTC integration
class VideoCallScreen extends ConsumerStatefulWidget {
  final String sessionId;
  final bool isHost;
  final String sessionTitle;
  final String hostName;

  const VideoCallScreen({
    super.key,
    required this.sessionId,
    required this.isHost,
    required this.sessionTitle,
    required this.hostName,
  });

  @override
  ConsumerState<VideoCallScreen> createState() => _VideoCallScreenState();
}

class _VideoCallScreenState extends ConsumerState<VideoCallScreen> {
  RtcEngine? _engine;
  int? _remoteUid;
  bool _isVideoEnabled = true;
  bool _isAudioEnabled = true;
  bool _isFrontCamera = true;
  bool _isConnected = false;
  bool _isInitialized = false;
  bool _remoteVideoEnabled = false; // Default to false until we detect video
  String? _agoraAppId;
  String? _agoraToken;
  String? _currentUserName;
  final PipService _pipService = PipService();
  bool _isPipSupported = false;
  bool _isInPipMode = false;
  bool _isNavigatingAway =
      false; // Track if we're navigating away to keep call alive

  @override
  void initState() {
    super.initState();
    WakelockPlus.enable(); // Keep screen awake during video calls
    // Hide overlay if it's showing (user expanded from PiP)
    if (PipOverlayService().isShowing) {
      PipOverlayService().hidePipOverlay();
    }
    _loadUserInfo();
    _initializePipService();
    _checkPipSupport();
    _initializeAgora();
  }

  void _initializePipService() {
    _pipService.initialize((isInPip) {
      if (mounted) {
        setState(() {
          _isInPipMode = isInPip;
        });
        debugPrint('[VideoCallScreen] PiP mode changed: $isInPip');
      }
    });
  }

  Future<void> _checkPipSupport() async {
    final isSupported = await _pipService.isPipSupported();
    final currentPipState = await _pipService.isInPipMode();
    setState(() {
      _isPipSupported = isSupported;
      _isInPipMode = currentPipState;
    });
  }

  Future<void> _loadUserInfo() async {
    try {
      final authRepository = ref.read(authRepositoryProvider);
      final currentUser = await authRepository.getCurrentUser();
      final userEmail = currentUser?['email'] as String? ?? 'User';
      setState(() {
        _currentUserName = userEmail.split('@').first;
      });
    } catch (e) {
      debugPrint('[VideoCallScreen] Error loading user info: $e');
    }
  }

  Future<void> _initializeAgora() async {
    try {
      // Check if there's an existing engine in the PiP overlay
      final pipService = PipOverlayService();
      final pipEngine = pipService.engine;
      if (pipEngine != null) {
        debugPrint('[VideoCallScreen] Reusing engine from PiP overlay');
        _engine = pipEngine;
        // Restore the remote user state from PiP
        setState(() {
          _isInitialized = true;
          _isConnected = pipService.isConnected;
          _remoteUid = pipService.remoteUid;
          _remoteVideoEnabled = pipService.remoteVideoEnabled;
        });
        // Re-register event handlers for this new screen instance
        _registerEventHandlers();
        return;
      }

      // Join the session on the backend if not the host
      if (!widget.isHost) {
        try {
          final socialsNotifier = ref.read(socialsProvider.notifier);
          await socialsNotifier.joinSession(widget.sessionId);
          debugPrint('[VideoCallScreen] Joined session: ${widget.sessionId}');
        } catch (e) {
          debugPrint(
            '[VideoCallScreen] Error joining session (continuing anyway): $e',
          );
          // Continue even if joinSession fails - the Agora call can still work
        }
      }

      // Get Agora credentials from server
      final repository = ref.read(socialsRepositoryProvider);
      final credentials = await repository.getAgoraCredentials(
        widget.sessionId,
        widget.isHost ? 0 : 1, // Use session ID as user ID
      );

      _agoraAppId = credentials['appId'];
      _agoraToken = credentials['token'];
      final channelName = credentials['channelName'] ?? widget.sessionId;
      final uid = int.tryParse(credentials['uid'] ?? '0') ?? 0;

      if (_agoraAppId == null || _agoraAppId!.isEmpty) {
        throw Exception('Agora App ID not configured');
      }

      // Create Agora engine
      _engine = createAgoraRtcEngine();
      await _engine!.initialize(
        RtcEngineContext(
          appId: _agoraAppId!,
          channelProfile: ChannelProfileType.channelProfileCommunication,
        ),
      );

      // Enable video
      debugPrint('[VideoCallScreen] Enabling video...');
      await _engine!.enableVideo();
      debugPrint('[VideoCallScreen] Video enabled, starting preview...');
      await _engine!.startPreview();
      debugPrint('[VideoCallScreen] Preview started');

      // Ensure local video is enabled by default
      await _engine!.enableLocalVideo(true);
      debugPrint('[VideoCallScreen] Local video enabled');

      // Set event handlers
      _registerEventHandlers();

      // Join channel
      await _engine!.joinChannel(
        token: (_agoraToken == null || _agoraToken!.isEmpty)
            ? ''
            : _agoraToken!,
        channelId: channelName,
        uid: uid,
        options: const ChannelMediaOptions(
          clientRoleType: ClientRoleType.clientRoleBroadcaster,
          channelProfile: ChannelProfileType.channelProfileCommunication,
        ),
      );

      setState(() {
        _isInitialized = true;
      });
    } catch (e) {
      debugPrint('[VideoCallScreen] Error initializing Agora: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error initializing video call: $e'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    }
  }

  void _registerEventHandlers() {
    _engine?.registerEventHandler(
      RtcEngineEventHandler(
        onJoinChannelSuccess: (RtcConnection connection, int elapsed) {
          if (mounted) {
            setState(() {
              _isConnected = true;
            });
          }
        },
        onUserJoined: (RtcConnection connection, int remoteUid, int elapsed) {
          debugPrint('[VideoCallScreen] User joined: $remoteUid');
          if (mounted) {
            setState(() {
              _remoteUid = remoteUid;
              _remoteVideoEnabled =
                  false; // Start with avatar until video is confirmed
            });
          }
          // Update overlay if it's showing
          if (PipOverlayService().isShowing) {
            PipOverlayService().updateRemoteUid(remoteUid);
          }
        },
        onUserOffline:
            (
              RtcConnection connection,
              int remoteUid,
              UserOfflineReasonType reason,
            ) {
              debugPrint(
                '[VideoCallScreen] User offline: $remoteUid (reason: $reason)',
              );
              if (mounted) {
                setState(() {
                  _remoteUid = null;
                  _remoteVideoEnabled = false;
                });
              }
              // Update overlay if it's showing
              if (PipOverlayService().isShowing) {
                PipOverlayService().updateRemoteUid(null);
              }
            },
        onRemoteVideoStateChanged:
            (
              RtcConnection connection,
              int remoteUid,
              RemoteVideoState state,
              RemoteVideoStateReason reason,
              int elapsed,
            ) {
              debugPrint(
                '[VideoCallScreen] Remote video state changed: $state, reason: $reason',
              );
              final videoEnabled =
                  state == RemoteVideoState.remoteVideoStateStarting ||
                  state == RemoteVideoState.remoteVideoStateDecoding;
              if (mounted) {
                setState(() {
                  _remoteVideoEnabled = videoEnabled;
                });
              }
              // Update overlay if it's showing
              if (PipOverlayService().isShowing) {
                PipOverlayService().updateRemoteVideoState(videoEnabled);
              }
            },
        onError: (ErrorCodeType err, String msg) {
          debugPrint('Agora error: $err - $msg');
        },
      ),
    );
  }

  void _toggleVideo() {
    setState(() {
      _isVideoEnabled = !_isVideoEnabled;
    });
    _engine?.enableLocalVideo(_isVideoEnabled);
  }

  void _toggleAudio() {
    setState(() {
      _isAudioEnabled = !_isAudioEnabled;
    });
    _engine?.muteLocalAudioStream(!_isAudioEnabled);
  }

  void _switchCamera() {
    _engine?.switchCamera();
    setState(() {
      _isFrontCamera = !_isFrontCamera;
    });
  }

  Future<void> _handleBackButton() async {
    // Show in-app PiP overlay and navigate back, keeping the call active
    try {
      if (!_isConnected) {
        // Not connected, just navigate back
        if (mounted) {
          Navigator.pop(context);
        }
        return;
      }

      // Set flag to prevent call from ending when we navigate away
      _isNavigatingAway = true;

      // Show in-app PiP overlay
      final pipOverlay = PipOverlayService();
      // Capture the ref and sessionId in closures before widget might be disposed
      final socialsNotifier = ref.read(socialsProvider.notifier);
      final sessionId = widget.sessionId;
      final sessionTitle = widget.sessionTitle;
      final hostName = widget.hostName;
      final isHost = widget.isHost;

      pipOverlay.showPipOverlay(
        context: context,
        engine: _engine!,
        remoteUid: _remoteUid,
        sessionId: sessionId,
        hostName: hostName,
        remoteVideoEnabled: _remoteVideoEnabled,
        isHost: isHost,
        sessionTitle: sessionTitle,
        onTapToExpand: (overlayContext) {
          // User tapped to expand - navigate back to call screen
          _isNavigatingAway = false;
          // Navigate back to video call screen using overlay's context
          Navigator.push(
            overlayContext,
            MaterialPageRoute(
              builder: (context) => VideoCallScreen(
                sessionId: sessionId,
                isHost: isHost,
                sessionTitle: sessionTitle,
                hostName: hostName,
              ),
            ),
          );
        },
        onLeaveCall: () async {
          // User tapped close button on overlay
          // Clean up engine and overlay
          WakelockPlus.disable();
          await pipOverlay.engine?.leaveChannel();
          await pipOverlay.engine?.release();
          // Try to leave session (might fail if widget is disposed, that's OK)
          try {
            await socialsNotifier.leaveSession(sessionId);
          } catch (e) {
            debugPrint(
              '[VideoCallScreen] Error leaving session from overlay: $e',
            );
          }
          PipOverlayService().disposeOverlay();
        },
      );

      // Update overlay when video state changes
      _setupOverlayUpdates(pipOverlay);

      // Small delay to ensure overlay is shown
      await Future.delayed(const Duration(milliseconds: 100));

      // Navigate back - call continues in floating overlay
      if (mounted) {
        Navigator.pop(context);
      }
    } catch (e) {
      debugPrint('[VideoCallScreen] Error handling back button: $e');
      _isNavigatingAway = false;
      // If error, show confirmation dialog
      if (mounted) {
        final shouldLeave = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Leave Video Call?'),
            content: const Text('Do you want to end the call?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text(
                  'End Call',
                  style: TextStyle(color: Colors.red),
                ),
              ),
            ],
          ),
        );

        if (shouldLeave == true && mounted) {
          await _leaveCall();
        }
      }
    }
  }

  void _setupOverlayUpdates(PipOverlayService pipOverlay) {
    // Overlay updates are handled in the event handlers above
    // This method is kept for potential future use
  }

  Future<void> _togglePipMode() async {
    try {
      // Check current state
      final currentState = await _pipService.isInPipMode();

      if (!currentState) {
        // Enter PiP mode
        final success = await _pipService.enterPipMode();
        if (success) {
          if (Platform.isIOS) {
            // On iOS, PiP activates automatically when app backgrounds
            debugPrint(
              '[VideoCallScreen] PiP ready - will activate when app backgrounds',
            );
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                    'Press home button to activate Picture-in-Picture',
                  ),
                  duration: Duration(seconds: 3),
                ),
              );
            }
          } else {
            // Android - PiP is triggered immediately
            debugPrint(
              '[VideoCallScreen] Entered PiP mode - you can now navigate the app',
            );
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                    'Call minimized to Picture-in-Picture. Navigate freely!',
                  ),
                  duration: Duration(seconds: 3),
                ),
              );
            }
          }
        } else {
          debugPrint('[VideoCallScreen] Failed to enter PiP mode');
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('PiP mode not available'),
                backgroundColor: AppTheme.errorColor,
              ),
            );
          }
        }
      } else {
        // Already in PiP mode - user needs to tap the PiP window to exit
        debugPrint(
          '[VideoCallScreen] Already in PiP mode - tap the floating window to expand',
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Tap the floating window to expand'),
              duration: Duration(seconds: 2),
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('[VideoCallScreen] Error toggling PiP mode: $e');
    }
  }

  Future<void> _leaveCall() async {
    try {
      WakelockPlus.disable(); // Allow screen to sleep when leaving call

      // Clean up the PiP overlay and engine
      PipOverlayService().disposeOverlay();

      await _engine?.leaveChannel();
      await _engine?.release();

      await ref.read(socialsProvider.notifier).leaveSession(widget.sessionId);

      // Check if we can pop before actually popping
      if (mounted && Navigator.canPop(context)) {
        Navigator.pop(context);
      }
    } catch (e) {
      debugPrint('[VideoCallScreen] Error leaving call: $e');
      // Don't try to pop on error, just clean up
    }
  }

  @override
  void dispose() {
    // Only end the call if we're not navigating away (PiP mode)
    if (!_isNavigatingAway) {
      WakelockPlus.disable(); // Allow screen to sleep again
      _engine?.leaveChannel();
      _engine?.release();
      // Clean up the overlay if it's showing
      if (PipOverlayService().isShowing) {
        PipOverlayService().disposeOverlay();
      }
    } else {
      // We're navigating away in PiP mode - keep the engine alive
      // The call will continue in the PiP window
      debugPrint(
        '[VideoCallScreen] Navigating away in PiP mode - keeping call active',
      );
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (!didPop) {
          await _handleBackButton();
        }
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: SafeArea(
          child: Stack(
            children: [
              // Remote video (main view)
              if (_isConnected && _remoteUid != null)
                Positioned.fill(
                  child: Stack(
                    children: [
                      // Show video only when remote video is enabled
                      if (_remoteVideoEnabled)
                        AgoraVideoView(
                          controller: VideoViewController.remote(
                            rtcEngine: _engine!,
                            canvas: VideoCanvas(uid: _remoteUid),
                            connection: RtcConnection(
                              channelId: widget.sessionId,
                            ),
                          ),
                        )
                      else
                        // Show colored box with name when camera is off (like Google Meet)
                        _buildCameraOffView(),
                    ],
                  ),
                )
              else if (_isConnected)
                Positioned.fill(
                  child: Container(
                    color: Colors.black,
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const CircularProgressIndicator(
                            color: AppTheme.primaryColor,
                          ),
                          const SizedBox(height: 24),
                          Text(
                            'Waiting for others to join...',
                            style: GoogleFonts.poppins(
                              fontSize: 18,
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                )
              else
                Positioned.fill(
                  child: Container(
                    color: Colors.black,
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const CircularProgressIndicator(
                            color: AppTheme.primaryColor,
                          ),
                          const SizedBox(height: 24),
                          Text(
                            'Connecting...',
                            style: GoogleFonts.poppins(
                              fontSize: 18,
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

              // Local video (picture-in-picture)
              if (_isInitialized)
                Positioned(
                  top: 16,
                  right: 16,
                  child: FadeInDown(
                    child: Container(
                      width: 120,
                      height: 160,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.white, width: 2),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.3),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: _isVideoEnabled
                          ? AgoraVideoView(
                              controller: VideoViewController(
                                rtcEngine: _engine!,
                                canvas: const VideoCanvas(uid: 0),
                              ),
                            )
                          : Container(
                              color: AppTheme.darkBackgroundColor,
                              child: Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Container(
                                      width: 50,
                                      height: 50,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: AppTheme.primaryColor,
                                      ),
                                      child: Center(
                                        child: Text(
                                          _currentUserName != null &&
                                                  _currentUserName!.isNotEmpty
                                              ? _currentUserName![0]
                                                    .toUpperCase()
                                              : 'Y',
                                          style: GoogleFonts.poppins(
                                            fontSize: 24,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      _currentUserName ?? 'You',
                                      style: GoogleFonts.poppins(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.white,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                    ),
                  ),
                ),

              // Back button (top-left)
              Positioned(
                top: 16,
                left: 16,
                child: FadeInDown(
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: _handleBackButton,
                      borderRadius: BorderRadius.circular(25),
                      child: Container(
                        width: 50,
                        height: 50,
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.6),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.3),
                            width: 1,
                          ),
                        ),
                        child: const Icon(
                          Icons.arrow_back,
                          color: Colors.white,
                          size: 24,
                        ),
                      ),
                    ),
                  ),
                ),
              ),

              // Top bar with session info
              Positioned(
                top: 16,
                left: 74, // Adjust to make room for back button
                right: 140,
                child: FadeInDown(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.6),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: _isConnected ? Colors.green : Colors.red,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            widget.isHost ? 'Hosting Session' : 'In Session',
                            style: GoogleFonts.poppins(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // Bottom controls
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 32,
                  ),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        Colors.black.withValues(alpha: 0.8),
                      ],
                    ),
                  ),
                  child: SafeArea(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _buildControlButton(
                          icon: _isVideoEnabled
                              ? FontAwesomeIcons.video
                              : FontAwesomeIcons.videoSlash,
                          label: _isVideoEnabled ? 'Video On' : 'Video Off',
                          isActive: _isVideoEnabled,
                          onTap: _toggleVideo,
                        ),
                        _buildControlButton(
                          icon: _isAudioEnabled
                              ? FontAwesomeIcons.microphone
                              : FontAwesomeIcons.microphoneSlash,
                          label: _isAudioEnabled ? 'Mic On' : 'Mic Off',
                          isActive: _isAudioEnabled,
                          onTap: _toggleAudio,
                        ),
                        _buildControlButton(
                          icon: FontAwesomeIcons.rotate,
                          label: 'Switch',
                          isActive: true,
                          onTap: _switchCamera,
                        ),
                        if (_isPipSupported)
                          _buildControlButton(
                            icon: _isInPipMode
                                ? FontAwesomeIcons.windowMaximize
                                : FontAwesomeIcons.upRightAndDownLeftFromCenter,
                            label: _isInPipMode ? 'Minimized' : 'Minimize',
                            isActive: !_isInPipMode,
                            onTap: _togglePipMode,
                          ),
                        _buildControlButton(
                          icon: FontAwesomeIcons.phone,
                          label: 'Leave',
                          isActive: false,
                          isDanger: true,
                          onTap: _leaveCall,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCameraOffView() {
    final displayName = widget.hostName.isNotEmpty
        ? widget.hostName
        : 'Participant';
    final firstLetter = displayName.isNotEmpty
        ? displayName[0].toUpperCase()
        : '?';

    // Generate a consistent color based on the name (like Google Meet)
    final colors = [
      const Color(0xFF4285F4), // Blue
      const Color(0xFF34A853), // Green
      const Color(0xFFEA4335), // Red
      const Color(0xFFFBBC05), // Yellow
      const Color(0xFF9C27B0), // Purple
      const Color(0xFF00BCD4), // Cyan
      const Color(0xFFFF9800), // Orange
      const Color(0xFFE91E63), // Pink
    ];
    final colorIndex = displayName.hashCode.abs() % colors.length;
    final avatarColor = colors[colorIndex];

    return Container(
      color: AppTheme.darkBackgroundColor,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Colored box with initial (Google Meet style)
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: avatarColor,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: avatarColor.withValues(alpha: 0.3),
                    blurRadius: 20,
                    spreadRadius: 5,
                  ),
                ],
              ),
              child: Center(
                child: Text(
                  firstLetter,
                  style: GoogleFonts.poppins(
                    fontSize: 56,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              displayName,
              style: GoogleFonts.poppins(
                fontSize: 24,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const FaIcon(
                    FontAwesomeIcons.videoSlash,
                    color: Colors.white70,
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Camera Off',
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      color: Colors.white70,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildControlButton({
    required IconData icon,
    required String label,
    required bool isActive,
    required VoidCallback onTap,
    bool isDanger = false,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onTap: onTap,
          child: Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: isDanger
                  ? Colors.red
                  : (isActive
                        ? Colors.white.withValues(alpha: 0.2)
                        : Colors.red.withValues(alpha: 0.8)),
              shape: BoxShape.circle,
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.3),
                width: 2,
              ),
            ),
            child: Center(child: FaIcon(icon, color: Colors.white, size: 24)),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: 12,
            color: Colors.white,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}
