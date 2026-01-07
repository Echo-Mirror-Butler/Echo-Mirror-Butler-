# 🚀 Starting Your EchoMirror Server

## ✅ Email Configuration Complete!

Your email is now configured:
- **Gmail:** devhodaofficial@gmail.com
- **Status:** ✅ Email service initialized successfully!

## 📋 Complete Startup Procedure

### Step 1: Start Docker Desktop

1. Open **Docker Desktop** application on your Mac
2. Wait for it to fully start (you'll see the Docker icon in the menu bar)
3. Verify it's running: the Docker icon should be solid (not animated)

### Step 2: Start the Database

Open a terminal and run:

```bash
cd /Users/macbookpro/echomirror_server/echomirror_server_server
docker compose up -d
```

You should see:
```
[+] Running 2/2
 ✔ Container echomirror_server_server-postgres-1  Started
 ✔ Container echomirror_server_server-redis-1     Started
```

### Step 3: Start the Serverpod Server

In the same terminal:

```bash
dart run bin/main.dart
```

Look for these SUCCESS messages:
```
[Server] ✅ Email service initialized
SERVER echomirror_server_server running, SERVERPOD version: 3.1.1
Insights server listening on port 8081
API server listening on port 8080
Web server listening on port 8082
```

### Step 4: Test Email Verification

1. **Run your Flutter app**:
```bash
cd /Users/macbookpro/echomirror
flutter run
```

2. **Sign up with a real email**

3. **Check your email inbox** (devhodaofficial@gmail.com or any email you sign up with)

4. **You should receive** a beautiful email with your verification code!

5. **Server logs will show**:
```
[EmailIdp] 📧 Registration code for test@example.com: ABC123
[EmailService] ✅ Verification email sent to test@example.com
```

## 🎯 Quick Commands

### Check if Docker is running:
```bash
docker ps
```

### Check if database is running:
```bash
cd /Users/macbookpro/echomirror_server/echomirror_server_server
docker compose ps
```

### Stop everything:
```bash
cd /Users/macbookpro/echomirror_server/echomirror_server_server
docker compose down
```

### View server logs:
```bash
cd /Users/macbookpro/echomirror_server/echomirror_server_server
tail -f logs/serverpod.log
```

## ✅ What's Working Now

- ✅ Email service configured with Gmail
- ✅ Verification emails will be sent automatically
- ✅ Password reset emails will work
- ✅ Beautiful HTML email templates
- ✅ Codes still logged for debugging

## 📧 Email Features

Your users will now receive:
- 🪞 Professional EchoMirror branded emails
- 🎨 Beautiful gradient design
- 📱 Mobile-responsive layout
- ⏰ Clear expiration warnings
- 🔐 Secure verification codes

## 🐛 Troubleshooting

### Email not sending?
Check server output for:
- `[Server] ✅ Email service initialized` ← Should see this
- `[EmailService] ✅ Email sent...` ← Confirms email sent

### Database won't start?
1. Make sure Docker Desktop is running
2. Check port 8090 isn't in use: `lsof -i :8090`
3. Try: `docker compose down && docker compose up -d`

### Gmail blocking emails?
- Verify App Password is correct in passwords.yaml
- Check Gmail security: https://myaccount.google.com/security
- Look for security alerts in your Gmail

## 🎉 You're All Set!

Once Docker is running and you start the server, your email verification system will be fully operational!

**Next:** Start Docker Desktop, then run the commands in Step 2-3 above.

