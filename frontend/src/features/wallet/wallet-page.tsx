import { FormEvent, useEffect, useState } from 'react'
import { useMutation, useQuery, useQueryClient, keepPreviousData } from '@tanstack/react-query'
import { supabase } from '../../lib/supabase'
import { useAuth } from '../../lib/auth-context'
import { useToast } from '../../lib/use-toast'
import { RecipientAutocomplete } from '../../components/recipient-autocomplete'
import type { EchoReward, WalletRecord } from '../../lib/types'
import { formatDateTime } from '../../lib/date'
import { TestnetBadge } from '../../components/TestnetBadge'
import { useWalletBalances } from '../../lib/use-wallet-balances'
import { isTestnet, stellarConfig } from '../../lib/stellar-config'

const WALLET_PAGE_SIZE = 20
const PRESET_AMOUNTS = [5, 10, 25, 50]

type WalletSnapshot = {
  exists: boolean
  record: WalletRecord | null
  balance: number
}

type RewardHistoryResult = {
  rows: EchoReward[]
  count: number
}

async function fetchWallet(userId: string): Promise<WalletSnapshot> {
  const { data, error } = await supabase
    .from('user_wallets')
    .select('id,user_id,public_key,balance')
    .eq('user_id', userId)
    .maybeSingle()

  if (error) {
    throw error
  }

  if (!data) {
    return {
      exists: false,
      record: null,
      balance: 0,
    }
  }

  return {
    exists: true,
    record: data as WalletRecord,
    balance: Number(data.balance ?? 0),
  }
}

async function fetchRewardHistory(
  userId: string,
  page: number,
  filters: {
    search?: string
    type?: 'all' | 'earned' | 'sent' | 'received'
    dateFrom?: string
    dateTo?: string
    sortBy?: 'date_desc' | 'date_asc' | 'amount_desc' | 'amount_asc'
  } = {}
): Promise<RewardHistoryResult> {
  const start = (page - 1) * WALLET_PAGE_SIZE
  const end = start + WALLET_PAGE_SIZE - 1

  let query = supabase
    .from('echo_rewards')
    .select('*', { count: 'exact' })
    .eq('user_id', userId)

  if (filters.search) {
    query = query.ilike('reason', `%${filters.search}%`)
  }

  if (filters.type && filters.type !== 'all') {
    if (filters.type === 'earned') {
      query = query.in('reason', [
        'daily_mood_log',
        'daily_log',
        '7_day_streak_bonus',
        'seven_day_streak',
        'streak_bonus',
        'welcome_bonus',
      ])
    } else if (filters.type === 'sent') {
      query = query.eq('reason', 'gift_sent').lt('amount', 0)
    } else if (filters.type === 'received') {
      query = query.eq('reason', 'gift_received').gt('amount', 0)
    }
  }

  if (filters.dateFrom) {
    query = query.gte('created_at', `${filters.dateFrom}T00:00:00.000Z`)
  }

  if (filters.dateTo) {
    query = query.lte('created_at', `${filters.dateTo}T23:59:59.999Z`)
  }

  const sortField = filters.sortBy?.startsWith('amount') ? 'amount' : 'created_at'
  const sortDirection = filters.sortBy?.endsWith('asc') ? true : false

  query = query.order(sortField, { ascending: sortDirection }).range(start, end)

  const { data, count, error } = await query

  if (error) {
    throw error
  }

  return {
    rows: (data ?? []) as EchoReward[],
    count: count ?? 0,
  }
}

function formatEchoAmount(amount: number): string {
  const absoluteAmount = Math.abs(amount)
  const formattedAmount = Number.isInteger(absoluteAmount)
    ? absoluteAmount.toString()
    : absoluteAmount.toFixed(2)

  return `${amount >= 0 ? '+' : '-'}${formattedAmount} ECHO`
}

function formatRewardReason(reason: string): string {
  const labels: Record<string, string> = {
    daily_mood_log: 'Daily log',
    daily_log: 'Daily log',
    '7_day_streak_bonus': '7-day streak bonus',
    seven_day_streak: '7-day streak bonus',
    streak_bonus: 'Streak bonus',
    gift_received: 'Gift received',
    welcome_bonus: 'Welcome bonus',
  }

  return (
    labels[reason] ??
    reason
      .split(/[_-]/)
      .filter(Boolean)
      .map((word) => word.charAt(0).toUpperCase() + word.slice(1))
      .join(' ')
  )
}

