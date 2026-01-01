import 'package:flutter/material.dart';
import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:google_fonts/google_fonts.dart';
import '../themes/app_theme.dart';

/// Service for managing in-app Picture-in-Picture overlay
class PipOverlayService {
  static final PipOverlayService _instance = PipOverlayService._internal();
  factory PipOverlayService() => _instance;
  PipOverlayService._internal();

  OverlayEntry? _overlayEntry;
  bool _isShowing = false;
  RtcEngine? _engine;
  
  // Getter for the engine instance and state
  RtcEngine? get engine => _engine;
  int? get remoteUid => _remoteUid;
  bool get remoteVideoEnabled => _remoteVideoEnabled;
  bool get isConnected => _remoteUid != null;
  
  int? _remoteUid;
  String? _sessionId;
  String? _hostName;
  bool _remoteVideoEnabled = true;
  void Function(BuildContext)? _onTapToExpand;
  Function()? _onLeaveCall;
  
  // Store navigation parameters to recreate the screen
  bool? _isHost;
  String? _sessionTitle;

  /// Show PiP overlay (floating window inside the app)
  void showPipOverlay({
    required BuildContext context,
    required RtcEngine engine,
    required int? remoteUid,
    required String sessionId,
    required String hostName,
    required bool remoteVideoEnabled,
    required void Function(BuildContext) onTapToExpand,
    required VoidCallback onLeaveCall,
    bool? isHost,
    String? sessionTitle,
  }) {
    if (_isShowing) return;

    _engine = engine;
    _remoteUid = remoteUid;
    _sessionId = sessionId;
    _hostName = hostName;
    _remoteVideoEnabled = remoteVideoEnabled;
    _onTapToExpand = onTapToExpand;
    _onLeaveCall = onLeaveCall;
    _isHost = isHost;
    _sessionTitle = sessionTitle;

    _overlayEntry = _createOverlayEntry();
    Overlay.of(context).insert(_overlayEntry!);
    _isShowing = true;
  }
  
  /// Navigate back to video call screen (called when user taps overlay to expand)
  void navigateToVideoCallScreen(BuildContext context) {
    if (_sessionId == null) return;
    
    // Import VideoCallScreen dynamically to avoid circular dependency
    // We'll use a callback instead
    if (_onTapToExpand != null) {
      _onTapToExpand!(context);
    }
  }

  /// Hide PiP overlay
  void hidePipOverlay() {
    if (!_isShowing || _overlayEntry == null) return;
    
    _overlayEntry?.remove();
    _overlayEntry = null;
    _isShowing = false;
  }
  
  /// Clean up and dispose the overlay (when ending the call)
  void disposeOverlay() {
    hidePipOverlay();
    _engine = null;
    _remoteUid = null;
    _sessionId = null;
    _hostName = null;
    _onTapToExpand = null;
    _onLeaveCall = null;
  }

  /// Update remote video state
  void updateRemoteVideoState(bool enabled) {
    _remoteVideoEnabled = enabled;
    if (_isShowing && _overlayEntry != null) {
      _overlayEntry?.markNeedsBuild();
    }
  }

  /// Update remote UID
  void updateRemoteUid(int? uid) {
    _remoteUid = uid;
    if (_isShowing && _overlayEntry != null) {
      _overlayEntry?.markNeedsBuild();
    }
  }

  /// Check if overlay is showing
  bool get isShowing => _isShowing;

  OverlayEntry _createOverlayEntry() {
    return OverlayEntry(
      builder: (context) => _PipOverlayWidget(
        engine: _engine!,
        remoteUid: _remoteUid,
        sessionId: _sessionId!,
        hostName: _hostName!,
        remoteVideoEnabled: _remoteVideoEnabled,
        isHost: _isHost,
        sessionTitle: _sessionTitle,
        onTap: (overlayContext) {
          _onTapToExpand?.call(overlayContext);
          hidePipOverlay();
        },
        onLeave: () {
          _onLeaveCall?.call();
          hidePipOverlay();
        },
        onUpdate: () {
          // Rebuild overlay when state changes
          if (_isShowing && _overlayEntry != null) {
            _overlayEntry?.markNeedsBuild();
          }
        },
      ),
    );
  }
}

