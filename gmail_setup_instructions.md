# Gmail App Password Setup Guide

## Step 1: Enable 2-Factor Authentication (if not already enabled)

1. Go to: https://myaccount.google.com/security
2. Scroll down to "Signing in to Google"
3. Click on "2-Step Verification"
4. Follow the steps to enable it (you'll need your phone)

## Step 2: Generate App Password

1. Go to: https://myaccount.google.com/apppasswords
   (or Google Account → Security → 2-Step Verification → App passwords)

2. You might need to sign in again

3. In the "Select app" dropdown, choose "Mail"

4. In the "Select device" dropdown, choose "Other (Custom name)"

5. Type "EchoMirror Server" as the name

6. Click "Generate"

7. **COPY THE 16-CHARACTER PASSWORD** (it looks like: `abcd efgh ijkl mnop`)
   - Remove the spaces when you copy it: `abcdefghijklmnop`

## Step 3: Save It

You'll use this password in the next step. Keep this window open or save it somewhere temporarily.

**IMPORTANT:** This password can only be viewed once! If you lose it, you'll need to generate a new one.

## Security Notes

- This app password is ONLY for EchoMirror server
- It's NOT your regular Gmail password
- You can revoke it anytime from the same page
- It only has email sending permissions

---

**Next:** Add this password to your server configuration

