import 'package:mailer/mailer.dart';
import 'package:mailer/smtp_server.dart';

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
  }) : _smtpHost = smtpHost,
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

      await send(message, smtpServer);
      print('[EmailService] ✅ Verification email sent to $toEmail');
      return true;
    } catch (e) {
      print(
        '[EmailService] ❌ Error sending verification email to $toEmail: $e',
      );
      return false;
    }
  }

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

      await send(message, smtpServer);
      print('[EmailService] ✅ Password reset email sent to $toEmail');
      return true;
    } catch (e) {
      print(
        '[EmailService] ❌ Error sending password reset email to $toEmail: $e',
      );
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
      font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Helvetica, Arial, sans-serif;
      line-height: 1.6;
      color: #333;
      max-width: 600px;
      margin: 0 auto;
      padding: 20px;
      background: #f5f5f5;
    }
    .container {
      background: #ffffff;
      border-radius: 12px;
      padding: 40px;
      box-shadow: 0 4px 6px rgba(0, 0, 0, 0.1);
    }
    .header {
      text-align: center;
      margin-bottom: 30px;
    }
    .logo {
      font-size: 56px;
      margin-bottom: 10px;
    }
    .title {
      font-size: 24px;
      font-weight: 600;
      color: #6366f1;
      margin: 10px 0;
    }
    .subtitle {
      color: #64748b;
      font-size: 16px;
    }
    .code-box {
      background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
      padding: 30px;
      text-align: center;
      border-radius: 12px;
      margin: 30px 0;
    }
    .code {
      font-size: 42px;
      font-weight: bold;
      color: #ffffff;
      letter-spacing: 8px;
      font-family: 'Courier New', monospace;
      text-shadow: 2px 2px 4px rgba(0,0,0,0.2);
    }
    .warning {
      background: #fef3c7;
      padding: 15px;
      margin: 20px 0;
      border-radius: 8px;
      border-left: 4px solid #f59e0b;
    }
    .info {
      color: #64748b;
      font-size: 14px;
      text-align: center;
      margin-top: 30px;
    }
    .footer {
      text-align: center;
      margin-top: 40px;
      padding-top: 20px;
      border-top: 1px solid #e2e8f0;
      font-size: 12px;
      color: #94a3b8;
    }
  </style>
</head>
<body>
  <div class="container">
    <div class="header">
      <div class="logo">🪞</div>
      <h1 class="title">Welcome to EchoMirror!</h1>
      <p class="subtitle">Your future self is excited to meet you</p>
    </div>
    
    <p>Thank you for signing up! To complete your registration and start your journey of self-reflection, please enter this verification code in the app:</p>
    
    <div class="code-box">
      <div class="code">$code</div>
    </div>
    
    <div class="warning">
      <strong>⏰ Important:</strong> This code will expire in <strong>15 minutes</strong>.
    </div>
    
    <p>Once verified, you'll be able to:</p>
    <ul>
      <li>📝 Log your daily moods and reflections</li>
      <li>📊 Track your emotional patterns over time</li>
      <li>🤖 Get AI-powered insights about yourself</li>
      <li>🌍 Connect with the Global Mirror community</li>
    </ul>
    
    <div class="info">
      <p>If you didn't create an account with EchoMirror, please ignore this email.</p>
    </div>
    
    <div class="footer">
      <p>This is an automated email. Please do not reply to this message.</p>
      <p>&copy; ${DateTime.now().year} EchoMirror. All rights reserved.</p>
    </div>
  </div>
</body>
</html>
''';
  }

  String _buildVerificationEmailText(String code) {
    return '''
Welcome to EchoMirror!

Thank you for signing up! Your future self is excited to meet you.

To complete your registration, please enter this verification code in the app:

$code

⏰ This code will expire in 15 minutes.

Once verified, you'll be able to:
• Log your daily moods and reflections
• Track your emotional patterns over time
• Get AI-powered insights about yourself
• Connect with the Global Mirror community

If you didn't create an account with EchoMirror, please ignore this email.

---
This is an automated email. Please do not reply.
© ${DateTime.now().year} EchoMirror. All rights reserved.
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
      font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Helvetica, Arial, sans-serif;
      line-height: 1.6;
      color: #333;
      max-width: 600px;
      margin: 0 auto;
      padding: 20px;
      background: #f5f5f5;
    }
    .container {
      background: #ffffff;
      border-radius: 12px;
      padding: 40px;
      box-shadow: 0 4px 6px rgba(0, 0, 0, 0.1);
    }
    .header {
      text-align: center;
      margin-bottom: 30px;
    }
    .logo {
      font-size: 56px;
      margin-bottom: 10px;
    }
    .title {
      font-size: 24px;
      font-weight: 600;
      color: #dc2626;
      margin: 10px 0;
    }
    .code-box {
      background: linear-gradient(135deg, #f43f5e 0%, #dc2626 100%);
      padding: 30px;
      text-align: center;
      border-radius: 12px;
      margin: 30px 0;
    }
    .code {
      font-size: 42px;
      font-weight: bold;
      color: #ffffff;
      letter-spacing: 8px;
      font-family: 'Courier New', monospace;
      text-shadow: 2px 2px 4px rgba(0,0,0,0.2);
    }
    .warning {
      background: #fee2e2;
      padding: 15px;
      margin: 20px 0;
      border-radius: 8px;
      border-left: 4px solid #dc2626;
    }
    .footer {
      text-align: center;
      margin-top: 40px;
      padding-top: 20px;
      border-top: 1px solid #e2e8f0;
      font-size: 12px;
      color: #94a3b8;
    }
  </style>
</head>
<body>
  <div class="container">
    <div class="header">
      <div class="logo">🔐</div>
      <h1 class="title">Password Reset Request</h1>
    </div>
    
    <p>You requested to reset your EchoMirror password. Enter this code in the app to proceed:</p>
    
    <div class="code-box">
      <div class="code">$code</div>
    </div>
    
    <div class="warning">
      <strong>⏰ Important:</strong> This code will expire in <strong>15 minutes</strong>.
    </div>
    
    <div class="warning">
      <strong>⚠️ Security Notice:</strong> If you didn't request this password reset, please ignore this email and consider changing your password if you believe your account may be compromised.
    </div>
    
    <div class="footer">
      <p>This is an automated email. Please do not reply to this message.</p>
      <p>&copy; ${DateTime.now().year} EchoMirror. All rights reserved.</p>
    </div>
  </div>
</body>
</html>
''';
  }

  String _buildPasswordResetEmailText(String code) {
    return '''
EchoMirror - Password Reset Request

You requested to reset your EchoMirror password. 

Enter this code in the app to proceed:

$code

⏰ This code will expire in 15 minutes.

⚠️ SECURITY NOTICE:
If you didn't request this password reset, please ignore this email and consider changing your password if you believe your account may be compromised.

---
This is an automated email. Please do not reply.
© ${DateTime.now().year} EchoMirror. All rights reserved.
''';
  }
}
