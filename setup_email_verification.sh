#!/bin/bash

# EchoMirror Email Verification Setup Script
# This script helps set up email verification for the Serverpod backend

set -e

echo "🪞 EchoMirror Email Verification Setup"
echo "======================================"
echo ""

# Check if server directory exists
SERVER_DIR="/Users/macbookpro/echomirror_server/echomirror_server_server"
if [ ! -d "$SERVER_DIR" ]; then
  echo "❌ Server directory not found at $SERVER_DIR"
  echo "Please make sure your Serverpod server is set up first."
  exit 1
fi

echo "✅ Found server directory"
echo ""

# Navigate to server
cd "$SERVER_DIR"

# Add mailer package
echo "📦 Adding mailer package to pubspec.yaml..."
if grep -q "mailer:" pubspec.yaml; then
  echo "   ℹ️  mailer package already added"
else
  # Add mailer to dependencies
  sed -i '' '/^dependencies:/a\
  mailer: ^6.0.0
' pubspec.yaml
  echo "   ✅ mailer package added"
fi

# Get dependencies
echo ""
echo "📥 Getting dependencies..."
dart pub get

# Create services directory if it doesn't exist
echo ""
echo "📁 Creating services directory..."
mkdir -p lib/src/services

# Create email service file
EMAIL_SERVICE_FILE="lib/src/services/email_service.dart"
if [ -f "$EMAIL_SERVICE_FILE" ]; then
  echo "   ℹ️  email_service.dart already exists, skipping..."
else
  echo "   Creating email_service.dart..."
  cat > "$EMAIL_SERVICE_FILE" << 'EOF'
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

  Future<bool> sendVerificationEmail({
    required String toEmail,
    required String verificationCode,
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
        ..subject = 'Welcome to EchoMirror - Verify Your Email'
        ..html = _buildVerificationEmailHtml(verificationCode)
        ..text = _buildVerificationEmailText(verificationCode);

      final sendReport = await send(message, smtpServer);
      print('[EmailService] ✅ Email sent to $toEmail');
      return true;
    } catch (e) {
      print('[EmailService] ❌ Error sending email to $toEmail: $e');
      return false;
    }
  }

  String _buildVerificationEmailHtml(String code) {
    return '''
<!DOCTYPE html>
<html>
<head>
  <meta charset="UTF-8">
  <style>
    body { font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto; padding: 20px; }
    .header { text-align: center; margin-bottom: 30px; }
    .logo { font-size: 48px; margin-bottom: 10px; }
    .code-box { background: #f3f4f6; padding: 30px; text-align: center; border-radius: 8px; margin: 20px 0; }
    .code { font-size: 36px; font-weight: bold; color: #6366f1; letter-spacing: 5px; font-family: monospace; }
    .warning { background: #fef3c7; padding: 15px; margin: 20px 0; border-radius: 4px; border-left: 4px solid #f59e0b; }
  </style>
</head>
<body>
  <div class="header">
    <div class="logo">🪞</div>
    <h2>Welcome to EchoMirror!</h2>
  </div>
  <p>Thank you for signing up! Use this verification code:</p>
  <div class="code-box">
    <div class="code">$code</div>
  </div>
  <div class="warning">
    <strong>⏰ Expires in 15 minutes</strong>
  </div>
  <p>If you didn't request this, please ignore this email.</p>
</body>
</html>
''';
  }

  String _buildVerificationEmailText(String code) {
    return '''
Welcome to EchoMirror!

Your verification code: $code

This code expires in 15 minutes.

If you didn't request this, please ignore this email.
''';
  }
}
EOF
  echo "   ✅ email_service.dart created"
fi

echo ""
echo "✅ Setup complete!"
echo ""
echo "📝 Next steps:"
echo ""
echo "1. Configure email credentials in config/passwords.yaml:"
echo ""
echo "   development:"
echo "     emailSmtpHost: 'smtp.gmail.com'"
echo "     emailSmtpPort: '587'"
echo "     emailUsername: 'your-email@gmail.com'"
echo "     emailPassword: 'your-app-password'"
echo "     emailFromAddress: 'your-email@gmail.com'"
echo ""
echo "2. Update lib/src/server.dart to use EmailService"
echo "   (See SERVERPOD_EMAIL_SETUP.md for complete instructions)"
echo ""
echo "3. Restart your Serverpod server:"
echo "   cd $SERVER_DIR"
echo "   dart run bin/main.dart"
echo ""
echo "📖 For detailed instructions, see: SERVERPOD_EMAIL_SETUP.md"
echo ""

