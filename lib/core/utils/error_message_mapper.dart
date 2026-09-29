import 'package:supabase_flutter/supabase_flutter.dart';

String friendlyErrorMessage(Object error) {
  if (error is AuthException) {
    final message = error.message.toLowerCase();
    if (message.contains('network') || message.contains('connection')) {
      return 'Could not connect. Check your internet and try again.';
    }
    if (message.contains('invalid') || message.contains('credentials')) {
      return 'That email or password is incorrect.';
    }
    if (message.contains('expired')) {
      return 'This link has expired. Please request a new one.';
    }
    return 'Something went wrong with your account. Please try again.';
  }

  if (error is PostgrestException) {
    return 'We could not save your changes. Please try again.';
  }

  if (error is StorageException) {
    return _storageErrorMessage(error);
  }

  final raw = error.toString().toLowerCase();
  if (raw.contains('socketexception') ||
      raw.contains('network') ||
      raw.contains('connection')) {
    return 'Internet connection interrupted. Please check your network and try again.';
  }
  if (raw.contains('timeoutexception') || raw.contains('timeout')) {
    return 'That took too long to respond. Please try again.';
  }
  if (raw.contains('permission')) {
    return 'Permission required. Please check your device settings.';
  }

  if (error is Exception) {
    final message = error.toString().replaceFirst('Exception: ', '').trim();
    if (message.isNotEmpty &&
        message.length < 120 &&
        !message.toLowerCase().contains('exception')) {
      return message;
    }
  }

  return 'Something went wrong. Please try again.';
}

String _storageErrorMessage(StorageException error) {
  final message = error.message.toLowerCase();
  if (message.contains('mime') ||
      message.contains('content-type') ||
      message.contains('content type') ||
      message.contains('unsupported') ||
      message.contains('not allowed')) {
    return 'That image type is not supported. Please use a PNG or JPEG image.';
  }
  if (message.contains('network') ||
      message.contains('connection') ||
      message.contains('socket')) {
    return 'Could not connect. Check your internet and try again.';
  }
  if (message.contains('timeout')) {
    return 'That took too long to respond. Please try again.';
  }
  if (message.contains('unauthorized') ||
      message.contains('jwt') ||
      message.contains('permission') ||
      message.contains('forbidden')) {
    return 'You do not have permission to upload this file. Please sign in again.';
  }
  return 'We could not upload that file. Please try again.';
}
