/**
 * Shared contract types for Supabase Edge Functions.
 *
 * These types document the expected request payload and response shape
 * for every deployed Edge Function. Both the web (frontend/src/) and
 * Flutter (lib/) clients should conform to these contracts.
 *
 * When adding or modifying an Edge Function, update this file and the
 * corresponding Dart mirror in lib/core/services/edge_function_types.dart.
 */

// ── create-stellar-wallet ─────────────────────────────────────────────────────
// Creates a Stellar wallet for the authenticated user.
// Auth: JWT (user extracted from auth header)
// Request body: empty (user is identified via JWT)
export interface CreateStellarWalletResponse {
  message?: string
  publicKey?: string
  error?: string
  details?: string
}

// ── send-echo ─────────────────────────────────────────────────────────────────
// Sends ECHO tokens from the authenticated user to a recipient.
// Auth: JWT
export interface SendEchoRequest {
  recipient_id: string
  amount: number
  message?: string
}

export interface SendEchoResponse {
  success?: boolean
  transactionId?: string
  error?: string
}

// ── generate-insight ──────────────────────────────────────────────────────────
// Generates AI insights from recent mood logs.
// Auth: JWT
export interface GenerateInsightRequest {
  recentLogs: Array<{
    date: string
    mood: number
    habits?: string[]
    notes?: string
  }>
  previousFollowThroughRate?: {
    acted: number
    total: number
  }
}

export interface GenerateInsightResponse {
  prediction: string
  suggestions: string[]
  futureLetter: string
  stressLevel: number
  calmingMessage?: string
  musicRecommendations?: string[]
  moodDrivers: Array<{ label: string; percentage: number }>
  bestTimeOfDay: string
  worstTimeOfDay: string
  recommendations: string[]
  moodScore: number
}

// ── generate-chat-response ────────────────────────────────────────────────────
// Generates a free-form chat response using Gemini.
// Auth: JWT
export interface GenerateChatResponseRequest {
  userMessage: string
  context?: string
}

export interface GenerateChatResponseResponse {
  response: string
  error?: string
}

// ── generate-encouragement ────────────────────────────────────────────────────
// Generates an encouraging message for a mood cluster.
// Auth: JWT
export interface GenerateEncouragementRequest {
  sentiment: string
  nearbyCount: number
}

export interface GenerateEncouragementResponse {
  message: string
  error?: string
}

// ── save-future-letter ────────────────────────────────────────────────────────
// Persists a future letter for the user.
// Auth: JWT
export interface SaveFutureLetterRequest {
  userId: string
  content: string
  generatedAt: string
}

export interface SaveFutureLetterResponse {
  id?: string
  error?: string
}

// ── get-agora-credentials ─────────────────────────────────────────────────────
// Gets Agora video call credentials.
// Auth: JWT
export interface GetAgoraCredentialsRequest {
  sessionId: string
  userId: string
}

export interface GetAgoraCredentialsResponse {
  token: string
  appId: string
  error?: string
}

// ── export-user-data ──────────────────────────────────────────────────────────
// Exports all user data as CSV.
// Auth: JWT (service role key used internally)
export interface ExportUserDataResponse {
  csv?: string
  error?: string
}

// ── send-daily-reminder ───────────────────────────────────────────────────────
// Scheduled function that sends push notifications to users due for a reminder.
// Auth: Service role key (called by cron)
// Request body: empty (reads from DB)
export interface SendDailyReminderResponse {
  sent: number
  failed: number
  error?: string
}