import { useState, useEffect, useCallback } from 'react'
import { supabase } from '../../lib/supabase'
import { MoodPin, Sentiment } from '../../lib/types'
import { useAuth } from '../../lib/auth-context'

export function useMoodPins() {
  const { user } = useAuth()
  const [pins, setPins] = useState<MoodPin[]>([])
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState<string | null>(null)
  const [geoStatus, setGeoStatus] = useState<'idle' | 'pending' | 'denied' | 'done'>('idle')

  // Derive current user's pins from the global list
  const myPins = pins.filter((p) => p.user_id === user?.id)

  const fetchPins = useCallback(async () => {
    try {
      setLoading(true)
      const { data, error: fetchError } = await supabase
        .from('mood_pins')
        .select('*')
        .gt('expires_at', new Date().toISOString())
        .order('created_at', { ascending: false })

      if (fetchError) throw fetchError
      setPins(data as MoodPin[])
    } catch (err: any) {
      setError(err.message)
    } finally {
      setLoading(false)
    }
  }, [])

  useEffect(() => {
    fetchPins()
  }, [fetchPins])

  // Realtime subscription
  useEffect(() => {
    const channel = supabase
      .channel('public:mood_pins')
      .on(
        'postgres_changes',
        { event: 'INSERT', schema: 'public', table: 'mood_pins' },
        (payload) => {
          const newPin = payload.new as MoodPin
          // Only add if not expired (unlikely for new pins, but safe)
          if (new Date(newPin.expires_at) > new Date()) {
            setPins((prev) => [newPin, ...prev])
          }
        }
      )
      .on(
        'postgres_changes',
        { event: 'DELETE', schema: 'public', table: 'mood_pins' },
        (payload) => {
          setPins((prev) => prev.filter((p) => p.id !== payload.old.id))
        }
      )
      .subscribe()

    return () => {
      supabase.removeChannel(channel)
    }
  }, [])

  const anonymize = (coord: number): number => {
    return Math.round(coord * 10) / 10
  }

  const insertPin = async (sentiment: Sentiment) => {
    if (!user?.id) return

    setGeoStatus('pending')
    setError(null)

    return new Promise<void>((resolve, reject) => {
      navigator.geolocation.getCurrentPosition(
        async (pos) => {
          try {
            const { error: insertError } = await supabase.from('mood_pins').insert({
              sentiment,
              grid_lat: anonymize(pos.coords.latitude),
              grid_lon: anonymize(pos.coords.longitude),
              user_id: user.id,
            })

            if (insertError) throw insertError

            setGeoStatus('done')
            setTimeout(() => setGeoStatus('idle'), 2000)
            resolve()
          } catch (err: any) {
            setError('Failed to drop pin. Please try again.')
            setGeoStatus('idle')
            reject(err)
          }
        },
        () => {
          setGeoStatus('denied')
          reject(new Error('Geolocation denied'))
        }
      )
    })
  }

  const deletePin = async (id: string) => {
    if (!user?.id) return
    try {
      const { error: deleteError } = await supabase
        .from('mood_pins')
        .delete()
        .eq('id', id)
        .eq('user_id', user.id) // Extra safety, RLS also protects this

      if (deleteError) throw deleteError
      
      // Optimistic update
      setPins((prev) => prev.filter((p) => p.id !== id))
    } catch (err: any) {
      setError('Failed to delete pin.')
      console.error(err)
    }
  }

  return {
    pins,
    myPins,
    loading,
    error,
    geoStatus,
    insertPin,
    deletePin,
  }
}
