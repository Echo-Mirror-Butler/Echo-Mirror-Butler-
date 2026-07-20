-- Migration: Add rate_limits table and transfer_echo RPC for atomic ECHO transfers
-- Issue #394: rate limiting, input validation, atomic balance updates, audit log

-- ── Rate limits table ──────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.rate_limits (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    action text NOT NULL,
    window_start timestamptz NOT NULL DEFAULT now(),
    count integer NOT NULL DEFAULT 1,
    created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_rate_limits_user_action_window
    ON public.rate_limits(user_id, action, window_start);

ALTER TABLE public.rate_limits ENABLE ROW LEVEL SECURITY;

do $$
begin
    create policy "Service role manages rate_limits"
        on public.rate_limits for all
        using (true)
        with check (true);
exception
    when duplicate_object then null;
end $$;

-- ── Helper: check and increment rate limit ─────────────────────
-- Returns true if the action is allowed (under limit), false if rate-limited.
CREATE OR REPLACE FUNCTION public.check_rate_limit(
    p_user_id uuid,
    p_action text,
    p_max_count integer DEFAULT 10,
    p_window_hours numeric DEFAULT 1.0
)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_window_start timestamptz;
    v_current_count integer;
    v_row_id uuid;
BEGIN
    v_window_start := date_trunc('hour', now());

    -- Try to find existing rate limit row for this user+action+window
    SELECT id, count INTO v_row_id, v_current_count
    FROM public.rate_limits
    WHERE user_id = p_user_id
      AND action = p_action
      AND window_start = v_window_start
    FOR UPDATE;

    IF NOT FOUND THEN
        -- No row yet for this window — insert one
        INSERT INTO public.rate_limits (user_id, action, window_start, count)
        VALUES (p_user_id, p_action, v_window_start, 1);
        RETURN true;
    END IF;

    IF v_current_count >= p_max_count THEN
        RETURN false;  -- Rate limited
    END IF;

    -- Increment count
    UPDATE public.rate_limits
    SET count = count + 1
    WHERE id = v_row_id;

    RETURN true;
END;
$$;

-- ── Atomic transfer RPC ───────────────────────────────────────
-- Atomically debits sender, credits recipient, logs echo_rewards,
-- and records the gift_transaction. Returns JSON with success/error.
-- Note: The Stellar transaction is submitted BEFORE calling this RPC,
-- so the tx_hash is passed in. If this RPC fails, the Stellar tx
-- still went through — a reconciliation process would handle orphans.
CREATE OR REPLACE FUNCTION public.complete_echo_transfer(
    p_sender_id uuid,
    p_recipient_id uuid,
    p_amount integer,
    p_stellar_tx_hash text,
    p_message text DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_sender_balance integer;
    v_gift_id uuid;
    v_sender_reward_id uuid;
    v_recipient_reward_id uuid;
BEGIN
    -- Lock and check sender's wallet
    SELECT balance INTO v_sender_balance
    FROM public.user_wallets
    WHERE user_id = p_sender_id
    FOR UPDATE;

    IF NOT FOUND THEN
        RETURN jsonb_build_object(
            'success', false,
            'error', 'Sender wallet not found',
            'code', 'SENDER_WALLET_NOT_FOUND'
        );
    END IF;

    IF v_sender_balance < p_amount THEN
        RETURN jsonb_build_object(
            'success', false,
            'error', 'Insufficient balance',
            'code', 'INSUFFICIENT_BALANCE'
        );
    END IF;

    -- Debit sender
    UPDATE public.user_wallets
    SET balance = balance - p_amount,
        updated_at = now()
    WHERE user_id = p_sender_id;

    -- Credit recipient
    UPDATE public.user_wallets
    SET balance = balance + p_amount,
        updated_at = now()
    WHERE user_id = p_recipient_id;

    -- Insert gift_transaction record
    INSERT INTO public.gift_transactions (
        sender_user_id,
        recipient_user_id,
        echo_amount,
        stellar_tx_hash,
        message,
        status
    ) VALUES (
        p_sender_id,
        p_recipient_id,
        p_amount,
        p_stellar_tx_hash,
        p_message,
        'completed'
    )
    RETURNING id INTO v_gift_id;

    -- Log audit trail in echo_rewards (sender loses, recipient gains)
    INSERT INTO public.echo_rewards (user_id, amount, reason)
    VALUES
        (p_sender_id, -p_amount, 'gift_sent'),
        (p_recipient_id, p_amount, 'gift_received');

    -- Return success
    RETURN jsonb_build_object(
        'success', true,
        'code', 'TRANSFER_COMPLETED',
        'gift_id', v_gift_id
    );
END;
$$;