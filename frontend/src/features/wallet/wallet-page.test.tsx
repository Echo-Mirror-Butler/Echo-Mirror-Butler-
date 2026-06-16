import { QueryClient, QueryClientProvider } from '@tanstack/react-query'
import { render, screen, waitFor } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { MemoryRouter } from 'react-router-dom'
import { afterEach, beforeEach, describe, expect, test, vi } from 'vitest'
import { ToastProvider } from '../../lib/use-toast'
import { stellarConfig } from '../../lib/stellar-config'
import { WalletPage } from './wallet-page'

let mockFreighterInstalled = false
let mockRequestAccessResult: { address: string; error: { message?: string } | null } = {
  address: '',
  error: null,
}
let mockGetNetworkResult: {
  network: string
  networkPassphrase: string
  error: { message?: string } | null
} = {
  network: 'TESTNET',
  networkPassphrase: stellarConfig.networkPassphrase,
  error: null,
}

const mockFrom = vi.hoisted(() => vi.fn())
const mockInvoke = vi.hoisted(() => vi.fn())
const mockRpc = vi.hoisted(() => vi.fn())

vi.mock('../../lib/auth-context', () => ({
  useAuth: () => ({
    user: {
      id: 'test-user-id',
      email: 'test@example.com',
      user_metadata: { onboarding_completed: true },
    },
    session: null,
    isLoading: false,
    signOut: vi.fn(),
  }),
}))

vi.mock('../../lib/supabase', () => ({
  supabase: {
    from: mockFrom,
    functions: {
      invoke: mockInvoke,
    },
    rpc: mockRpc,
  },
}))

vi.mock('@stellar/freighter-api', () => ({
  requestAccess: vi.fn(() => Promise.resolve(mockRequestAccessResult)),
  getNetwork: vi.fn(() => Promise.resolve(mockGetNetworkResult)),
}))

Object.defineProperty(window, 'freighter', {
  get: () => (mockFreighterInstalled ? {} : undefined),
  configurable: true,
})

function createMockChain(data: unknown = null, error: unknown = null) {
  const chain = {
    select: vi.fn(() => chain),
    eq: vi.fn(() => chain),
    gte: vi.fn(() => chain),
    lte: vi.fn(() => chain),
    order: vi.fn(() => chain),
    range: vi.fn(() => chain),
    maybeSingle: vi.fn(() => Promise.resolve({ data, error })),
    single: vi.fn(() => Promise.resolve({ data, error })),
    upsert: vi.fn(() => chain),
    insert: vi.fn(() => chain),
  }
  return chain
}

function renderWalletPage() {
  const queryClient = new QueryClient({
    defaultOptions: {
      queries: { retry: false },
      mutations: { retry: false },
    },
  })

  return render(
    <QueryClientProvider client={queryClient}>
      <MemoryRouter>
        <ToastProvider>
          <WalletPage />
        </ToastProvider>
      </MemoryRouter>
    </QueryClientProvider>,
  )
}