/// Floating PiP widget that appears on top of all screens
class _PipOverlayWidget extends StatefulWidget {
  final RtcEngine engine;
  final int? remoteUid;
  final String sessionId;
  final String hostName;
  final bool remoteVideoEnabled;
  final bool? isHost;
  final String? sessionTitle;
  final void Function(BuildContext) onTap;
  final VoidCallback onLeave;
  final VoidCallback onUpdate;

  const _PipOverlayWidget({
    required this.engine,
    required this.remoteUid,
    required this.sessionId,
    required this.hostName,
    required this.remoteVideoEnabled,
    this.isHost,
    this.sessionTitle,
    required this.onTap,
    required this.onLeave,
    required this.onUpdate,
  });

  @override
  State<_PipOverlayWidget> createState() => _PipOverlayWidgetState();
}

class _PipOverlayWidgetState extends State<_PipOverlayWidget> {
  bool _isDragging = false;
  Offset _position = const Offset(20, 100);
  final GlobalKey _key = GlobalKey();

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: _position.dx,
      top: _position.dy,
      child: Material(
        color: Colors.transparent,
        child: GestureDetector(
        onPanUpdate: (details) {
          setState(() {
            _isDragging = true;
            _position += details.delta;
            // Keep within screen bounds
            final screenWidth = MediaQuery.of(context).size.width;
            final screenHeight = MediaQuery.of(context).size.height;
            _position = Offset(
              _position.dx.clamp(0.0, screenWidth - 150),
              _position.dy.clamp(0.0, screenHeight - 200),
            );
          });
        },
        onPanEnd: (_) {
          setState(() {
            _isDragging = false;
          });
        },
        onTap: () => widget.onTap(context),
        child: Container(
          key: _key,
          width: 150,
          height: 200,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: Colors.white,
              width: 2,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.5),
                blurRadius: 20,
                spreadRadius: 5,
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: Stack(
            children: [
              // Video or avatar
              if (widget.remoteUid != null)
                widget.remoteVideoEnabled
                    ? AgoraVideoView(
                        controller: VideoViewController.remote(
                          rtcEngine: widget.engine,
                          canvas: VideoCanvas(uid: widget.remoteUid),
                          connection: RtcConnection(channelId: widget.sessionId),
                        ),
                      )
                    : _buildCameraOffView()
              else
                Container(
                  color: AppTheme.darkBackgroundColor,
                  child: const Center(
                    child: CircularProgressIndicator(),
                  ),
                ),

              // Tap to expand hint
              if (!_isDragging)
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Colors.black.withOpacity(0.6),
                        ],
                      ),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Text(
                            'Tap to expand',
                            style: GoogleFonts.poppins(
                              fontSize: 10,
                              color: Colors.white,
                              fontWeight: FontWeight.w500,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

              // Close button
              Positioned(
                top: 4,
                right: 4,
                child: GestureDetector(
                  onTap: widget.onLeave,
                  child: Container(
                    width: 24,
                    height: 24,
                    decoration: const BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.close,
                      color: Colors.white,
                      size: 16,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      ),
    );
  }

  Widget _buildCameraOffView() {
    final firstLetter = widget.hostName.isNotEmpty
        ? widget.hostName[0].toUpperCase()
        : '?';
    
    final colors = [
      const Color(0xFF4285F4),
      const Color(0xFF34A853),
      const Color(0xFFEA4335),
      const Color(0xFFFBBC05),
      const Color(0xFF9C27B0),
      const Color(0xFF00BCD4),
      const Color(0xFFFF9800),
      const Color(0xFFE91E63),
    ];
    final colorIndex = widget.hostName.hashCode.abs() % colors.length;
    final avatarColor = colors[colorIndex];

    return Container(
      color: AppTheme.darkBackgroundColor,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: avatarColor,
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  firstLetter,
                  style: GoogleFonts.poppins(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8.0),
              child: Text(
                widget.hostName,
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

