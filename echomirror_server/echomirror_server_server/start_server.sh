#!/bin/bash

# EchoMirror Server Startup Script
# This script sets up environment variables and starts the Serverpod server

cd "$(dirname "$0")"

echo "🚀 Starting EchoMirror Server..."
echo ""

# Generate JWT keys if not already set
if [ -z "$SERVERPOD_PASSWORD_jwtPublicKey" ]; then
  echo "📝 Generating JWT keys..."
  openssl genrsa -out /tmp/jwt_private.pem 2048 2>/dev/null
  openssl rsa -in /tmp/jwt_private.pem -pubout -out /tmp/jwt_public.pem 2>/dev/null
  
  export SERVERPOD_PASSWORD_jwtPublicKey=$(base64 -w 0 /tmp/jwt_public.pem)
  export SERVERPOD_PASSWORD_jwtPrivateKey=$(base64 -w 0 /tmp/jwt_private.pem)
  
  rm /tmp/jwt_private.pem /tmp/jwt_public.pem
  echo "✅ JWT keys generated"
fi

# Check if Docker containers are running
echo "🐳 Checking Docker containers..."
if ! docker-compose ps | grep -q "Up"; then
  echo "⚠️  Docker containers not running. Starting them..."
  docker-compose up -d
  sleep 3
fi

echo "✅ Docker containers are running"
echo ""
echo "🌐 Server will be available at:"
echo "   - API Server: http://localhost:8080"
echo "   - Insights: http://localhost:8081"
echo "   - Web Server: http://localhost:8082"
echo ""
echo "📧 Email configuration loaded from config/passwords.yaml"
echo ""
echo "Press Ctrl+C to stop the server"
echo "================================"
echo ""

# Start the server
dart run bin/main.dart
