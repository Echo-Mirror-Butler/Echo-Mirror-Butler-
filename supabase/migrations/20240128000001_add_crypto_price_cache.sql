-- Create crypto price cache table
CREATE TABLE IF NOT EXISTS crypto_price_cache (
  coin_id TEXT PRIMARY KEY,
  usd_price DECIMAL(20, 8) NOT NULL,
  last_updated TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Add index on last_updated for efficient staleness checks
CREATE INDEX IF NOT EXISTS idx_crypto_price_cache_last_updated 
  ON crypto_price_cache(last_updated);

-- Add comment for documentation
COMMENT ON TABLE crypto_price_cache IS 
  'Caches cryptocurrency prices from CoinGecko to reduce API calls and handle outages gracefully';

COMMENT ON COLUMN crypto_price_cache.coin_id IS 
  'CoinGecko coin identifier (e.g., stellar, bitcoin, ethereum)';

COMMENT ON COLUMN crypto_price_cache.usd_price IS 
  'Price in USD, stored with high precision';

COMMENT ON COLUMN crypto_price_cache.last_updated IS 
  'Timestamp when price was last fetched from CoinGecko';

-- Optional: Add a scheduled refresh function (requires pg_cron extension)
-- This ensures prices are refreshed even if no clients request them
CREATE OR REPLACE FUNCTION refresh_crypto_prices()
RETURNS void AS $$
DECLARE
  coin_record RECORD;
BEGIN
  -- This function is meant to be called by pg_cron or a similar scheduler
  -- It ensures the cache stays fresh without client requests
  -- The actual refresh logic is in the edge function
  RAISE NOTICE 'Price cache refresh triggered at %', NOW();
END;
$$ LANGUAGE plpgsql;

-- Grant permissions for the service role
ALTER TABLE crypto_price_cache ENABLE ROW LEVEL SECURITY;

-- Allow service role full access
CREATE POLICY service_role_all ON crypto_price_cache
  FOR ALL
  TO service_role
  USING (true)
  WITH CHECK (true);

-- Allow authenticated users to read cached prices
CREATE POLICY authenticated_read ON crypto_price_cache
  FOR SELECT
  TO authenticated
  USING (true);
