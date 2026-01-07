# Serverpod Email Verification Setup

This guide explains how to configure Serverpod to automatically send verification codes via email instead of only showing them in server logs.

## Overview

Currently, when a user signs up:
1. `startRegistration` is called on the backend
2. A verification code is generated
3. The code only appears in server logs (not sent to email)
4. User must manually retrieve the code from logs

**Goal:** Automatically send the verification code to the user's email.

## Prerequisites

- Serverpod server running
- SMTP email service (Gmail, SendGrid, AWS SES, etc.)
- Email credentials

## Step 1: Install Email Package

In your server project (`echomirror_server_server`), add the `mailer` package to `pubspec.yaml`:

```bash
cd /Users/macbookpro/echomirror_server/echomirror_server_server
```

Add to `pubspec.yaml`:

```yaml
dependencies:
  serverpod: ^2.0.0
  mailer: ^6.0.0  # Add this
  # ... other dependencies
```

Then run:

```bash
dart pub get
```

## Step 2: Create Email Service

Create a new file: `lib/src/services/email_service.dart`

```dart
import 'package:mailer/mailer.dart';
import 'package:mailer/smtp_server.dart';
import 'package:serverpod/serverpod.dart';

class EmailService {
  final String _smtpHost;
  final int _smtpPort;
  final String _username;
  final String _password;
  final String _fromEmail;
  final String _fromName;

  EmailService({
    required String smtpHost,
    required int smtpPort,
    required String username,
    required String password,
    required String fromEmail,
    String fromName = 'EchoMirror',
  })  : _smtpHost = smtpHost,
        _smtpPort = smtpPort,
        _username = username,
        _password = password,
        _fromEmail = fromEmail,
        _fromName = fromName;

  /// Send verification code email
  Future<bool> sendVerificationEmail({
    required String toEmail,
    required String verificationCode,
  }) async {
    try {
      // Configure SMTP server
      final smtpServer = SmtpServer(
        _smtpHost,
        port: _smtpPort,
        username: _username,
        password: _password,
        ssl: _smtpPort == 465,
        allowInsecure: false,
      );

      // Create email message
      final message = Message()
        ..from = Address(_fromEmail, _fromName)
        ..recipients.add(toEmail)
        ..subject = 'Welcome to EchoMirror - Verify Your Email'
        ..html = _buildVerificationEmailHtml(verificationCode)
        ..text = _buildVerificationEmailText(verificationCode);

      // Send email
      final sendReport = await send(message, smtpServer);
      print('[EmailService] Email sent to $toEmail: ${sendReport.toString()}');
      return true;
    } catch (e) {
      print('[EmailService] Error sending email to $toEmail: $e');
      return false;
    }
  }

  /// Build HTML email template
  String _buildVerificationEmailHtml(String code) {
    return '''
<!DOCTYPE html>
<html>
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <style>
    body {
      font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Helvetica, Arial, sans-serif;
      line-height: 1.6;
      color: #333;
      max-width: 600px;
      margin: 0 auto;
      padding: 20px;
    }
    .container {
      background: #ffffff;
      border-radius: 10px;
      padding: 30px;
      box-shadow: 0 2px 4px rgba(0,0,0,0.1);
    }
    .header {
      text-align: center;
      margin-bottom: 30px;
    }
    .logo {
      font-size: 32px;
      font-weight: bold;
      color: #6366f1;
      margin-bottom: 10px;
    }
    .code-container {
      background: #f3f4f6;
      border-radius: 8px;
      padding: 20px;
      text-align: center;
      margin: 30px 0;
    }
    .code {
      font-size: 32px;
      font-weight: bold;
      color: #6366f1;
      letter-spacing: 5px;
      font-family: 'Courier New', monospace;
    }
    .footer {
      text-align: center;
      margin-top: 30px;
      font-size: 12px;
      color: #6b7280;
    }
    .warning {
      background: #fef3c7;
      border-left: 4px solid #f59e0b;
      padding: 15px;
      margin: 20px 0;
      border-radius: 4px;
    }
  </style>
</head>
<body>
  <div class="container">
    <div class="header">
      <div class="logo">🪞 EchoMirror</div>
      <h2>Welcome to EchoMirror!</h2>
      <p>Your future self is excited to meet you.</p>
    </div>

    <p>Thank you for signing up! To complete your registration, please use the verification code below:</p>

    <div class="code-container">
      <div class="code">$code</div>
    </div>

    <div class="warning">
      <strong>⏰ Important:</strong> This code will expire in 15 minutes.
    </div>

    <p>If you didn't request this code, please ignore this email.</p>

    <div class="footer">
      <p>This is an automated email. Please do not reply.</p>
      <p>&copy; ${DateTime.now().year} EchoMirror. All rights reserved.</p>
    </div>
  </div>
</body>
</html>
''';
  }

  /// Build plain text email template
  String _buildVerificationEmailText(String code) {
    return '''
Welcome to EchoMirror!

Thank you for signing up! To complete your registration, please use the verification code below:

VERIFICATION CODE: $code

This code will expire in 15 minutes.

If you didn't request this code, please ignore this email.

---
This is an automated email. Please do not reply.
© ${DateTime.now().year} EchoMirror. All rights reserved.
''';
  }

  /// Send password reset email
  Future<bool> sendPasswordResetEmail({
    required String toEmail,
    required String resetCode,
  }) async {
    try {
      final smtpServer = SmtpServer(
        _smtpHost,
        port: _smtpPort,
        username: _username,
        password: _password,
        ssl: _smtpPort == 465,
        allowInsecure: false,
      );

      final message = Message()
        ..from = Address(_fromEmail, _fromName)
        ..recipients.add(toEmail)
        ..subject = 'EchoMirror - Password Reset Request'
        ..html = _buildPasswordResetEmailHtml(resetCode)
        ..text = _buildPasswordResetEmailText(resetCode);

      final sendReport = await send(message, smtpServer);
      print('[EmailService] Password reset email sent to $toEmail');
      return true;
    } catch (e) {
      print('[EmailService] Error sending password reset email: $e');
      return false;
    }
  }

  String _buildPasswordResetEmailHtml(String code) {
    return '''
<!DOCTYPE html>
<html>
<head>
  <meta charset="UTF-8">
  <style>
    body { font-family: Arial, sans-serif; line-height: 1.6; color: #333; }
    .container { max-width: 600px; margin: 0 auto; padding: 20px; }
    .code { font-size: 28px; font-weight: bold; color: #6366f1; letter-spacing: 3px; }
  </style>
</head>
<body>
  <div class="container">
    <h2>🔐 Password Reset Request</h2>
    <p>You requested to reset your EchoMirror password. Use this code:</p>
    <p class="code">$code</p>
    <p><strong>This code expires in 15 minutes.</strong></p>
    <p>If you didn't request this, please ignore this email.</p>
  </div>
</body>
</html>
''';
  }

  String _buildPasswordResetEmailText(String code) {
    return '''
Password Reset Request

You requested to reset your EchoMirror password. Use this code:

RESET CODE: $code

This code expires in 15 minutes.

If you didn't request this, please ignore this email.
''';
  }
}
```

