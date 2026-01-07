#!/bin/bash

# Interactive Gmail Configuration Script for EchoMirror

echo "🪞 EchoMirror Email Configuration Setup"
echo "======================================="
echo ""
echo "This script will add Gmail configuration to your Serverpod server."
echo ""

# Check if passwords.yaml exists
PASSWORDS_FILE="/Users/macbookpro/echomirror_server/echomirror_server_server/config/passwords.yaml"
if [ ! -f "$PASSWORDS_FILE" ]; then
  echo "❌ Error: passwords.yaml not found at $PASSWORDS_FILE"
  exit 1
fi

echo "✅ Found passwords.yaml"
echo ""

# Get Gmail address
echo "📧 Enter your Gmail address:"
read -p "Gmail: " GMAIL_ADDRESS

if [ -z "$GMAIL_ADDRESS" ]; then
  echo "❌ Error: Gmail address is required"
  exit 1
fi

# Get App Password
echo ""
echo "🔑 Enter your Gmail App Password (16 characters, no spaces):"
echo "   (Get it from: https://myaccount.google.com/apppasswords)"
read -p "App Password: " APP_PASSWORD

if [ -z "$APP_PASSWORD" ]; then
  echo "❌ Error: App password is required"
  exit 1
fi

# Remove any spaces from app password
APP_PASSWORD=$(echo "$APP_PASSWORD" | tr -d ' ')

echo ""
echo "📝 Configuration to add:"
echo "   Gmail: $GMAIL_ADDRESS"
echo "   Password: ${APP_PASSWORD:0:4}************${APP_PASSWORD: -4}"
echo ""
read -p "Proceed with update? (y/n): " CONFIRM

if [ "$CONFIRM" != "y" ] && [ "$CONFIRM" != "Y" ]; then
  echo "❌ Cancelled"
  exit 0
fi

# Backup original file
cp "$PASSWORDS_FILE" "$PASSWORDS_FILE.backup_$(date +%Y%m%d_%H%M%S)"
echo "✅ Backed up original passwords.yaml"

# Add email configuration to development section
# Using awk to insert after the "development:" section
awk -v gmail="$GMAIL_ADDRESS" -v pass="$APP_PASSWORD" '
/^development:/ {
  print $0
  in_dev=1
  next
}
in_dev && /^  [a-zA-Z]/ && !email_added {
  print ""
  print "  # Email Configuration"
  print "  emailSmtpHost: '"'"'smtp.gmail.com'"'"'"
  print "  emailSmtpPort: '"'"'587'"'"'"
  print "  emailUsername: '"'"'" gmail "'"'"'"
  print "  emailPassword: '"'"'" pass "'"'"'"
  print "  emailFromAddress: '"'"'" gmail "'"'"'"
  print ""
  email_added=1
  in_dev=0
}
{print}
' "$PASSWORDS_FILE" > "$PASSWORDS_FILE.tmp"

mv "$PASSWORDS_FILE.tmp" "$PASSWORDS_FILE"

echo ""
echo "✅ Email configuration added to passwords.yaml!"
echo ""
echo "📋 Next steps:"
echo ""
echo "1. Restart your Serverpod server:"
echo "   cd /Users/macbookpro/echomirror_server/echomirror_server_server"
echo "   dart run bin/main.dart"
echo ""
echo "2. Look for this line in the output:"
echo "   [Server] ✅ Email service initialized"
echo ""
echo "3. Test by signing up in your Flutter app!"
echo ""
echo "📖 Backup saved at: $PASSWORDS_FILE.backup_*"
echo ""

