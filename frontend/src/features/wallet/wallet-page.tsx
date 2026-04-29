import { FormEvent, useState } from 'react'
import { useMutation, useQuery, useQueryClient, keepPreviousData } from '@tanstack/react-query'
import { supabase } from '../../lib/supabase'
import { useAuth } from '../../lib/auth-context'
import { RecipientAutocomplete } from '../../components/recipient-autocomplete'
import type { GiftTransaction, WalletRecord } from '../../lib/types'
import { formatDateTime } from '../../lib/date'

const WALLET_PAGE_SIZE = 20
const PRESET_AMOUNTS = [5, 10, 25, 50]

type WalletSnapshot = {
  exists: boolean
  record: WalletRecord | null
  balance: number
}

type GiftHistoryResult = {
  rows: GiftTransaction[]
  count: number
}

function isMissingColumnError(error: unknown): boolean {
  return (
    typeof error === 'object' &&
    error !== null &&
    'message' in error &&
    typeof (error as { message: string }).message === 'string' &&
    (error as { message: string }).message.toLowerCase().includes('column')
  )
}

async function computeBalanceFromTransactions(userId: string): Promise<number> {
  const [{ data: sentRows, error: sentError }, { data: receivedRows, error: receivedError }] =
    await Promise.all([
      supabase
        .from('gift_transactions')
        .select('echo_amount,status')
        .eq('sender_user_id', userId)
        .eq('status', 'completed'),
      supabase
        .from('gift_transactions')
        .select('echo_amount,status')
        .eq('recipient_user_id', userId)
        .eq('status', 'completed'),
    ])

  if (sentError) {
    throw sentError
  }

  if (receivedError) {
    throw receivedError
  }

  const sentTotal = (sentRows ?? []).reduce((sum, row) => sum + Number(row.echo_amount ?? 0), 0)
  const receivedTotal = (receivedRows ?? []).reduce(
    (sum, row) => sum + Number(row.echo_amount ?? 0),
    0,
  )

  return Math.max(0, receivedTotal - sentTotal)
}

async function fetchWallet(userId: string): Promise<WalletSnapshot> {
  const walletBaseQuery = supabase
    .from('user_wallets')
    .select('id,user_id,public_key,balance')
    .eq('user_id', userId)
    .maybeSingle()

  const { data, error } = await walletBaseQuery

  if (error && !isMissingColumnError(error)) {
    throw error
  }

  if (!data && !isMissingColumnError(error)) {
    return {
      exists: false,
      record: null,
      balance: 0,
    }
  }

  if (data) {
    if (typeof data.balance === 'number') {
      return {
        exists: true,
        record: data as WalletRecord,
        balance: data.balance,
      }
    }

    const fallbackBalance = await computeBalanceFromTransactions(userId)
    return {
      exists: true,
      record: data as WalletRecord,
      balance: fallbackBalance,
    }
  }

  const { data: walletWithoutBalance, error: walletError } = await supabase
    .from('user_wallets')
    .select('id,user_id,public_key')
    .eq('user_id', userId)
    .maybeSingle()

  if (walletError) {
    throw walletError
  }

  if (!walletWithoutBalance) {
    return {
      exists: false,
      record: null,
      balance: 0,
    }
  }

  const fallbackBalance = await computeBalanceFromTransactions(userId)

  return {
    exists: true,
    record: walletWithoutBalance as WalletRecord,
    balance: fallbackBalance,
  }
}

async function fetchGiftHistory(userId: string, page: number): Promise<GiftHistoryResult> {
  const start = (page - 1) * WALLET_PAGE_SIZE
  const end = start + WALLET_PAGE_SIZE - 1

  const { data, count, error } = await supabase
    .from('gift_transactions')
    .select('*', { count: 'exact' })
    .or(`sender_user_id.eq.${userId},recipient_user_id.eq.${userId}`)
    .order('created_at', { ascending: false })
    .range(start, end)

  if (error) {
    throw error
  }

  return {
    rows: (data ?? []) as GiftTransaction[],
    count: count ?? 0,
  }
}