async function resolveRecipientId(recipientInput: string): Promise<string> {
  const trimmed = recipientInput.trim()
  const uuidRegex =
    /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i

  if (uuidRegex.test(trimmed)) {
    return trimmed
  }

  if (isValidStellarKey(trimmed)) {
    let data: { user_id: string } | null = null
    let lookupFailed = false

    try {
      const result = await supabase
        .from('user_wallets')
        .select('user_id')
        .eq('public_key', trimmed)
        .maybeSingle()
      data = result.data
      lookupFailed = Boolean(result.error)
    } catch {
      lookupFailed = true
    }

    if (data?.user_id) {
      return data.user_id as string
    }

    if (lookupFailed) {
      throw new Error('Network error while looking up that Stellar address. Please try again.')
    }

    throw new Error('Address not found. No wallet is linked to that Stellar address.')
  }

  if (!trimmed.includes('@')) {
    throw new Error('Use a valid recipient UUID, email address, or Stellar address.')
  }

  let lookupFailed = false
  const profileTables = ['profiles', 'user_profiles']
  for (const table of profileTables) {
    try {
      const { data, error } = await supabase.from(table).select('id').eq('email', trimmed).maybeSingle()
      if (error) {
        lookupFailed = true
        continue
      }
      if (data?.id) {
        return data.id as string
      }
    } catch {
      lookupFailed = true
    }
  }

  try {
    const { data: rpcData, error: rpcError } = await supabase.rpc('lookup_user_by_email', {
      email_input: trimmed,
    })

    if (rpcError) {
      lookupFailed = true
    } else if (rpcData && typeof rpcData.user_id === 'string') {
      return rpcData.user_id
    }
  } catch {
    lookupFailed = true
  }

  if (lookupFailed) {
    throw new Error('Network error while resolving that email. Please try again.')
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

  const { data, error } = await supabase.functions.invoke('send-echo', {
    body: {
      recipient_id: recipientUserId,
      amount: params.amount,
      message: params.message || undefined,
    },
  })

  if (error) {
    throw new Error(error.message || 'Failed to send ECHO')
  }

  if (data.error) {
    throw new Error(data.error)
  }

  return data
}

function isValidStellarKey(key: string): boolean {
  return key.length === 56 && key.startsWith('G')
}

async function isFreighterInstalled(): Promise<boolean> {
  try {
    const { isConnected } = await import('@stellar/freighter-api')
    const { isAppConnected } = await isConnected()
    return Boolean(isAppConnected)
  } catch {
    return false
  }
}

async function requestFreighterAccess(): Promise<string> {
  if (!(await isFreighterInstalled())) {
    throw new Error('FREIGHTER_NOT_INSTALLED')
  }
  const { requestAccess, getNetwork } = await import('@stellar/freighter-api')
  const result = await requestAccess()
  if (result.error) {
    throw new Error(result.error.message ?? 'Freighter connection rejected')
  }

  const network = await getNetwork()
  if (network.error) {
    throw new Error(network.error.message ?? 'Could not verify the Freighter network.')
  }
  if (network.networkPassphrase !== stellarConfig.networkPassphrase) {
    throw new Error(
      `Freighter is set to ${network.network}, but this app requires ${stellarConfig.network}. Switch networks in Freighter and try again.`,
    )
  }

  return result.address
}

async function upsertPublicKey(userId: string, publicKey: string | null): Promise<void> {
  const { error } = await supabase
    .from('user_wallets')
    .upsert({ user_id: userId, public_key: publicKey }, { onConflict: 'user_id' })
  if (error) throw error
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
  const [customAmount, setCustomAmount] = useState(String(PRESET_AMOUNTS[1]))
  const [message, setMessage] = useState('')
  const [inlineError, setInlineError] = useState<string | null>(null)
  const { showToast } = useToast()
  const [showConfetti, setShowConfetti] = useState(false)
  const [copiedWalletAddress, setCopiedWalletAddress] = useState(false)
  const [showConfirmDialog, setShowConfirmDialog] = useState(false)

  const [searchQuery, setSearchQuery] = useState('')
  const [debouncedSearch, setDebouncedSearch] = useState('')
  const [typeFilter, setTypeFilter] = useState<'all' | 'earned' | 'sent' | 'received'>('all')
  const [dateFrom, setDateFrom] = useState('')
  const [dateTo, setDateTo] = useState('')
  const [sortBy, setSortBy] = useState<'date_desc' | 'date_asc' | 'amount_desc' | 'amount_asc'>('date_desc')

  // External wallet state
  const [manualKeyInput, setManualKeyInput] = useState('')
  const [manualKeyError, setManualKeyError] = useState<string | null>(null)
  const [freighterStatus, setFreighterStatus] = useState<
    'idle' | 'connecting' | 'connected' | 'not_installed' | 'error'
  >('idle')
  const [freighterError, setFreighterError] = useState<string | null>(null)
  const [freighterAddress, setFreighterAddress] = useState<string | null>(null)

  // Ticker for "last updated X seconds ago"
  const [, setTick] = useState(0)
  useEffect(() => {
    const id = setInterval(() => setTick((t) => t + 1), 5_000)
    return () => clearInterval(id)
  }, [])

  useEffect(() => {
    const timer = setTimeout(() => {
      setDebouncedSearch(searchQuery)
    }, 300)
    return () => clearTimeout(timer)
  }, [searchQuery])

  useEffect(() => {
    const filters = { search: debouncedSearch, type: typeFilter, dateFrom, dateTo, sortBy }
    sessionStorage.setItem('wallet-filters', JSON.stringify(filters))
  }, [debouncedSearch, typeFilter, dateFrom, dateTo, sortBy])

  useEffect(() => {
    const stored = sessionStorage.getItem('wallet-filters')
    if (stored) {
      try {
        const filters = JSON.parse(stored)
        if (filters.search) setSearchQuery(filters.search)
        if (filters.type) setTypeFilter(filters.type)
        if (filters.dateFrom) setDateFrom(filters.dateFrom)
        if (filters.dateTo) setDateTo(filters.dateTo)
        if (filters.sortBy) setSortBy(filters.sortBy)
      } catch {
        // Ignore parse errors
      }
    }
  }, [])

  const walletQuery = useQuery({
    queryKey: ['wallet', user?.id],
    queryFn: () => fetchWallet(user!.id),
    enabled: Boolean(user?.id),
  })

  const historyQuery = useQuery({
    queryKey: ['wallet-history', user?.id, page, debouncedSearch, typeFilter, dateFrom, dateTo, sortBy],
    queryFn: () =>
      fetchRewardHistory(user!.id, page, {
        search: debouncedSearch,
        type: typeFilter,
        dateFrom,
        dateTo,
        sortBy,
      }),
    enabled: Boolean(user?.id),
    placeholderData: keepPreviousData,
  })

  const publicKey = walletQuery.data?.record?.public_key ?? null
  const balancesQuery = useWalletBalances(publicKey)

  const savePublicKeyMutation = useMutation({
    mutationFn: (key: string) => upsertPublicKey(user!.id, key),
    onSuccess: async () => {
      await queryClient.invalidateQueries({ queryKey: ['wallet', user?.id] })
      await queryClient.invalidateQueries({ queryKey: ['horizon-balances'] })
    },
  })

  const removePublicKeyMutation = useMutation({
    mutationFn: () => upsertPublicKey(user!.id, null),
    onSuccess: async () => {
      setManualKeyInput('')
      await queryClient.invalidateQueries({ queryKey: ['wallet', user?.id] })
      await queryClient.invalidateQueries({ queryKey: ['horizon-balances'] })
    },
  })

  const createWalletMutation = useMutation({
    mutationFn: async () => {
      const { data, error } = await supabase.functions.invoke('create-stellar-wallet', {
        body: {
          type: 'INSERT',
          schema: 'auth',
          table: 'users',
          record: { id: user!.id },
        },
      })
      if (error) {
        throw error
      }
      if (data?.error) {
        throw new Error(data.error)
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
    },
    onSuccess: async () => {
      setShowConfetti(true)
      setTimeout(() => setShowConfetti(false), 2200)
      setMessage('')
      setCustomAmount(String(PRESET_AMOUNTS[1]))
      setSelectedAmount(PRESET_AMOUNTS[1])
      setRecipientInput('')
      setShowConfirmDialog(false)
      showToast('ECHO sent!', 'success')
      await queryClient.invalidateQueries({ queryKey: ['wallet', user?.id] })
      await queryClient.invalidateQueries({ queryKey: ['wallet-history', user?.id] })
    },
    onError: (error: Error) => {
      showToast(error.message, 'error')
      setInlineError(error.message)
      setShowConfirmDialog(false)
    },
  })

  const handleCopyWalletAddress = async () => {
    if (!publicKey) {
      return
    }

    try {
      await navigator.clipboard.writeText(publicKey)
      setCopiedWalletAddress(true)
      window.setTimeout(() => setCopiedWalletAddress(false), 1800)
    } catch {
      setInlineError('Could not copy wallet address.')
    }
  }

  const handleFreighterConnect = async () => {
    setFreighterStatus('connecting')
    setFreighterError(null)
    try {
      const address = await requestFreighterAccess()
      setFreighterAddress(address)
      setFreighterStatus('connected')
      await savePublicKeyMutation.mutateAsync(address)
    } catch (err) {
      const msg = (err as Error).message ?? ''
      if (msg === 'FREIGHTER_NOT_INSTALLED') {
        setFreighterStatus('not_installed')
      } else {
        setFreighterStatus('error')
        setFreighterError(msg || 'Connection failed')
      }
    }
  }

  const handleFreighterDisconnect = async () => {
    setFreighterError(null)
    try {
      await removePublicKeyMutation.mutateAsync()
      setFreighterAddress(null)
      setFreighterStatus('idle')
    } catch (err) {
      const msg = (err as Error).message ?? ''
      setFreighterStatus('error')
      setFreighterError(msg || 'Could not disconnect wallet')
    }
  }

  const handleManualKeySave = async () => {
    const key = manualKeyInput.trim()
    if (!isValidStellarKey(key)) {
      setManualKeyError('Invalid key -- must start with G and be 56 characters.')
      return
    }
    setManualKeyError(null)
    await savePublicKeyMutation.mutateAsync(key)
    setManualKeyInput('')
  }

  const handleConfirmSend = () => {
    sendGiftMutation.mutate()
  }

  const handleCancelSend = () => {
    setShowConfirmDialog(false)
  }

  const handleDownloadCSV = async () => {
    if (!user) return

    const { data, error } = await supabase
      .from('echo_rewards')
      .select('*')
      .eq('user_id', user.id)
      .order('created_at', { ascending: false })

    if (error || !data) {
      showToast('Failed to export transactions', 'error')
      return
    }

    let filteredData = data

    if (debouncedSearch) {
      filteredData = filteredData.filter((row) =>
        row.reason.toLowerCase().includes(debouncedSearch.toLowerCase())
      )
    }

    if (typeFilter !== 'all') {
      if (typeFilter === 'earned') {
        filteredData = filteredData.filter((row) =>
          [
            'daily_mood_log',
            'daily_log',
            '7_day_streak_bonus',
            'seven_day_streak',
            'streak_bonus',
            'welcome_bonus',
          ].includes(row.reason)
        )
      } else if (typeFilter === 'sent') {
        filteredData = filteredData.filter((row) => row.reason === 'gift_sent' && row.amount < 0)
      } else if (typeFilter === 'received') {
        filteredData = filteredData.filter((row) => row.reason === 'gift_received' && row.amount > 0)
      }
    }

    if (dateFrom) {
      filteredData = filteredData.filter((row) => row.created_at >= `${dateFrom}T00:00:00.000Z`)
    }

    if (dateTo) {
      filteredData = filteredData.filter((row) => row.created_at <= `${dateTo}T23:59:59.999Z`)
    }

    const csv = [
      ['Date', 'Type', 'Amount', 'Reason'],
      ...filteredData.map((row) => [
        formatDateTime(row.created_at),
        row.amount >= 0 ? 'Received' : 'Sent',
        row.amount.toFixed(2),
        formatRewardReason(row.reason),
      ]),
    ]
      .map((row) => row.map((cell) => `"${cell}"`).join(','))
      .join('\n')

    const blob = new Blob([csv], { type: 'text/csv' })
    const url = URL.createObjectURL(blob)
    const link = document.createElement('a')
    link.href = url
    link.download = `echo-transactions-${new Date().toISOString().slice(0, 10)}.csv`
    link.click()
    URL.revokeObjectURL(url)
  }

  const handleClearFilters = () => {
    setSearchQuery('')
    setDebouncedSearch('')
    setTypeFilter('all')
    setDateFrom('')
    setDateTo('')
    setSortBy('date_desc')
    setPage(1)
  }

  if (!user) {
    return null
  }

  const resolvedAmount = Number(customAmount)
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

      {isTestnet ? (
        <div
          role="status"
          className="full-width flex items-center gap-2 rounded-lg border border-amber-300 bg-amber-50 px-4 py-2.5 text-sm font-medium text-amber-900"
        >
          <span aria-hidden="true">⚠</span>
          You are on Testnet — ECHO and XLM here have no real-world value.
        </div>
      ) : null}

      <article className="card balance-card">
        <div className="card-header">
          <div className="flex items-center gap-2"><h2>ECHO Wallet</h2><TestnetBadge /></div>
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
        ) : walletQuery.isError ? (
          <p className="error-text">Failed to load wallet.</p>
        ) : walletQuery.data?.exists ? (
          <>
            <p className="balance-number">{walletQuery.data.balance.toFixed(2)} ECHO</p>
            {publicKey ? (
              <div style={{ display: 'flex', gap: '0.75rem', alignItems: 'center', flexWrap: 'wrap' }}>
                <p className="muted" style={{ margin: 0 }}>
                  Public key: {publicKey.slice(0, 14)}...{publicKey.slice(-4)}
                </p>
                <button type="button" className="secondary" onClick={() => void handleCopyWalletAddress()}>
                  {copiedWalletAddress ? 'Copied' : 'Copy'}
                </button>
              </div>
            ) : (
              <p className="muted">Wallet row exists, but no Stellar public key is connected yet.</p>
            )}
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

      {publicKey ? (
        <article className="card">
          <div className="card-header">
            <h2>Live Stellar Balances</h2>
            <button
              type="button"
              onClick={() => void balancesQuery.refetch()}
              disabled={balancesQuery.isFetching}
            >
              Refresh
            </button>
          </div>

          {balancesQuery.isLoading || balancesQuery.isFetching ? (
            <>
              <div className="skeleton-line" />
              <div className="skeleton-line" />
            </>
          ) : balancesQuery.data?.notFunded ? (
            <div className="empty-state">
              <p>Wallet not funded yet.</p>
              <a
                href={`https://friendbot.stellar.org/?addr=${publicKey}`}
                target="_blank"
                rel="noopener noreferrer"
              >
                Fund with Friendbot (testnet)
              </a>
            </div>
          ) : balancesQuery.isError ? (
            <p className="error-text">Failed to load Stellar balances.</p>
          ) : (
            <>
              <p>
                <strong>XLM:</strong> {Number(balancesQuery.data?.xlm ?? '0').toFixed(7)}
              </p>
              <p>
                <strong>ECHO:</strong> {Number(balancesQuery.data?.echo ?? '0').toFixed(2)}
              </p>
            </>
          )}

          {balancesQuery.dataUpdatedAt ? (
            <p className="muted" style={{ marginTop: '0.5rem', fontSize: '0.8rem' }}>
              Last updated{' '}
              {Math.floor((Date.now() - balancesQuery.dataUpdatedAt) / 1000)}s ago · auto-refreshes
              every 30s
            </p>
          ) : null}
        </article>
      ) : null}

      <article className="card">
        <h2>Connect External Wallet</h2>

        {walletQuery.data?.record?.public_key ? (
          <p className="muted" style={{ marginBottom: '1rem', fontSize: '0.875rem' }}>
            ⚠ You already have a wallet connected. Connecting a new one will replace the current
            key.
          </p>
        ) : null}

        <div className="form-stack">
          <div>
            <p className="field-label">Freighter (browser extension)</p>
            {freighterAddress ? (
              <div style={{ display: 'flex', alignItems: 'center', gap: '0.75rem', flexWrap: 'wrap' }}>
                <span className="chip active">Connected via Freighter</span>
                <span className="muted" style={{ fontSize: '0.875rem' }}>
                  {freighterAddress.slice(0, 8)}...{freighterAddress.slice(-4)}
                </span>
                <button
                  type="button"
                  className="secondary"
                  onClick={() => void handleFreighterDisconnect()}
                  disabled={removePublicKeyMutation.isPending}
                >
                  {removePublicKeyMutation.isPending ? 'Disconnecting...' : 'Disconnect'}
                </button>
              </div>
            ) : freighterStatus === 'not_installed' ? (
              <p>
                Freighter not found.{' '}
                <a href="https://www.freighter.app/" target="_blank" rel="noopener noreferrer">
                  Install Freighter
                </a>
              </p>
            ) : (
              <button
                type="button"
                onClick={() => void handleFreighterConnect()}
                disabled={freighterStatus === 'connecting' || savePublicKeyMutation.isPending}
              >
                {freighterStatus === 'connecting' ? 'Connecting...' : 'Connect Freighter'}
              </button>
            )}
            {freighterStatus === 'error' && freighterError ? (
              <p className="error-text">{freighterError}</p>
            ) : null}
          </div>

          <div>
            <p className="field-label">Connect with public key</p>
            {walletQuery.data?.record?.public_key && !freighterAddress ? (
              <div style={{ display: 'flex', alignItems: 'center', gap: '0.75rem', flexWrap: 'wrap' }}>
                <span className="muted" style={{ fontSize: '0.875rem' }}>
                  {walletQuery.data.record.public_key.slice(0, 8)}...
                  {walletQuery.data.record.public_key.slice(-4)}
                </span>
                <button
                  type="button"
                  className="danger"
                  onClick={() => {
                    if (window.confirm('Remove the connected wallet key? This cannot be undone.')) {
                      removePublicKeyMutation.mutate()
                    }
                  }}
                  disabled={removePublicKeyMutation.isPending}
                >
                  {removePublicKeyMutation.isPending ? 'Removing...' : 'Remove wallet'}
                </button>
              </div>
            ) : (
              <>
                <input
                  type="text"
                  placeholder="GABCD... (56 characters)"
                  value={manualKeyInput}
                  onChange={(e) => {
                    setManualKeyInput(e.target.value)
                    setManualKeyError(null)
                  }}
                  maxLength={56}
                />
                <p className="muted" style={{ fontSize: '0.8rem', margin: '0.25rem 0' }}>
                  EchoMirror will send ECHO to this address. Make sure you control this wallet.
                </p>
                <button
                  type="button"
                  onClick={() => void handleManualKeySave()}
                  disabled={savePublicKeyMutation.isPending || !manualKeyInput.trim()}
                >
                  {savePublicKeyMutation.isPending ? 'Saving...' : 'Save address'}
                </button>
                {manualKeyError ? <p className="error-text">{manualKeyError}</p> : null}
                {savePublicKeyMutation.error ? (
                  <p className="error-text">
                    {(savePublicKeyMutation.error as Error).message}
                  </p>
                ) : null}
              </>
            )}
          </div>
        </div>
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
            Recipient user ID, email, or Stellar address
            <RecipientAutocomplete
              value={recipientInput}
              onChange={setRecipientInput}
              onSelect={(userId) => setRecipientInput(userId)}
              placeholder="UUID, email, or G... address"
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
                    setCustomAmount(String(chipAmount))
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
                const nextAmount = event.target.value
                const matchingPreset = PRESET_AMOUNTS.find(
                  (presetAmount) => presetAmount === Number(nextAmount),
                )

                setCustomAmount(nextAmount)
                setSelectedAmount(matchingPreset ?? null)
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
        <div className="card-header">
          <h2>Transaction History</h2>
          <button type="button" onClick={() => void handleDownloadCSV()}>
            Download CSV
          </button>
        </div>

        <div style={{ padding: '1rem', background: '#f9fafb', borderRadius: '4px', marginBottom: '1rem' }}>
          <div style={{ display: 'flex', gap: '1rem', flexWrap: 'wrap', marginBottom: '1rem' }}>
            <div style={{ flex: '1 1 250px' }}>
              <label style={{ display: 'block', marginBottom: '0.25rem', fontSize: '0.875rem', fontWeight: 500 }}>
                Search
              </label>
              <input
                type="text"
                placeholder="Search by reason..."
                value={searchQuery}
                onChange={(e) => {
                  setSearchQuery(e.target.value)
                  setPage(1)
                }}
                style={{ width: '100%', padding: '0.5rem', border: '1px solid #ddd', borderRadius: '4px' }}
              />
            </div>

            <div style={{ flex: '1 1 200px' }}>
              <label style={{ display: 'block', marginBottom: '0.25rem', fontSize: '0.875rem', fontWeight: 500 }}>
                From Date
              </label>
              <input
                type="date"
                value={dateFrom}
                onChange={(e) => {
                  setDateFrom(e.target.value)
                  setPage(1)
                }}
                style={{ width: '100%', padding: '0.5rem', border: '1px solid #ddd', borderRadius: '4px' }}
              />
            </div>

            <div style={{ flex: '1 1 200px' }}>
              <label style={{ display: 'block', marginBottom: '0.25rem', fontSize: '0.875rem', fontWeight: 500 }}>
                To Date
              </label>
              <input
                type="date"
                value={dateTo}
                onChange={(e) => {
                  setDateTo(e.target.value)
                  setPage(1)
                }}
                style={{ width: '100%', padding: '0.5rem', border: '1px solid #ddd', borderRadius: '4px' }}
              />
            </div>

            <div style={{ flex: '1 1 150px' }}>
              <label style={{ display: 'block', marginBottom: '0.25rem', fontSize: '0.875rem', fontWeight: 500 }}>
                Sort By
              </label>
              <select
                value={sortBy}
                onChange={(e) => {
                  setSortBy(e.target.value as typeof sortBy)
                  setPage(1)
                }}
                style={{ width: '100%', padding: '0.5rem', border: '1px solid #ddd', borderRadius: '4px' }}
              >
                <option value="date_desc">Date (newest)</option>
                <option value="date_asc">Date (oldest)</option>
                <option value="amount_desc">Amount (high)</option>
                <option value="amount_asc">Amount (low)</option>
              </select>
            </div>
          </div>

          <div style={{ display: 'flex', gap: '0.5rem', alignItems: 'center', flexWrap: 'wrap' }}>
            <span style={{ fontSize: '0.875rem', fontWeight: 500 }}>Type:</span>
            {(['all', 'earned', 'sent', 'received'] as const).map((type) => (
              <button
                key={type}
                type="button"
                className={typeFilter === type ? 'chip active' : 'chip'}
                onClick={() => {
                  setTypeFilter(type)
                  setPage(1)
                }}
                style={{ textTransform: 'capitalize' }}
              >
                {type}
              </button>
            ))}
            {(searchQuery || typeFilter !== 'all' || dateFrom || dateTo || sortBy !== 'date_desc') && (
              <button
                type="button"
                onClick={handleClearFilters}
                style={{
                  background: 'none',
                  border: 'none',
                  color: 'var(--brand)',
                  cursor: 'pointer',
                  fontSize: '0.875rem',
                  textDecoration: 'underline',
                }}
              >
                Clear filters
              </button>
            )}
          </div>
        </div>

        <div className="table-wrap">
          <table>
            <thead>
              <tr>
                <th style={{ cursor: 'pointer' }} onClick={() => setSortBy(sortBy === 'date_desc' ? 'date_asc' : 'date_desc')}>
                  Date {sortBy.startsWith('date') && (sortBy === 'date_desc' ? '↓' : '↑')}
                </th>
                <th>Reason</th>
                <th style={{ cursor: 'pointer' }} onClick={() => setSortBy(sortBy === 'amount_desc' ? 'amount_asc' : 'amount_desc')}>
                  Amount {sortBy.startsWith('amount') && (sortBy === 'amount_desc' ? '↓' : '↑')}
                </th>
              </tr>
            </thead>
            <tbody>
              {historyQuery.isLoading ? (
                Array.from({ length: 3 }).map((_, index) => (
                  <tr key={`reward-skeleton-${index}`}>
                    <td><div className="skeleton-line" /></td>
                    <td><div className="skeleton-line" /></td>
                    <td><div className="skeleton-line" /></td>
                  </tr>
                ))
              ) : (
                (historyQuery.data?.rows ?? []).map((row) => (
                  <tr key={row.id}>
                    <td>{formatDateTime(row.created_at)}</td>
                    <td>{formatRewardReason(row.reason)}</td>
                    <td className={row.amount >= 0 ? 'amount-plus' : 'amount-minus'}>
                      {formatEchoAmount(row.amount)}
                    </td>
                  </tr>
                ))
              )}
            </tbody>
          </table>

          {historyQuery.isError ? <p className="error-text">Failed to load transactions.</p> : null}
          {!historyQuery.isLoading && !historyQuery.data?.rows.length ? (
            <p className="muted">
              {searchQuery || typeFilter !== 'all' || dateFrom || dateTo
                ? `No transactions match "${searchQuery || 'your filters'}"`
                : 'No transactions yet.'}
            </p>
          ) : null}
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


