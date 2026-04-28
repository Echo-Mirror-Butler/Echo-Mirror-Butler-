export type AppUser = {
  id: string
  email?: string
}

export type WalletRecord = {
  id: string
  user_id: string
  public_key: string
  balance?: number | null
}

export type GiftTransaction = {
  id: string
  sender_user_id: string
  recipient_user_id: string
  echo_amount: number
  stellar_tx_hash: string | null
  message: string | null
  status: string
  created_at: string
}

export type LogEntry = {
  id: string
  user_id: string
  date: string
  mood: number | null
  habits: string[]
  notes: string | null
  created_at: string
  updated_at: string
}

export type Insight = {
  id: string
  user_id: string
  prediction: string
  suggestions: string[]
  future_letter: string
  stress_level: number
  created_at: string
}