describe('WalletPage', () => {
  beforeEach(() => {
    mockFrom.mockClear()
    mockInvoke.mockClear()
    mockRpc.mockClear()
    mockRpc.mockResolvedValue({ data: null, error: null })
    mockFreighterInstalled = false
    mockRequestAccessResult = { address: '', error: null }
    mockGetNetworkResult = {
      network: 'TESTNET',
      networkPassphrase: stellarConfig.networkPassphrase,
      error: null,
    }
  })

  afterEach(() => {
    vi.clearAllMocks()
  })

  test('renders Connect Freighter button when no wallet is connected', async () => {
    const walletChain = createMockChain({
      id: 'wallet-1',
      user_id: 'test-user-id',
      public_key: null,
      balance: 0,
    })
    mockFrom.mockReturnValue(walletChain)

    renderWalletPage()

    await waitFor(() => {
      expect(screen.getByText('Connect Freighter')).toBeInTheDocument()
    })
  })

  test('shows install prompt when Freighter extension is not detected', async () => {
    const walletChain = createMockChain({
      id: 'wallet-1',
      user_id: 'test-user-id',
      public_key: null,
      balance: 0,
    })
    mockFrom.mockReturnValue(walletChain)
    mockFreighterInstalled = false

    const user = userEvent.setup()
    renderWalletPage()

    await waitFor(() => {
      expect(screen.getByText('Connect Freighter')).toBeInTheDocument()
    })

    await user.click(screen.getByText('Connect Freighter'))

    await waitFor(() => {
      expect(screen.getByText(/Freighter not found/i)).toBeInTheDocument()
      expect(screen.getByText('Install Freighter')).toBeInTheDocument()
    })
  })

  test('connects via Freighter and shows the address when the network matches testnet', async () => {
    const walletChain = createMockChain({
      id: 'wallet-1',
      user_id: 'test-user-id',
      public_key: null,
      balance: 0,
    })
    mockFrom.mockReturnValue(walletChain)
    mockFreighterInstalled = true
    mockRequestAccessResult = {
      address: 'GABCDEF1234567890ABCDEF1234567890ABCDEF1234567890ABCD',
      error: null,
    }
    mockGetNetworkResult = {
      network: 'TESTNET',
      networkPassphrase: stellarConfig.networkPassphrase,
      error: null,
    }

    const user = userEvent.setup()
    renderWalletPage()

    await waitFor(() => {
      expect(screen.getByText('Connect Freighter')).toBeInTheDocument()
    })

    await user.click(screen.getByText('Connect Freighter'))

    await waitFor(() => {
      expect(screen.getByText('Connected via Freighter')).toBeInTheDocument()
    })
  })

  test('shows an error when the user rejects the Freighter connection request', async () => {
    const walletChain = createMockChain({
      id: 'wallet-1',
      user_id: 'test-user-id',
      public_key: null,
      balance: 0,
    })
    mockFrom.mockReturnValue(walletChain)
    mockFreighterInstalled = true
    mockRequestAccessResult = {
      address: '',
      error: { message: 'User declined access' },
    }

    const user = userEvent.setup()
    renderWalletPage()

    await waitFor(() => {
      expect(screen.getByText('Connect Freighter')).toBeInTheDocument()
    })

    await user.click(screen.getByText('Connect Freighter'))

    await waitFor(() => {
      expect(screen.getByText('User declined access')).toBeInTheDocument()
    })
  })

  test('rejects a Freighter connection on the wrong network', async () => {
    const walletChain = createMockChain({
      id: 'wallet-1',
      user_id: 'test-user-id',
      public_key: null,
      balance: 0,
    })
    mockFrom.mockReturnValue(walletChain)
    mockFreighterInstalled = true
    mockRequestAccessResult = {
      address: 'GABCDEF1234567890ABCDEF1234567890ABCDEF1234567890ABCD',
      error: null,
    }
    mockGetNetworkResult = {
      network: 'PUBLIC',
      networkPassphrase: 'Public Global Stellar Network ; September 2015',
      error: null,
    }

    const user = userEvent.setup()
    renderWalletPage()

    await waitFor(() => {
      expect(screen.getByText('Connect Freighter')).toBeInTheDocument()
    })

    await user.click(screen.getByText('Connect Freighter'))

    await waitFor(() => {
      expect(screen.getByText(/Freighter is set to PUBLIC/i)).toBeInTheDocument()
    })

    expect(screen.queryByText('Connected via Freighter')).not.toBeInTheDocument()
  })

  test('displays wallet address and balance after successful connection', async () => {
    const walletChain = createMockChain({
      id: 'wallet-1',
      user_id: 'test-user-id',
      public_key: 'GABCDEF1234567890ABCDEF1234567890ABCDEF1234567890ABCD',
      balance: 100.5,
    })

    const historyChain = {
      select: vi.fn(() => historyChain),
      eq: vi.fn(() => historyChain),
      order: vi.fn(() => historyChain),
      range: vi.fn(() => Promise.resolve({ data: [], count: 0, error: null })),
    }

    mockFrom.mockImplementation((table: string) => {
      if (table === 'user_wallets') {
        return walletChain
      }
      if (table === 'echo_rewards') {
        return historyChain
      }
      return createMockChain(null)
    })

    renderWalletPage()

    await waitFor(() => {
      const balanceElements = screen.getAllByText(/100\.50 ECHO/i, { exact: false })
      expect(balanceElements.length).toBeGreaterThan(0)
    })
  })

  test('shows Address not found error for invalid recipient', async () => {
    const walletChain = createMockChain({
      id: 'wallet-1',
      user_id: 'test-user-id',
      public_key: 'GABCDEF1234567890ABCDEF1234567890ABCDEF1234567890ABCD',
      balance: 100,
    })

    const historyChain = createMockChain()
    historyChain.range = vi.fn(() => historyChain)
    historyChain.maybeSingle = vi.fn(() => Promise.resolve({ data: [], count: 0, error: null }))

    mockFrom.mockImplementation((table: string) => {
      if (table === 'user_wallets') {
        return walletChain
      }
      if (table === 'echo_rewards') {
        return historyChain
      }
      return createMockChain(null)
    })

    mockInvoke.mockResolvedValue({
      data: { error: 'Could not resolve recipient from email. Use recipient user ID.' },
      error: null,
    })

    const user = userEvent.setup()
    renderWalletPage()

    await waitFor(() => {
      expect(screen.getByText('100.00 ECHO')).toBeInTheDocument()
    })

    const recipientInput = screen.getByPlaceholderText(/UUID, email, or G\.\.\. address/i)
    await user.type(recipientInput, 'invalid@example.com')

    const amountInput = screen.getByPlaceholderText(/Custom amount/i)
    await user.clear(amountInput)
    await user.type(amountInput, '10')

    const sendButton = screen.getByRole('button', { name: /Send 10 ECHO/i })
    await user.click(sendButton)

    await waitFor(() => {
      expect(screen.getAllByText(/Could not resolve recipient/i).length).toBeGreaterThan(0)
    })
  })

  function createUserWalletsTableMock(
    senderRecord: Record<string, unknown>,
    recipientLookupResult: { data: unknown; error: unknown },
  ) {
    let lastEqField: string | null = null
    const chain = {
      select: vi.fn(() => chain),
      eq: vi.fn((field: string) => {
        lastEqField = field
        return chain
      }),
      maybeSingle: vi.fn(() =>
        lastEqField === 'public_key'
          ? Promise.resolve(recipientLookupResult)
          : Promise.resolve({ data: senderRecord, error: null }),
      ),
      upsert: vi.fn(() => chain),
    }
    return chain
  }

  test('shows "Address not found" for an unknown Stellar address recipient', async () => {
    const senderRecord = {
      id: 'wallet-1',
      user_id: 'test-user-id',
      public_key: 'GABCDEF1234567890ABCDEF1234567890ABCDEF1234567890ABCD',
      balance: 100,
    }
    const walletChain = createUserWalletsTableMock(senderRecord, { data: null, error: null })

    const historyChain = createMockChain()
    historyChain.range = vi.fn(() => historyChain)

    mockFrom.mockImplementation((table: string) => {
      if (table === 'user_wallets') {
        return walletChain
      }
      if (table === 'echo_rewards') {
        return historyChain
      }
      return createMockChain(null)
    })

    const user = userEvent.setup()
    renderWalletPage()

    await waitFor(() => {
      expect(screen.getByText('100.00 ECHO')).toBeInTheDocument()
    })

    const recipientInput = screen.getByPlaceholderText(/UUID, email, or G\.\.\. address/i)
    await user.type(recipientInput, 'GAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA')

    const amountInput = screen.getByPlaceholderText(/Custom amount/i)
    await user.clear(amountInput)
    await user.type(amountInput, '10')

    await user.click(screen.getByRole('button', { name: /Send 10 ECHO/i }))

    await waitFor(() => {
      expect(screen.getAllByText(/Address not found/i).length).toBeGreaterThan(0)
    })
  })

  test('shows a network error message when the Stellar address lookup fails', async () => {
    const senderRecord = {
      id: 'wallet-1',
      user_id: 'test-user-id',
      public_key: 'GABCDEF1234567890ABCDEF1234567890ABCDEF1234567890ABCD',
      balance: 100,
    }
    const walletChain = createUserWalletsTableMock(senderRecord, {
      data: null,
      error: { message: 'fetch failed' },
    })

    const historyChain = createMockChain()
    historyChain.range = vi.fn(() => historyChain)

    mockFrom.mockImplementation((table: string) => {
      if (table === 'user_wallets') {
        return walletChain
      }
      if (table === 'echo_rewards') {
        return historyChain
      }
      return createMockChain(null)
    })

    const user = userEvent.setup()
    renderWalletPage()

    await waitFor(() => {
      expect(screen.getByText('100.00 ECHO')).toBeInTheDocument()
    })

    const recipientInput = screen.getByPlaceholderText(/UUID, email, or G\.\.\. address/i)
    await user.type(recipientInput, 'GAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA')

    const amountInput = screen.getByPlaceholderText(/Custom amount/i)
    await user.clear(amountInput)
    await user.type(amountInput, '10')

    await user.click(screen.getByRole('button', { name: /Send 10 ECHO/i }))

    await waitFor(() => {
      expect(screen.getAllByText(/Network error/i).length).toBeGreaterThan(0)
    })
  })

  test('testnet badge renders when VITE_STELLAR_NETWORK is testnet', async () => {
    vi.stubEnv('VITE_STELLAR_NETWORK', 'testnet')

    const walletChain = createMockChain({
      id: 'wallet-1',
      user_id: 'test-user-id',
      public_key: 'GABCDEF1234567890ABCDEF1234567890ABCDEF1234567890ABCD',
      balance: 50,
    })
    mockFrom.mockReturnValue(walletChain)

    renderWalletPage()

    await waitFor(() => {
      expect(screen.getByText('50.00 ECHO')).toBeInTheDocument()
    })

    vi.unstubAllEnvs()
  })

  test('shows a prominent testnet warning banner', async () => {
    const walletChain = createMockChain({
      id: 'wallet-1',
      user_id: 'test-user-id',
      public_key: 'GABCDEF1234567890ABCDEF1234567890ABCDEF1234567890ABCD',
      balance: 50,
    })
    mockFrom.mockReturnValue(walletChain)

    renderWalletPage()

    await waitFor(() => {
      expect(screen.getByText(/You are on Testnet/i)).toBeInTheDocument()
    })
  })

  test('no wallet exists state renders create wallet button', async () => {
    const walletChain = createMockChain(null)
    mockFrom.mockReturnValue(walletChain)

    renderWalletPage()

    await waitFor(() => {
      expect(screen.getByText('No wallet yet.')).toBeInTheDocument()
      expect(screen.getByText('Create wallet')).toBeInTheDocument()
    })
  })

  test('create wallet mutation triggers edge function', async () => {
    const walletChain = createMockChain(null)
    const updatedWalletChain = createMockChain({
      id: 'wallet-1',
      user_id: 'test-user-id',
      public_key: null,
      balance: 0,
    })

    let callCount = 0
    mockFrom.mockImplementation(() => {
      callCount++
      return callCount === 1 ? walletChain : updatedWalletChain
    })

    mockInvoke.mockResolvedValue({ data: {}, error: null })

    const user = userEvent.setup()
    renderWalletPage()

    await waitFor(() => {
      expect(screen.getByText('Create wallet')).toBeInTheDocument()
    })

    await user.click(screen.getByText('Create wallet'))

    await waitFor(() => {
      expect(mockInvoke).toHaveBeenCalledWith('create-stellar-wallet', expect.any(Object))
    })
  })

  test('send gift form validates amount exceeds balance', async () => {
    const walletChain = createMockChain({
      id: 'wallet-1',
      user_id: 'test-user-id',
      public_key: 'GABCDEF1234567890ABCDEF1234567890ABCDEF1234567890ABCD',
      balance: 5,
    })

    const historyChain = createMockChain()
    historyChain.range = vi.fn(() => historyChain)
    historyChain.maybeSingle = vi.fn(() => Promise.resolve({ data: [], count: 0, error: null }))

    mockFrom.mockImplementation((table: string) => {
      if (table === 'user_wallets') {
        return walletChain
      }
      if (table === 'echo_rewards') {
        return historyChain
      }
      return createMockChain(null)
    })

    const user = userEvent.setup()
    renderWalletPage()

    await waitFor(() => {
      expect(screen.getByText('5.00 ECHO')).toBeInTheDocument()
    })

    const recipientInput = screen.getByPlaceholderText(/UUID, email, or G\.\.\. address/i)
    await user.type(recipientInput, 'recipient-user-id')

    const amountInput = screen.getByPlaceholderText(/Custom amount/i)
    await user.clear(amountInput)
    await user.type(amountInput, '100')

    await waitFor(() => {
      expect(screen.getByText('Amount exceeds your balance.')).toBeInTheDocument()
    })
  })

  test('displays transaction history with pagination', async () => {
    const walletChain = createMockChain({
      id: 'wallet-1',
      user_id: 'test-user-id',
      public_key: 'GABCDEF1234567890ABCDEF1234567890ABCDEF1234567890ABCD',
      balance: 100,
    })

    const historyData = [
      {
        id: 'reward-1',
        user_id: 'test-user-id',
        amount: 1,
        reason: 'daily_mood_log',
        created_at: '2024-04-29T10:00:00.000Z',
      },
      {
        id: 'reward-2',
        user_id: 'test-user-id',
        amount: 5,
        reason: '7_day_streak_bonus',
        created_at: '2024-04-28T10:00:00.000Z',
      },
    ]

    const historyChain = {
      select: vi.fn(() => historyChain),
      eq: vi.fn(() => historyChain),
      order: vi.fn(() => historyChain),
      range: vi.fn(() => Promise.resolve({ data: historyData, count: 2, error: null })),
      maybeSingle: vi.fn(() => Promise.resolve({ data: null, error: null })),
    }

    mockFrom.mockImplementation((table: string) => {
      if (table === 'user_wallets') {
        return walletChain
      }
      if (table === 'echo_rewards') {
        return historyChain
      }
      return createMockChain(null)
    })

    renderWalletPage()

    await waitFor(() => {
      expect(screen.getByText(/Daily log/i)).toBeInTheDocument()
      expect(screen.getByText(/7-day streak bonus/i)).toBeInTheDocument()
      expect(screen.getByText('+1 ECHO')).toBeInTheDocument()
      expect(screen.getByText('+5 ECHO')).toBeInTheDocument()
    })
  })

  test('copy wallet address button works correctly', async () => {
    const walletChain = createMockChain({
      id: 'wallet-1',
      user_id: 'test-user-id',
      public_key: 'GABCDEF1234567890ABCDEF1234567890ABCDEF1234567890ABCD',
      balance: 50,
    })

    const historyChain = createMockChain()
    historyChain.range = vi.fn(() => historyChain)
    historyChain.maybeSingle = vi.fn(() => Promise.resolve({ data: [], count: 0, error: null }))

    mockFrom.mockImplementation((table: string) => {
      if (table === 'user_wallets') {
        return walletChain
      }
      if (table === 'echo_rewards') {
        return historyChain
      }
      return createMockChain(null)
    })

    // userEvent.setup() installs its own clipboard stub on `navigator.clipboard`,
    // so our mock must be defined after setup() or it gets overwritten.
    const user = userEvent.setup()
    const writeTextMock = vi.fn(() => Promise.resolve())
    Object.defineProperty(navigator, 'clipboard', {
      value: {
        writeText: writeTextMock,
      },
      configurable: true,
    })

    renderWalletPage()

    await waitFor(() => {
      expect(screen.getByText('50.00 ECHO')).toBeInTheDocument()
    })

    const copyButtons = screen.getAllByRole('button', { name: /Copy/i })
    await user.click(copyButtons[0])

    await waitFor(() => {
      expect(writeTextMock).toHaveBeenCalledWith(
        'GABCDEF1234567890ABCDEF1234567890ABCDEF1234567890ABCD',
      )
      expect(screen.getByText('Copied')).toBeInTheDocument()
    })
  })
})