## Step 3: Configure Email in Server

Update `lib/src/server.dart` to initialize and use the email service:

```dart
import 'package:serverpod/serverpod.dart';
import 'package:serverpod_auth_server/serverpod_auth_server.dart';
import 'services/email_service.dart';

class Server extends Serverpod {
  late final EmailService emailService;

  @override
  Future<void> initialize() async {
    await super.initialize();

    // Initialize email service
    emailService = EmailService(
      smtpHost: passwords['emailSmtpHost'] ?? 'smtp.gmail.com',
      smtpPort: int.tryParse(passwords['emailSmtpPort'] ?? '587') ?? 587,
      username: passwords['emailUsername'] ?? '',
      password: passwords['emailPassword'] ?? '',
      fromEmail: passwords['emailFromAddress'] ?? 'noreply@echomirror.app',
      fromName: 'EchoMirror',
    );

    // Configure auth callbacks
    AuthConfig.set(AuthConfig(
      // Send verification email callback
      sendVerificationCodeEmail: (session, email, code) async {
        print('[Auth] Sending verification code to $email: $code');
        await emailService.sendVerificationEmail(
          toEmail: email,
          verificationCode: code,
        );
      },
      // Send password reset email callback
      sendPasswordResetEmail: (session, email, code) async {
        print('[Auth] Sending password reset code to $email');
        await emailService.sendPasswordResetEmail(
          toEmail: email,
          resetCode: code,
        );
      },
    ));
  }
}
```

## Step 4: Configure Email Credentials

### Option A: Using Gmail (for development)

1. Enable 2-Factor Authentication on your Gmail account
2. Generate an App Password:
   - Go to Google Account Settings
   - Security → 2-Step Verification → App passwords
   - Create a new app password

3. Add to `config/passwords.yaml`:

