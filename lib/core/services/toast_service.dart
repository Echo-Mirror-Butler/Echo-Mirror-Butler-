import 'package:flutter/material.dart';
import '../themes/app_theme.dart';
import '../utils/error_message_mapper.dart';
import 'app_logger.dart';

class ToastService {
  ToastService._();

  static void success(BuildContext context, String message) {
    _show(context, message, AppTheme.successColor);
  }

  static void info(BuildContext context, String message) {
    _show(context, message, AppTheme.primaryColor);
  }

  static void errorMessage(BuildContext context, String message) {
    _show(context, message, AppTheme.errorColor);
  }

  static void error(
    BuildContext context,
    Object error, {
    String label = 'ToastService',
    StackTrace? stackTrace,
  }) {
    AppLogger.error(label, error, stackTrace);
    _show(context, friendlyErrorMessage(error), AppTheme.errorColor);
  }

  static void _show(BuildContext context, String message, Color color) {
    if (message.trim().isEmpty) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
      ),
    );
  }
}
