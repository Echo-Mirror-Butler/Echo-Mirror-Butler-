import { useQuery } from '@tanstack/react-query'
import { supabase } from '../lib/supabase'

export type MaintenanceStatus = {
  enabled: boolean
  message: string | null
  expected_end_at: string | null
}

async function fetchMaintenanceStatus(): Promise<MaintenanceStatus | null> {
  const { data, error } = await supabase
    .from('app_maintenance')
    .select('enabled, message, expected_end_at')
    .eq('id', 1)
    .maybeSingle()

  if (error || !data) {
    return null
  }

  return data as MaintenanceStatus
}

export function useMaintenanceStatus() {
  return useQuery({
    queryKey: ['maintenance-status'],
    queryFn: fetchMaintenanceStatus,
    staleTime: 30_000,
    refetchInterval: 60_000,
  })
}
