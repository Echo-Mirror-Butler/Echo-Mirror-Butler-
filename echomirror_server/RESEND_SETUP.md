# 🚀 Resend Email Setup for EchoMirror

## Why Resend?
- ✅ **Cloud-friendly**: No SMTP port blocking issues
- ✅ **Reliable**: 99.9% delivery rate
- ✅ **Free tier**: 3,000 emails/month, 100/day
- ✅ **Fast**: API-based, no connection timeouts
- ✅ **Modern**: Built for developers

---

## 📝 Step 1: Create Resend Account

1. Go to **https://resend.com/signup**
2. Sign up with your email (or GitHub)
3. Verify your email

---

## 🔑 Step 2: Get Your API Key

1. After login, go to **API Keys** in the dashboard
2. Click **"Create API Key"**
3. Name it: `EchoMirror Production`
4. **Copy the API key** (starts with `re_...`)
   - ⚠️ **IMPORTANT**: Save it now! You can't see it again.

---

## 📧 Step 3: Add Your Domain (or Use Resend's)

### Option A: Use Resend's Domain (Quick Start)
- Resend provides `onboarding@resend.dev` for testing
- **Limitation**: Can only send to YOUR verified email
- Good for testing, but not for production

### Option B: Add Your Own Domain (Recommended)
1. In Resend dashboard, go to **Domains**
2. Click **"Add Domain"**
3. Enter your domain (e.g., `echomirror.app`)
4. Add the DNS records Resend provides:
   - SPF record
   - DKIM records
   - DMARC record
5. Wait for verification (usually 5-10 minutes)
6. Once verified, you can send from `noreply@echomirror.app`

### Option C: Use a Subdomain (Easy Alternative)
- Use `mail.yourdomain.com` or `app.yourdomain.com`
- Same DNS setup as Option B

---

## 🔧 Step 4: Configure Serverpod Cloud

Run these commands in your terminal:

```bash
cd /Users/macbookpro/echomirror_server

# Set your Resend API key
scloud password set resendApiKey --value "re_YOUR_API_KEY_HERE" --yes

# Set your from email address
scloud password set emailFromAddress --value "noreply@yourdomain.com" --yes

# Or use Resend's onboarding email for testing:
# scloud password set emailFromAddress --value "onboarding@resend.dev" --yes
```

---

## 🚀 Step 5: Deploy

```bash
cd /Users/macbookpro/echomirror_server
scloud deploy --yes
```

Wait 3-5 minutes for deployment to complete.

---

## 🧪 Step 6: Test

1. Open your EchoMirror app
2. Sign up with any email
3. Check your inbox! 📬

---

## 🔍 Verify Setup

Check if Resend is initialized:

```bash
scloud log --since 2m | grep -i resend
```

You should see:
```
[Server] ✅ Resend email service initialized
[Server] 📧 Sending from: noreply@yourdomain.com
```

---

## 🎯 Quick Test (For Onboarding Email)

If using `onboarding@resend.dev`, you can only send to **your verified email**:

1. In Resend dashboard, verify your personal email
2. Sign up in the app with that email
3. You'll receive the verification email!

---

## 📊 Monitor Emails

View sent emails in Resend dashboard:
- Go to **Emails** tab
- See delivery status, opens, clicks
- Debug any issues

---

## 💰 Pricing

- **Free**: 3,000 emails/month, 100/day
- **Pro**: $20/month for 50,000 emails
- **Enterprise**: Custom pricing

For EchoMirror's scale, free tier should be sufficient initially!

---

## 🆘 Troubleshooting

### Email not received?
1. Check Resend dashboard for delivery status
2. Check spam folder
3. Verify domain DNS records
4. Check Serverpod logs: `scloud log --since 5m`

### "Domain not verified"?
- Wait 10-15 minutes after adding DNS records
- Use `dig` to verify DNS propagation
- Contact Resend support if stuck

### API key not working?
- Make sure it starts with `re_`
- Recreate the API key if needed
- Verify it's set in Serverpod: `scloud password list`

---

## 📚 Resources

- **Resend Docs**: https://resend.com/docs
- **Resend Dashboard**: https://resend.com/dashboard
- **DNS Setup Guide**: https://resend.com/docs/dashboard/domains/introduction

---

## ✅ Next Steps

After setup:
1. ✅ Remove old Gmail passwords from Serverpod Cloud
2. ✅ Update any documentation
3. ✅ Test password reset emails too
4. ✅ Monitor email delivery rates

---

**Need help?** The Resend team is very responsive on their Discord and support email!

