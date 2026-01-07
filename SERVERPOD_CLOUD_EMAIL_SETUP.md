# Adding Email to Serverpod Cloud

## Current Situation

Your app is connected to: `https://echomirror.api.serverpod.space`

Email service is configured locally but needs to be added to your Serverpod Cloud deployment.

## Steps to Add Email Configuration

### Step 1: Login to Serverpod Cloud Dashboard

1. Go to: **https://app.serverpod.cloud**
2. Login with your Serverpod account
3. Select your project: **echomirror**

### Step 2: Add Email Secrets/Environment Variables

In your Serverpod Cloud project dashboard:

1. Navigate to **Settings** or **Environment Variables** or **Secrets**
2. Add these configuration values:

```
EMAIL_SMTP_HOST = smtp.gmail.com
EMAIL_SMTP_PORT = 587
EMAIL_USERNAME = devhodaofficial@gmail.com
EMAIL_PASSWORD = bqslxjmmwvwbdqdd
EMAIL_FROM_ADDRESS = devhodaofficial@gmail.com
```

### Step 3: Deploy Updated Server Code

Your cloud server needs the updated `server.dart` with EmailService support.

#### Check your deployment method:

**If using Git deployment:**
```bash
cd /Users/macbookpro/echomirror_server
git add .
git commit -m "Add email service support"
git push
```

**If manual deployment:**
- Upload your updated server code through the Serverpod Cloud dashboard
- Or follow your existing deployment process

### Step 4: Verify Server Files on Cloud

Make sure these files are deployed to your cloud server:

1. **lib/server.dart** - Updated with EmailService initialization
2. **lib/src/services/email_service.dart** - The email service class
3. **pubspec.yaml** - Must include `mailer: ^6.0.0` dependency

### Step 5: Check Server Logs

After deployment, check your Serverpod Cloud logs for:

```
[Server] ✅ Email service initialized
```

If you see this, email is working!

## Testing Email on Cloud

1. Sign up with a real email in your app
2. Check server logs in Serverpod Cloud dashboard
3. Look for:
   ```
   [EmailIdp] 📧 Registration code for user@example.com: ABC123
   [EmailService] ✅ Verification email sent to user@example.com
   ```
4. Check your email inbox for the verification code

## Troubleshooting

### Email service not initialized?

**Check:**
- Environment variables are correctly added in cloud dashboard
- Server has been redeployed after adding variables
- `mailer` package is in dependencies

### Authentication Failed (535)?

**This means:**
- Gmail App Password is incorrect
- Or Gmail account has security restrictions

**Fix:**
- Verify the App Password in cloud environment variables
- Make sure it's the 16-character App Password, not your regular password

### Emails not sending but no errors?

**Check:**
- Gmail hasn't blocked the account
- Check Gmail security: https://myaccount.google.com/security
- Verify App Password is still valid

## Alternative: Use Serverpod Email Service

If you prefer, Serverpod Cloud can handle emails for you:

1. In your Serverpod Cloud dashboard
2. Enable built-in email service
3. Configure from there (no code changes needed)

## Current Status

- ✅ Email service code written
- ✅ Local server configured and tested
- ⏳ Waiting: Cloud environment variables
- ⏳ Waiting: Cloud deployment with email service

## Quick Reference

**Gmail:** devhodaofficial@gmail.com  
**App Password:** bqslxjmmwvwbdqdd  
**Server URL:** https://echomirror.api.serverpod.space  

---

**Once configured, all signups will receive professional verification emails automatically!** 📧

