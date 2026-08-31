import 'package:flutter/material.dart';
import 'error_message_mapper.dart';
import '../services/toast_service.dart';

/// Utility class for handling and displaying errors
class ErrorHandler {
  ErrorHandler._();

  /// Show a snackbar with error message
  static void showError(BuildContext context, String message) {
    ToastService.errorMessage(context, message);
  }

  /// Show a snackbar with success message
  static void showSuccess(BuildContext context, String message) {
    ToastService.success(context, message);
  }

  /// Show a dialog with error details
  static Future<void> showErrorDialog(
    BuildContext context,
    String title,
    String message,
  ) async {
    return showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(title),
          content: Text(message),
          actions: <Widget>[
            TextButton(
              child: const Text('OK'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  /// Extract error message from exception
  static String getErrorMessage(dynamic error) {
    if (error is String) {
      return error;
    }
    return friendlyErrorMessage(error as Object);
  }
}
