#!/bin/bash
export PATH="$PATH:$HOME/.pub-cache/bin"
echo "🔍 Checking for verification codes..."
echo ""
scloud log --limit 500 2>&1 | grep -oE '\[EmailIdp\] (Registration|Password reset) code \([^)]+\): [a-z0-9]+' | tail -10