async function resolveRecipientId(recipientInput: string): Promise<string> {
  const trimmed = recipientInput.trim()
  const uuidRegex =
    /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i

  if (uuidRegex.test(trimmed)) {
    return trimmed
  }

  if (!trimmed.includes('@')) {
    throw new Error('Use a valid recipient UUID or email address.')
  }

  const profileTables = ['profiles', 'user_profiles']
  for (const table of profileTables) {
    const { data, error } = await supabase.from(table).select('id').eq('email', trimmed).maybeSingle()
    if (!error && data?.id) {
      return data.id as string
    }
  }

  const { data: rpcData, error: rpcError } = await supabase.rpc('lookup_user_by_email', {
    email_input: trimmed,
  })

  if (!rpcError && rpcData && typeof rpcData.user_id === 'string') {
    return rpcData.user_id
  }

  throw new Error('Could not resolve recipient from email. Use recipient user ID.')
}

async function sendGift(params: {
  senderUserId: string
  recipientInput: string
  amount: number
  message: string
}) {
  const recipientUserId = await resolveRecipientId(params.recipientInput)

  if (recipientUserId === params.senderUserId) {
    throw new Error('You cannot send ECHO to yourself.')
  }

  const { data: recipientWallet, error: recipientWalletError } = await supabase
    .from('user_wallets')
    .select('id')
    .eq('user_id', recipientUserId)
    .maybeSingle()

  if (recipientWalletError) {
    throw recipientWalletError
  }

  if (!recipientWallet) {
    throw new Error('Recipient has no wallet yet.')
  }

  const { data, error } = await supabase
    .from('gift_transactions')
    .insert({
      sender_user_id: params.senderUserId,
      recipient_user_id: recipientUserId,
      echo_amount: params.amount,
      message: params.message || null,
      status: 'completed',
    })
    .select('*')
    .single()

  if (error) {
    throw error
  }

  const { error: balancePatchError } = await supabase
    .from('user_wallets')
    .update({ balance: null })
    .eq('user_id', params.senderUserId)

  if (balancePatchError && !isMissingColumnError(balancePatchError)) {
    throw balancePatchError
  }

  return data as GiftTransaction
}

function ConfettiBlast({ active }: { active: boolean }) {
  if (!active) {
    return null
  }

  return (
    <div className="confetti-wrap" aria-hidden="true">
      {Array.from({ length: 24 }).map((_, index) => (
        <span key={index} style={{ ['--piece-delay' as string]: `${index * 35}ms` }} />
      ))}
    </div>
  )
}

