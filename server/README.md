# Echo Mirror Butler Server

Node.js + Express API server for Echo Mirror Butler custom business logic that doesn't fit neatly into Supabase Edge Functions.

## Purpose

While Supabase Edge Functions handle AI and Agora token generation, this server handles more complex business logic including:
- Webhook processing (Supabase, Stripe, Agora)
- Complex Stellar transaction orchestration
- Scheduled jobs and background tasks
- Third-party integrations requiring persistent connections

## Features

- ✅ **TypeScript** with full type safety
- ✅ **Express.js** with middleware for security and logging
- ✅ **Supabase Integration** with service role authentication
- ✅ **JWT Authentication** middleware for protected routes
- ✅ **Stellar API** mock endpoints for transaction processing
- ✅ **Webhook Handlers** for multiple services
- ✅ **Error Handling** with structured responses
- ✅ **Health Checks** for monitoring
- ✅ **Docker Support** for containerized deployment

## Quick Start

### Prerequisites

- Node.js 18+ 
- npm or yarn
- Supabase project with service role key

### Installation

```bash
# Clone the repository
git clone <repository-url>
cd Echo-Mirror-Butler/server

# Install dependencies
npm install

# Copy environment variables
cp .env.example .env

# Update .env with your credentials
nano .env
```

### Environment Variables

```bash
PORT=3000
SUPABASE_URL=https://your-project.supabase.co
SUPABASE_SERVICE_ROLE_KEY=your-service-role-key
JWT_SECRET=your-jwt-secret
```

### Development

```bash
# Start development server
npm run dev

# Server will start on http://localhost:3000
```

### Production

```bash
# Build TypeScript
npm run build

# Start production server
npm start

# Or use Docker
docker build -t echo-mirror-butler-server .
docker run -p 3000:3000 echo-mirror-butler-server
```

## API Endpoints

### Health Checks
- `GET /health` - Basic health status
- `GET /health/detailed` - Detailed system metrics

### Stellar API (Protected)
- `POST /stellar/transaction` - Process Stellar transactions
- `GET /stellar/balance/:accountId` - Get account balance

### Webhooks
- `POST /webhooks/supabase` - Handle Supabase webhooks
- `POST /webhooks/stripe` - Handle Stripe webhooks
- `POST /webhooks/agora` - Handle Agora webhooks

### Authentication

Protected routes require a Bearer token in the Authorization header:

```bash
Authorization: Bearer <your-jwt-token>
```

The server validates the JWT using your Supabase project's JWT secret and fetches user profile information.

## Project Structure

```
server/
├── src/
│   ├── index.ts              # Express app entry point
│   ├── middleware/
│   │   ├── auth.ts           # JWT authentication middleware
│   │   └── errorHandler.ts  # Global error handler
│   ├── routes/
│   │   ├── health.ts         # Health check endpoints
│   │   ├── stellar.ts        # Stellar transaction routes
│   │   └── webhooks.ts       # Webhook handlers
│   └── services/
│       └── supabase.ts       # Supabase client service
├── package.json              # Dependencies and scripts
├── tsconfig.json            # TypeScript configuration
├── Dockerfile               # Docker configuration
├── .env.example             # Environment variables template
└── README.md                # This file
```

## Development Scripts

- `npm run dev` - Start development server with hot reload
- `npm run build` - Compile TypeScript to JavaScript
- `npm start` - Start production server
- `npm run clean` - Clean build artifacts

## Security Features

- **Helmet.js** - Security headers
- **CORS** - Cross-origin resource sharing
- **Rate Limiting** - Prevent abuse
- **JWT Validation** - Secure authentication
- **Input Validation** - Request body validation
- **Error Sanitization** - Safe error responses

## Monitoring

The server provides comprehensive health checks including:
- Memory usage
- CPU usage  
- Uptime
- Environment information
- Node.js version details

## Deployment

### Docker

```bash
# Build image
docker build -t echo-mirror-butler-server .

# Run container
docker run -p 3000:3000 --env-file .env echo-mirror-butler-server
```

### Environment Variables in Production

Ensure all required environment variables are set in production:
- `SUPABASE_URL` - Your Supabase project URL
- `SUPABASE_SERVICE_ROLE_KEY` - Service role key for admin operations
- `JWT_SECRET` - Secret for JWT token validation
- `PORT` - Server port (default: 3000)

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Add tests if applicable
5. Submit a pull request

## License

MIT License - see LICENSE file for details.
