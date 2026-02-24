#!/bin/bash
echo "🔍 Watching for verification codes (press Ctrl+C to stop)..."
export PATH="$PATH:$HOME/.pub-cache/bin"
while true; do
  scloud log --limit 10 2>&1 | grep "Registration code" | tail -1
  sleep 2
done