export function WalletPage() {
  const { user } = useAuth()
  const queryClient = useQueryClient()
  const [page, setPage] = useState(1)
  const [recipientInput, setRecipientInput] = useState('')
  const [selectedAmount, setSelectedAmount] = useState<number | null>(PRESET_AMOUNTS[1])
  const [customAmount, setCustomAmount] = useState('')
  const [message, setMessage] = useState('')
  const [inlineError, setInlineError] = useState<string | null>(null)
  const [showConfetti, setShowConfetti] = useState(false)

  const walletQuery = useQuery({
    queryKey: ['wallet', user?.id],
    queryFn: () => fetchWallet(user!.id),
    enabled: Boolean(user?.id),
  })

  const historyQuery = useQuery({
    queryKey: ['wallet-history', user?.id, page],
    queryFn: () => fetchGiftHistory(user!.id, page),
    enabled: Boolean(user?.id),
    placeholderData: keepPreviousData,
  })

  const createWalletMutation = useMutation({
    mutationFn: async () => {
      const { error } = await supabase.functions.invoke('create-stellar-wallet')
      if (error) {
        throw error
      }
    },
    onSuccess: async () => {
      await queryClient.invalidateQueries({ queryKey: ['wallet', user?.id] })
    },
  })

  const sendGiftMutation = useMutation({
    mutationFn: async () => {
      return sendGift({
        senderUserId: user!.id,
        recipientInput,
        amount: resolvedAmount,
        message,
      })
    },
    onMutate: async () => {
      setInlineError(null)
      await queryClient.cancelQueries({ queryKey: ['wallet', user?.id] })
      await queryClient.cancelQueries({ queryKey: ['wallet-history', user?.id] })

      const previousWallet = queryClient.getQueryData<WalletSnapshot>(['wallet', user?.id])
      const previousHistory = queryClient.getQueryData<GiftHistoryResult>(['wallet-history', user?.id, page])

      if (previousWallet) {
        queryClient.setQueryData<WalletSnapshot>(['wallet', user?.id], {
          ...previousWallet,
          balance: Math.max(0, previousWallet.balance - resolvedAmount),
        })
      }

      if (previousHistory) {
        const optimisticTx: GiftTransaction = {
          id: `optimistic-${Date.now()}`,
          sender_user_id: user!.id,
          recipient_user_id: 'pending',
          echo_amount: resolvedAmount,
          stellar_tx_hash: null,
          message: message || null,
          status: 'completed',
          created_at: new Date().toISOString(),
        }

        queryClient.setQueryData<GiftHistoryResult>(['wallet-history', user?.id, page], {
          count: previousHistory.count + 1,
          rows: [optimisticTx, ...previousHistory.rows].slice(0, WALLET_PAGE_SIZE),
        })
      }

      return { previousWallet, previousHistory }
    },
    onSuccess: async () => {
      setShowConfetti(true)
      setTimeout(() => setShowConfetti(false), 2200)
      setMessage('')
      setCustomAmount('')
      setSelectedAmount(PRESET_AMOUNTS[1])
      await queryClient.invalidateQueries({ queryKey: ['wallet', user?.id] })
      await queryClient.invalidateQueries({ queryKey: ['wallet-history', user?.id] })
    },
    onError: (error: Error, _vars, context) => {
      setInlineError(error.message)
      if (context?.previousWallet) {
        queryClient.setQueryData(['wallet', user?.id], context.previousWallet)
      }
      if (context?.previousHistory) {
        queryClient.setQueryData(['wallet-history', user?.id, page], context.previousHistory)
      }
    },
  })

  if (!user) {
    return null
  }

  const resolvedAmount = selectedAmount ?? Number(customAmount)
  const exceedsBalance = resolvedAmount > (walletQuery.data?.balance ?? 0)
  const isSendDisabled =
    !walletQuery.data?.exists ||
    !recipientInput.trim() ||
    !Number.isFinite(resolvedAmount) ||
    resolvedAmount <= 0 ||
    exceedsBalance ||
    sendGiftMutation.isPending

  const totalHistoryPages = Math.max(
    1,
    Math.ceil((historyQuery.data?.count ?? 0) / WALLET_PAGE_SIZE),
  )

  return (
    <section className="feature-grid wallet-grid">
      <ConfettiBlast active={showConfetti} />

      <article className="card balance-card">
        <div className="card-header">
          <h2>ECHO Wallet</h2>
          <button
            type="button"
            onClick={() => void walletQuery.refetch()}
            disabled={walletQuery.isFetching}
          >
            Refresh
          </button>
        </div>

        {walletQuery.isLoading ? (
          <div className="skeleton-line large" />
        ) : walletQuery.data?.exists ? (
          <>
            <p className="balance-number">{walletQuery.data.balance.toFixed(2)} ECHO</p>
            <p className="muted">Public key: {walletQuery.data.record?.public_key.slice(0, 14)}…</p>
          </>
        ) : (
          <div className="empty-state">
            <p>No wallet yet.</p>
            <button
              type="button"
              onClick={() => createWalletMutation.mutate()}
              disabled={createWalletMutation.isPending}
            >
              {createWalletMutation.isPending ? 'Creating…' : 'Create wallet'}
            </button>
            {createWalletMutation.error ? (
              <p className="error-text">{(createWalletMutation.error as Error).message}</p>
            ) : null}
          </div>
        )}
      </article>

      <article className="card">
        <h2>Send Gift</h2>
        <form
          className="form-stack"
          onSubmit={(event: FormEvent<HTMLFormElement>) => {
            event.preventDefault()
            if (!isSendDisabled) {
              sendGiftMutation.mutate()
            }
          }}
        >
          <label>
            Recipient user ID or email
            <RecipientAutocomplete
              value={recipientInput}
              onChange={setRecipientInput}
              onSelect={(userId) => setRecipientInput(userId)}
              placeholder="UUID or email"
            />
          </label>

          <div>
            <p className="field-label">Amount</p>
            <div className="chip-row">
              {PRESET_AMOUNTS.map((chipAmount) => (
                <button
                  key={chipAmount}
                  type="button"
                  className={selectedAmount === chipAmount ? 'chip active' : 'chip'}
                  onClick={() => {
                    setSelectedAmount(chipAmount)
                    setCustomAmount('')
                  }}
                >
                  {chipAmount} ECHO
                </button>
              ))}
            </div>
            <input
              type="number"
              min="0"
              step="0.01"
              placeholder="Custom amount"
              value={customAmount}
              onChange={(event) => {
                setCustomAmount(event.target.value)
                setSelectedAmount(null)
              }}
            />
          </div>

          <label>
            Message (optional, max 140 chars)
            <textarea
              maxLength={140}
              value={message}
              onChange={(event) => setMessage(event.target.value)}
              rows={3}
              placeholder="Keep shining."
            />
          </label>

          <button type="submit" disabled={isSendDisabled}>
            {sendGiftMutation.isPending
              ? 'Sending…'
              : `Send ${Number.isFinite(resolvedAmount) ? resolvedAmount : 0} ECHO`}
          </button>

          {exceedsBalance ? <p className="error-text">Amount exceeds your balance.</p> : null}
          {inlineError ? <p className="error-text">{inlineError}</p> : null}
        </form>
      </article>

      <article className="card full-width">
        <h2>Transaction History</h2>
        <div className="table-wrap">
          <table>
            <thead>
              <tr>
                <th>Date</th>
                <th>Type</th>
                <th>Amount</th>
                <th>Counterparty</th>
                <th>Status</th>
              </tr>
            </thead>
            <tbody>
              {(historyQuery.data?.rows ?? []).map((row) => {
                const isSent = row.sender_user_id === user.id
                const counterparty = isSent ? row.recipient_user_id : row.sender_user_id
                return (
                  <tr key={row.id}>
                    <td>{formatDateTime(row.created_at)}</td>
                    <td>{isSent ? 'sent' : 'received'}</td>
                    <td className={isSent ? 'amount-minus' : 'amount-plus'}>
                      {isSent ? '-' : '+'}
                      {row.echo_amount.toFixed(2)}
                    </td>
                    <td>{counterparty.slice(0, 10)}…</td>
                    <td>{row.status}</td>
                  </tr>
                )
              })}
            </tbody>
          </table>

          {!historyQuery.data?.rows.length ? <p className="muted">No transactions yet.</p> : null}
        </div>

        <div className="pagination-row">
          <button
            type="button"
            disabled={page <= 1 || historyQuery.isFetching}
            onClick={() => setPage((prev) => Math.max(1, prev - 1))}
          >
            Prev
          </button>
          <span>
            Page {page} / {totalHistoryPages}
          </span>
          <button
            type="button"
            disabled={page >= totalHistoryPages || historyQuery.isFetching}
            onClick={() => setPage((prev) => Math.min(totalHistoryPages, prev + 1))}
          >
            Next
          </button>
        </div>
      </article>
    </section>
  )
}
