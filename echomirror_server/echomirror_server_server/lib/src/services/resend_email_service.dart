import 'dart:convert';
import 'package:http/http.dart' as http;

/// Email service using Resend API
/// Resend is a modern email API designed for developers
/// Free tier: 3,000 emails/month, 100 emails/day
class ResendEmailService {
  final String _apiKey;
  final String _fromEmail;
  final String _fromName;

  ResendEmailService({
    required String apiKey,
    required String fromEmail,
    String fromName = 'EchoMirror',
  })  : _apiKey = apiKey,
        _fromEmail = fromEmail,
        _fromName = fromName;

  Future<bool> sendVerificationEmail({
    required String toEmail,
    required String verificationCode,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('https://api.resend.com/emails'),
        headers: {
          'Authorization': 'Bearer $_apiKey',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'from': '$_fromName <$_fromEmail>',
          'to': [toEmail],
          'subject': 'Verify Your EchoMirror Account',
          'html': _buildVerificationEmailHtml(verificationCode),
        }),
      );

      if (response.statusCode == 200) {
        print('[ResendEmail] ✅ Verification email sent to $toEmail');
        return true;
      } else {
        print(
            '[ResendEmail] ⚠️  Failed to send email. Status: ${response.statusCode}, Body: ${response.body}');
        return false;
      }
    } catch (e) {
      print('[ResendEmail] ❌ Error sending verification email: $e');
      return false;
    }
  }

  Future<bool> sendPasswordResetEmail({
    required String toEmail,
    required String resetCode,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('https://api.resend.com/emails'),
        headers: {
          'Authorization': 'Bearer $_apiKey',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'from': '$_fromName <$_fromEmail>',
          'to': [toEmail],
          'subject': 'Reset Your EchoMirror Password',
          'html': _buildPasswordResetEmailHtml(resetCode),
        }),
      );

      if (response.statusCode == 200) {
        print('[ResendEmail] ✅ Password reset email sent to $toEmail');
        return true;
      } else {
        print(
            '[ResendEmail] ⚠️  Failed to send email. Status: ${response.statusCode}, Body: ${response.body}');
        return false;
      }
    } catch (e) {
      print('[ResendEmail] ❌ Error sending password reset email: $e');
      return false;
    }
  }

  String _buildVerificationEmailHtml(String code) {
    return '''
<!DOCTYPE html>
<html>
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <style>
    body {
      font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, 'Helvetica Neue', Arial, sans-serif;
      line-height: 1.6;
      color: #333;
      max-width: 600px;
      margin: 0 auto;
      padding: 20px;
    }
    .container {
      background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
      border-radius: 10px;
      padding: 40px;
      text-align: center;
    }
    .content {
      background: white;
      border-radius: 8px;
      padding: 30px;
      margin-top: 20px;
    }
    .code {
      font-size: 32px;
      font-weight: bold;
      letter-spacing: 8px;
      color: #667eea;
      background: #f7f7f7;
      padding: 20px;
      border-radius: 8px;
      margin: 20px 0;
      font-family: 'Courier New', monospace;
    }
    .logo {
      font-size: 36px;
      font-weight: bold;
      color: white;
      margin-bottom: 10px;
    }
    .subtitle {
      color: rgba(255, 255, 255, 0.9);
      font-size: 16px;
    }
    .footer {
      margin-top: 30px;
      font-size: 12px;
      color: #999;
      text-align: center;
    }
  </style>
</head>
<body>
  <div class="container">
    <div class="logo">🪞 EchoMirror</div>
    <div class="subtitle">Your Mental Wellness Companion</div>
    
    <div class="content">
      <h2 style="color: #333; margin-top: 0;">Welcome to EchoMirror!</h2>
      <p>Thank you for signing up. To complete your registration, please enter this verification code in the app:</p>
      
      <div class="code">$code</div>
      
      <p style="color: #666; font-size: 14px;">This code will expire in 15 minutes.</p>
      <p style="color: #666; font-size: 14px;">If you didn't request this code, you can safely ignore this email.</p>
    </div>
  </div>
  
  <div class="footer">
    <p>© 2026 EchoMirror. All rights reserved.</p>
    <p>This is an automated message, please do not reply.</p>
  </div>
</body>
</html>
''';
  }

  String _buildPasswordResetEmailHtml(String code) {
    return '''
<!DOCTYPE html>
<html>
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <style>
    body {
      font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, 'Helvetica Neue', Arial, sans-serif;
      line-height: 1.6;
      color: #333;
      max-width: 600px;
      margin: 0 auto;
      padding: 20px;
    }
    .container {
      background: linear-gradient(135deg, #f093fb 0%, #f5576c 100%);
      border-radius: 10px;
      padding: 40px;
      text-align: center;
    }
    .content {
      background: white;
      border-radius: 8px;
      padding: 30px;
      margin-top: 20px;
    }
    .code {
      font-size: 32px;
      font-weight: bold;
      letter-spacing: 8px;
      color: #f5576c;
      background: #f7f7f7;
      padding: 20px;
      border-radius: 8px;
      margin: 20px 0;
      font-family: 'Courier New', monospace;
    }
    .logo {
      font-size: 36px;
      font-weight: bold;
      color: white;
      margin-bottom: 10px;
    }
    .subtitle {
      color: rgba(255, 255, 255, 0.9);
      font-size: 16px;
    }
    .footer {
      margin-top: 30px;
      font-size: 12px;
      color: #999;
      text-align: center;
    }
  </style>
</head>
<body>
  <div class="container">
    <div class="logo">🪞 EchoMirror</div>
    <div class="subtitle">Your Mental Wellness Companion</div>
    
    <div class="content">
      <h2 style="color: #333; margin-top: 0;">Password Reset Request</h2>
      <p>We received a request to reset your password. Enter this code in the app to continue:</p>
      
      <div class="code">$code</div>
      
      <p style="color: #666; font-size: 14px;">This code will expire in 15 minutes.</p>
      <p style="color: #ff6b6b; font-size: 14px; font-weight: bold;">If you didn't request this, please ignore this email and your password will remain unchanged.</p>
    </div>
  </div>
  
  <div class="footer">
    <p>© 2026 EchoMirror. All rights reserved.</p>
    <p>This is an automated message, please do not reply.</p>
  </div>
</body>
</html>
''';
  }
}

