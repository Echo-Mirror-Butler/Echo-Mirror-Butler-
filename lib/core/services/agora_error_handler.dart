import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:flutter/material.dart';

enum AgoraErrorSeverity { transient, fatal }

class AgoraErrorInfo {
  final ErrorCodeType code;
  final String message;
  final AgoraErrorSeverity severity;
  final String userMessage;
  final bool shouldRetry;

  const AgoraErrorInfo({
    required this.code,
    required this.message,
    required this.severity,
    required this.userMessage,
    required this.shouldRetry,
  });
}

class AgoraErrorHandler {
  static AgoraErrorInfo classifyError(ErrorCodeType err, String msg) {
    switch (err) {
      // Transient/Recoverable Errors
      case ErrorCodeType.errNetDown:
        return AgoraErrorInfo(
          code: err,
          message: msg,
          severity: AgoraErrorSeverity.transient,
          userMessage: 'Connection issue. Reconnecting...',
          shouldRetry: true,
        );

      case ErrorCodeType.errJoinChannelRejected:
        return AgoraErrorInfo(
          code: err,
          message: msg,
          severity: AgoraErrorSeverity.transient,
          userMessage: 'Failed to join call. Retrying...',
          shouldRetry: true,
        );

      case ErrorCodeType.errAdmInitPlayout:
      case ErrorCodeType.errAdmStartPlayout:
      case ErrorCodeType.errAdmInitRecording:
      case ErrorCodeType.errAdmStartRecording:
        return AgoraErrorInfo(
          code: err,
          message: msg,
          severity: AgoraErrorSeverity.transient,
          userMessage: 'Media device issue. Attempting to recover...',
          shouldRetry: true,
        );

      // Fatal Errors
      case ErrorCodeType.errInvalidToken:
      case ErrorCodeType.errTokenExpired:
        return AgoraErrorInfo(
          code: err,
          message: msg,
          severity: AgoraErrorSeverity.fatal,
          userMessage: 'Session expired. Please start a new call.',
          shouldRetry: false,
        );

      case ErrorCodeType.errInvalidChannelName:
        return AgoraErrorInfo(
          code: err,
          message: msg,
          severity: AgoraErrorSeverity.fatal,
          userMessage: 'Invalid call session. Unable to connect.',
          shouldRetry: false,
        );

      case ErrorCodeType.errNotInitialized:
        return AgoraErrorInfo(
          code: err,
          message: msg,
          severity: AgoraErrorSeverity.fatal,
          userMessage: 'Call initialization failed. Please try again.',
          shouldRetry: false,
        );

      case ErrorCodeType.errNoPermission:
        return AgoraErrorInfo(
          code: err,
          message: msg,
          severity: AgoraErrorSeverity.fatal,
          userMessage:
              'Camera or microphone permission denied. Please enable in settings.',
          shouldRetry: false,
        );

      case ErrorCodeType.errAdmGeneralError:
        return AgoraErrorInfo(
          code: err,
          message: msg,
          severity: AgoraErrorSeverity.fatal,
          userMessage:
              'Media device error. Please check camera/microphone access.',
          shouldRetry: false,
        );

      case ErrorCodeType.errSetClientRoleNotAuthorized:
        return AgoraErrorInfo(
          code: err,
          message: msg,
          severity: AgoraErrorSeverity.fatal,
          userMessage: 'Authentication failed. Please log in again.',
          shouldRetry: false,
        );

      // Default case for unknown errors
      default:
        return AgoraErrorInfo(
          code: err,
          message: msg,
          severity: AgoraErrorSeverity.transient,
          userMessage: 'Connection issue. Attempting to reconnect...',
          shouldRetry: true,
        );
    }
  }

  static void showErrorSnackBar(
    BuildContext context,
    AgoraErrorInfo errorInfo,
  ) {
    if (!context.mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              errorInfo.severity == AgoraErrorSeverity.fatal
                  ? Icons.error_outline
                  : Icons.warning_amber_rounded,
              color: Colors.white,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                errorInfo.userMessage,
                style: const TextStyle(fontWeight: FontWeight.w500),
              ),
            ),
          ],
        ),
        backgroundColor: errorInfo.severity == AgoraErrorSeverity.fatal
            ? Colors.red.shade700
            : Colors.orange.shade700,
        duration: errorInfo.severity == AgoraErrorSeverity.fatal
            ? const Duration(seconds: 6)
            : const Duration(seconds: 4),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}