```yaml
production:
  emailSmtpHost: 'smtp.gmail.com'
  emailSmtpPort: '587'
  emailUsername: 'your-email@gmail.com'
  emailPassword: 'your-app-password-here'
  emailFromAddress: 'your-email@gmail.com'

development:
  emailSmtpHost: 'smtp.gmail.com'
  emailSmtpPort: '587'
  emailUsername: 'your-email@gmail.com'
  emailPassword: 'your-app-password-here'
  emailFromAddress: 'your-email@gmail.com'
```

### Option B: Using SendGrid (recommended for production)

1. Sign up at [SendGrid](https://sendgrid.com/)
2. Create an API key
3. Add to `config/passwords.yaml`:

```yaml
production:
  emailSmtpHost: 'smtp.sendgrid.net'
  emailSmtpPort: '587'
  emailUsername: 'apikey'
  emailPassword: 'YOUR_SENDGRID_API_KEY'
  emailFromAddress: 'noreply@yourdomain.com'

development:
  emailSmtpHost: 'smtp.sendgrid.net'
  emailSmtpPort: '587'
  emailUsername: 'apikey'
  emailPassword: 'YOUR_SENDGRID_API_KEY'
  emailFromAddress: 'noreply@yourdomain.com'
```

### Option C: Using AWS SES (production)

```yaml
production:
  emailSmtpHost: 'email-smtp.us-east-1.amazonaws.com'
  emailSmtpPort: '587'
  emailUsername: 'YOUR_AWS_SES_USERNAME'
  emailPassword: 'YOUR_AWS_SES_PASSWORD'
  emailFromAddress: 'noreply@yourdomain.com'
```

## Step 5: Restart Server

```bash
cd /Users/macbookpro/echomirror_server/echomirror_server_server

# Stop the server if running (Ctrl+C)

# Restart
dart run bin/main.dart
```

## Step 6: Test Email Verification

1. Run your Flutter app
2. Sign up with a real email address
3. Check your email inbox for the verification code
4. The code should also still appear in server logs as a backup

## Troubleshooting

### Email not sending

**Check server logs** for error messages:
```bash
tail -f /Users/macbookpro/echomirror_server/echomirror_server_server/logs/serverpod.log
```

**Common issues:**

1. **Gmail blocking:**
   - Ensure 2FA is enabled
   - Use App Password, not regular password
   - Check "Less secure app access" (not recommended)

2. **SMTP credentials wrong:**
   - Verify `passwords.yaml` has correct credentials
   - Check port number (587 for TLS, 465 for SSL)

3. **Email in spam:**
   - Check spam/junk folder
   - Add sender to contacts

4. **SendGrid issues:**
   - Verify domain if using custom domain
   - Check API key permissions
   - Verify sender identity

### Code not received

1. Check server logs: `grep "verification code" logs/serverpod.log`
2. Verify email service is initialized: check for `[EmailService]` logs
3. Test SMTP connection manually

### Production considerations

1. **Use a dedicated email service** (SendGrid, AWS SES, Mailgun)
2. **Verify your domain** for better deliverability
3. **Monitor email quotas** and rate limits
4. **Set up SPF, DKIM, and DMARC** records
5. **Handle bounces and complaints**
6. **Log all email attempts** for debugging

## Update Frontend

The Flutter app already handles email verification correctly. Just update the message in `verification_screen.dart` to be more confident:

```dart
Text(
  'We sent a verification code to\n${widget.email}',
  style: theme.textTheme.bodyMedium,
  textAlign: TextAlign.center,
),
const SizedBox(height: 8),
Text(
  'Check your inbox (and spam folder) for the code.',
  style: theme.textTheme.bodySmall?.copyWith(
    fontStyle: FontStyle.italic,
  ),
  textAlign: TextAlign.center,
),
```

Remove the development note about checking server logs once email is working.

## Alternative: Mailtrap (for testing)

For testing without sending real emails, use [Mailtrap](https://mailtrap.io/):

```yaml
development:
  emailSmtpHost: 'sandbox.smtp.mailtrap.io'
  emailSmtpPort: '587'
  emailUsername: 'your-mailtrap-username'
  emailPassword: 'your-mailtrap-password'
  emailFromAddress: 'noreply@echomirror.app'
```

Mailtrap captures all emails in a test inbox without delivering them.

## Summary

Once configured:
1. ✅ User signs up
2. ✅ Verification code generated
3. ✅ Email automatically sent
4. ✅ Code also logged (backup)
5. ✅ User receives email
6. ✅ User enters code
7. ✅ Registration complete

The verification code will be sent to the user's email automatically, while still appearing in the logs for development/debugging purposes.

