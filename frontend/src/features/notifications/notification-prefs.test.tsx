/**
 * Tests for the quiet-hours + digest-frequency controls (issue #616).
 * Focuses on the QuietHoursControls card loading existing prefs and saving
 * changes back to the profiles table.
 */
import { QueryClient, QueryClientProvider } from '@tanstack/react-query'
import { fireEvent, render, screen, waitFor } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { afterEach, beforeEach, describe, expect, test, vi } from 'vitest'
import { NotificationPrefs } from './notification-prefs'

const mockFrom = vi.hoisted(() => vi.fn())
const mockUpdate = vi.hoisted(() => vi.fn())

// Push-notification hook is unrelated to the quiet-hours card — stub it so the
// "Daily Mood Reminders" card renders harmlessly as "unsupported".
vi.mock('../../lib/use-push-notifications', () => ({
  usePushNotifications: () => ({
    permissionState: 'unsupported',
    prefs: { enabled: false, reminderTime: '09:00' },
    loading: false,
    error: null,
    swAvailable: false,
    subscriptionExpired: false,
    subscribe: vi.fn(),
    unsubscribe: vi.fn(),
    updateReminderTime: vi.fn(),
  }),
}))

vi.mock('../../lib/use-toast', () => ({
  useToast: () => ({ showToast: vi.fn() }),
}))

vi.mock('../../lib/supabase', () => ({
  supabase: { from: mockFrom },
}))

const currentRow = {
  quiet_hours_enabled: true,
  quiet_hours_start: '22:00',
  quiet_hours_end: '08:00',
  mood_comment_digest_mode: 'immediately',
}

function setup() {
  // profiles select chain for both WeeklyDigestToggle and QuietHoursControls.
  mockUpdate.mockReturnValue({ eq: vi.fn().mockResolvedValue({ error: null }) })
  mockFrom.mockImplementation(() => {
    const chain = {
      select: vi.fn(() => chain),
      eq: vi.fn(() => chain),
      maybeSingle: vi.fn().mockResolvedValue({ data: currentRow, error: null }),
      update: mockUpdate,
    }
    return chain
  })

  const queryClient = new QueryClient({ defaultOptions: { queries: { retry: false } } })
  return render(
    <QueryClientProvider client={queryClient}>
      <NotificationPrefs userId="user-123" />
    </QueryClientProvider>,
  )
}

describe('QuietHoursControls', () => {
  beforeEach(() => {
    mockFrom.mockReset()
    mockUpdate.mockReset()
  })
  afterEach(() => vi.clearAllMocks())

  test('loads existing quiet-hours prefs from profiles', async () => {
    setup()
    expect(await screen.findByText('Quiet Hours & Digest')).toBeInTheDocument()
    // Enabled → the start/end time inputs are shown with saved values.
    await waitFor(() => {
      expect(screen.getByLabelText('Quiet hours start time')).toHaveValue('22:00')
    })
    expect(screen.getByLabelText('Quiet hours end time')).toHaveValue('08:00')
    expect(screen.getByLabelText('Mood-comment notification frequency')).toHaveValue(
      'immediately',
    )
  })

  test('saves digest-mode change back to profiles', async () => {
    setup()
    const select = await screen.findByLabelText('Mood-comment notification frequency')
    fireEvent.change(select, { target: { value: 'daily' } })

    await waitFor(() => {
      expect(mockUpdate).toHaveBeenCalledWith(
        expect.objectContaining({ mood_comment_digest_mode: 'daily' }),
      )
    })
  })

  test('saves quiet-hours start-time change back to profiles', async () => {
    setup()
    const startInput = await screen.findByLabelText('Quiet hours start time')
    await userEvent.clear(startInput)
    await userEvent.type(startInput, '23:30')

    await waitFor(() => {
      expect(mockUpdate).toHaveBeenCalledWith(
        expect.objectContaining({ quiet_hours_start: '23:30' }),
      )
    })
  })
})
