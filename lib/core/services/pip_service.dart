import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';

/// Service for managing Picture-in-Picture mode
class PipService {
  static const MethodChannel _channel = MethodChannel('com.echomirror.app/pip');
  static final PipService _instance = PipService._internal();
  factory PipService() => _instance;
  PipService._internal();

  bool _isInPipMode = false;
  Function(bool)? _onPipModeChanged;

  /// Initialize the PiP service and set up event listener
  void initialize(Function(bool) onPipModeChanged) {
    _onPipModeChanged = onPipModeChanged;
    _channel.setMethodCallHandler(_handleMethodCall);
  }

  /// Handle method calls from native side
  Future<dynamic> _handleMethodCall(MethodCall call) async {
    switch (call.method) {
      case 'onPipModeChanged':
        final isInPip = call.arguments as bool;
        _isInPipMode = isInPip;
        _onPipModeChanged?.call(isInPip);
        debugPrint('[PipService] PiP mode changed: $isInPip');
        break;
      default:
        debugPrint('[PipService] Unknown method call: ${call.method}');
    }
  }

  /// Check if PiP mode is supported on this device
  Future<bool> isPipSupported() async {
    try {
      final result = await _channel.invokeMethod<bool>('isPipSupported');
      return result ?? false;
    } catch (e) {
      debugPrint('[PipService] Error checking PiP support: $e');
      return false;
    }
  }

  /// Check if currently in PiP mode
  Future<bool> isInPipMode() async {
    try {
      final result = await _channel.invokeMethod<bool>('isInPipMode');
      _isInPipMode = result ?? false;
      return _isInPipMode;
    } catch (e) {
      debugPrint('[PipService] Error checking PiP mode state: $e');
      return _isInPipMode;
    }
  }

  /// Enter Picture-in-Picture mode
  Future<bool> enterPipMode() async {
    try {
      final result = await _channel.invokeMethod<bool>('enterPipMode');
      if (result == true) {
        _isInPipMode = true;
      }
      return result ?? false;
    } catch (e) {
      debugPrint('[PipService] Error entering PiP mode: $e');
      return false;
    }
  }

  /// Get current PiP mode state (cached)
  bool get isInPipModeSync => _isInPipMode;
}
