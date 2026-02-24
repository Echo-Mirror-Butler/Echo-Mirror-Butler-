import 'dart:io';

import 'package:serverpod/serverpod.dart';
import 'package:serverpod_auth_idp_server/core.dart';
import 'package:serverpod_auth_idp_server/providers/email.dart';

import 'src/generated/endpoints.dart';
import 'src/generated/protocol.dart';
import 'src/web/routes/root.dart';
import 'src/tasks/cleanup_task.dart';
import 'src/services/resend_email_service.dart';

/// Email service instance (initialized on server start)
ResendEmailService? _emailService;

/// The starting point of the Serverpod server.
void run(List<String> args) async {
  // Initialize Serverpod and connect it with your generated code.
  final pod = Serverpod(args, Protocol(), Endpoints());

  // Initialize Resend email service
  try {
    final resendApiKey = pod.getPassword('resendApiKey');
    final fromEmail = pod.getPassword('emailFromAddress') ?? 'noreply@echomirror.app';
    
    if (resendApiKey != null && resendApiKey.isNotEmpty) {
      _emailService = ResendEmailService(
        apiKey: resendApiKey,
        fromEmail: fromEmail,
        fromName: 'EchoMirror',
      );
      print('[Server] ✅ Resend email service initialized');
      print('[Server] 📧 Sending from: $fromEmail');
    } else {
      print('[Server] ⚠️  Resend API key not configured');
      print('[Server] ℹ️  Verification codes will only appear in logs');
    }
  } catch (e) {
    print('[Server] ⚠️  Email service initialization failed: $e');
    print('[Server] ℹ️  Verification codes will only appear in logs');
  }

  // Initialize authentication services for the server.
  // Token managers will be used to validate and issue authentication keys,
  // and the identity providers will be the authentication options available for users.
  pod.initializeAuthServices(
    tokenManagerBuilders: [
      // Use JWT for authentication keys towards the server.
      // In Serverpod Cloud, secrets are injected as environment variables.
      // Fall back to passwords.yaml for local development.
      _createJwtConfig(),
    ],
    identityProviderBuilders: [
      // Configure the email identity provider for email/password authentication.
      // In Serverpod Cloud, secrets are injected as environment variables.
      // Fall back to passwords.yaml for local development.
      _createEmailIdpConfig(
        sendRegistrationVerificationCode: _sendRegistrationCode,
        sendPasswordResetVerificationCode: _sendPasswordResetCode,
      ),
    ],
  );

  // Register Global Mirror cleanup task
  CleanupTask.register(pod);

  // Setup a default page at the web root.
  pod.webServer.addRoute(RootRoute(), '/');
  pod.webServer.addRoute(RootRoute(), '/index.html');

  // Serve all files in the web/static relative directory under /static.
  // Note: Using /static/* instead of /** to avoid route conflicts in Serverpod 3.1+
  final root = Directory(Uri(path: 'web/static').toFilePath());
  if (root.existsSync()) {
    pod.webServer.addRoute(StaticRoute.directory(root), '/static/*');
  }

  // Start the server.
  await pod.start();
}

void _sendRegistrationCode(
  Session session, {
  required String email,
  required UuidValue accountRequestId,
  required String verificationCode,
  required Transaction? transaction,
}) async {
  // Always log the code (useful for development/debugging)
  session.log('[EmailIdp] 📧 Registration code for $email: $verificationCode');

  // Send email asynchronously (don't block the session)
  // Use print() instead of session.log() since session may close
  if (_emailService != null) {
    _emailService!
        .sendVerificationEmail(
      toEmail: email,
      verificationCode: verificationCode,
    )
        .then((sent) {
      if (sent) {
        print('[EmailIdp] ✅ Verification email sent to $email');
      } else {
        print('[EmailIdp] ⚠️  Failed to send verification email to $email');
      }
    }).catchError((e) {
      print('[EmailIdp] ❌ Error sending verification email: $e');
    });
  } else {
    print('[EmailIdp] ℹ️  Email service not configured - code only logged');
  }
}

void _sendPasswordResetCode(
  Session session, {
  required String email,
  required UuidValue passwordResetRequestId,
  required String verificationCode,
  required Transaction? transaction,
}) async {
  // Always log the code (useful for development/debugging)
  session.log(
    '[EmailIdp] 🔑 Password reset code for $email: $verificationCode',
  );

  // Send email asynchronously (don't block the session)
  // Use print() instead of session.log() since session may close
  if (_emailService != null) {
    _emailService!
        .sendPasswordResetEmail(
      toEmail: email,
      resetCode: verificationCode,
    )
        .then((sent) {
      if (sent) {
        print('[EmailIdp] ✅ Password reset email sent to $email');
      } else {
        print('[EmailIdp] ⚠️  Failed to send password reset email to $email');
      }
    }).catchError((e) {
      print('[EmailIdp] ❌ Error sending password reset email: $e');
    });
  } else {
    print('[EmailIdp] ℹ️  Email service not configured - code only logged');
  }
}

/// Creates JWT config from environment variables (Serverpod Cloud) or passwords file (local)
TokenManagerBuilder _createJwtConfig() {
  // JwtConfigFromPasswords reads from passwords.yaml
  // In Serverpod Cloud, we need to ensure secrets are accessible
  // For now, use the standard approach - Serverpod Cloud should handle secret injection
  return JwtConfigFromPasswords();
}

/// Creates Email IDP config from environment variables (Serverpod Cloud) or passwords file (local)
IdentityProviderBuilder _createEmailIdpConfig({
  required void Function(
    Session session, {
    required String email,
    required UuidValue accountRequestId,
    required String verificationCode,
    required Transaction? transaction,
  })
  sendRegistrationVerificationCode,
  required void Function(
    Session session, {
    required String email,
    required UuidValue passwordResetRequestId,
    required String verificationCode,
    required Transaction? transaction,
  })
  sendPasswordResetVerificationCode,
}) {
  // EmailIdpConfigFromPasswords reads from passwords.yaml
  // In Serverpod Cloud, we need to ensure secrets are accessible
  // For now, use the standard approach - Serverpod Cloud should handle secret injection
  return EmailIdpConfigFromPasswords(
    sendRegistrationVerificationCode: sendRegistrationVerificationCode,
    sendPasswordResetVerificationCode: sendPasswordResetVerificationCode,
  );
}
