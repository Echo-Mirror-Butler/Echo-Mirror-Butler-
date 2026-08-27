import { useState, useEffect, useCallback, useRef } from 'react'
import { useQuery, useQueryClient, useMutation } from '@tanstack/react-query'
import type { RealtimeChannel } from '@supabase/supabase-js'
import { supabase } from '../lib/supabase'
import { useAuth } from '../lib/auth-context'
import { formatDateTime } from '../lib/date'

const MAX_COMMENT_LENGTH = 500

type MoodPinComment = {
  id: string
  mood_pin_id: string
  user_id: string
  text: string
  created_at: string
}

type MoodPinCommentsPanelProps = {
  pinId: string
  onClose: () => void
}

function parseRateLimitError(error: unknown): { isRateLimited: boolean; retryAfterSeconds: number } {
  const msg = error instanceof Error ? error.message : String(error)
  if (msg.includes('rate_limit_exceeded') || msg.includes('PT429') || msg.includes('429')) {
    const match = msg.match(/retry_after_seconds['":\s]+(\d+)/)
    return { isRateLimited: true, retryAfterSeconds: match ? Number(match[1]) : 3600 }
  }
  return { isRateLimited: false, retryAfterSeconds: 0 }
}

function parseProfanityError(error: unknown): boolean {
  const msg = error instanceof Error ? error.message : String(error)
  return msg.includes('inappropriate') || msg.includes('Profanity')
}

export function MoodPinCommentsPanel({ pinId, onClose }: MoodPinCommentsPanelProps) {
  const { user } = useAuth()
  const queryClient = useQueryClient()
  const [newComment, setNewComment] = useState('')
  const [rateLimitError, setRateLimitError] = useState<string | null>(null)
  const [profanityError, setProfanityError] = useState<string | null>(null)
  const channelRef = useRef<RealtimeChannel | null>(null)
  const [showReportModal, setShowReportModal] = useState<string | null>(null)
  const [reportReason, setReportReason] = useState('')
  const [blockConfirm, setBlockConfirm] = useState<string | null>(null)

  const { data: comments = [], isLoading } = useQuery({
    queryKey: ['mood-pin-comments', pinId],
    queryFn: async () => {
      const { data, error } = await supabase
        .from('mood_pin_comments')
        .select('id, text, created_at, user_id')
        .eq('mood_pin_id', pinId)
        .order('created_at', { ascending: true })
        .limit(50)

      if (error) throw error
      return (data ?? []) as MoodPinComment[]
    },
    enabled: Boolean(pinId),
  })

  // Fetch blocked user IDs for client-side filtering
  const { data: blockedIds = [] } = useQuery({
    queryKey: ['blocked-users', user?.id],
    queryFn: async () => {
      if (!user?.id) return []
      const { data, error } = await supabase
        .from('user_blocks')
        .select('blocked_id')
        .eq('blocker_id', user.id)
      if (error) return []
      return (data ?? []).map((r) => r.blocked_id as string)
    },
    enabled: Boolean(user?.id),
  })

  // Filter out comments from blocked users
  const visibleComments = comments.filter((c) => !blockedIds.includes(c.user_id))

  useEffect(() => {
    if (!pinId) return

    const channel = supabase
      .channel(`mood_pin_comments_${pinId}`)
      .on('postgres_changes',
        {
          event: 'INSERT',
          schema: 'public',
          table: 'mood_pin_comments',
          filter: `mood_pin_id=eq.${pinId}`
        },
        (payload) => {
          const newComment = payload.new as MoodPinComment
          queryClient.setQueryData<MoodPinComment[]>(
            ['mood-pin-comments', pinId],
            (old = []) => [...old, newComment]
          )
        }
      )
      .subscribe()

    channelRef.current = channel

    return () => {
      if (channelRef.current) {
        supabase.removeChannel(channelRef.current)
      }
    }
  }, [pinId, queryClient])

  const addCommentMutation = useMutation({
    mutationFn: async (text: string) => {
      if (!user?.id) throw new Error('User not authenticated')

      if (text.length > MAX_COMMENT_LENGTH) {
        throw new Error(`Comment must be ${MAX_COMMENT_LENGTH} characters or less`)
      }

      const { data, error } = await supabase
        .from('mood_pin_comments')
        .insert({
          mood_pin_id: pinId,
          user_id: user.id,
          text: text.trim(),
        })
        .select('*')
        .single()

      if (error) throw error
      return data as MoodPinComment
    },
    onMutate: async (newText) => {
      await queryClient.cancelQueries({ queryKey: ['mood-pin-comments', pinId] })
      const previousComments = queryClient.getQueryData<MoodPinComment[]>(['mood-pin-comments', pinId])

      const optimisticComment: MoodPinComment = {
        id: `optimistic-${Date.now()}`,
        mood_pin_id: pinId,
        user_id: user!.id,
        text: newText.trim(),
        created_at: new Date().toISOString(),
      }

      queryClient.setQueryData<MoodPinComment[]>(
        ['mood-pin-comments', pinId],
        (old = []) => [...old, optimisticComment]
      )

      return { previousComments }
    },
    onError: (err, _newText, context) => {
      if (context?.previousComments) {
        queryClient.setQueryData(['mood-pin-comments', pinId], context.previousComments)
      }

      const { isRateLimited, retryAfterSeconds } = parseRateLimitError(err)
      if (isRateLimited) {
        const mins = Math.ceil(retryAfterSeconds / 60)
        setRateLimitError(`You're posting too fast. Try again in ${mins} minute${mins === 1 ? '' : 's'}.`)
      } else if (parseProfanityError(err)) {
        setProfanityError('Your comment contains inappropriate language. Please revise and try again.')
      }
    },
    onSuccess: () => {
      setNewComment('')
      setRateLimitError(null)
      setProfanityError(null)
    },
  })

  const reportMutation = useMutation({
    mutationFn: async ({ commentId, reason }: { commentId: string; reason: string }) => {
      if (!user?.id) throw new Error('Not authenticated')
      const { error } = await supabase.from('reported_content').insert({
        content_type: 'mood_pin_comment',
        content_id: commentId,
        reported_by: user.id,
        reason,
      })
      if (error) throw error
    },
    onSuccess: () => {
      setShowReportModal(null)
      setReportReason('')
    },
  })

  const blockMutation = useMutation({
    mutationFn: async (blockedId: string) => {
      if (!user?.id) throw new Error('Not authenticated')
      const { error } = await supabase.rpc('block_user', { p_blocked_id: blockedId })
      if (error) throw error
    },
    onSuccess: (_data, blockedId) => {
      queryClient.setQueryData<string[]>(['blocked-users', user?.id], (old = []) => [...old, blockedId])
      setBlockConfirm(null)
    },
  })

  const handleSubmit = useCallback((e: React.FormEvent) => {
    e.preventDefault()
    setRateLimitError(null)
    setProfanityError(null)
    if (newComment.trim() && !addCommentMutation.isPending) {
      addCommentMutation.mutate(newComment.trim())
    }
  }, [newComment, addCommentMutation])

  const handleBackdropClick = useCallback((e: React.MouseEvent) => {
    if (e.target === e.currentTarget) {
      onClose()
    }
  }, [onClose])

  if (!pinId) return null

  return (
    <div className="comments-panel-backdrop" onClick={handleBackdropClick}>
      <div className="comments-panel">
        <div className="comments-panel-header">
          <h3>Comments</h3>
          <button type="button" className="close-button" onClick={onClose}>
            ✕
          </button>
        </div>

        <div className="comments-list">
          {isLoading ? (
            <div className="loading">Loading comments...</div>
          ) : visibleComments.length === 0 ? (
            <div className="empty-state">No comments yet. Be the first to share!</div>
          ) : (
            visibleComments.map((comment) => (
              <div key={comment.id} className="comment-item">
                <div className="comment-header">
                  <span className="comment-author">
                    {comment.user_id === user?.id ? 'You' : 'Anonymous'}
                  </span>
                  <div style={{ display: 'flex', alignItems: 'center', gap: '0.5rem' }}>
                    <span className="comment-time">
                      {formatDateTime(comment.created_at)}
                    </span>
                    {comment.user_id !== user?.id && (
                      <div style={{ display: 'flex', gap: '0.25rem' }}>
                        <button
                          type="button"
                          onClick={() => setShowReportModal(comment.id)}
                          style={{ fontSize: '0.7rem', padding: '0.15rem 0.4rem', background: 'none', border: '1px solid var(--line)', borderRadius: '4px', cursor: 'pointer', color: 'var(--muted)' }}
                          aria-label="Report comment"
                        >
                          🚩
                        </button>
                        <button
                          type="button"
                          onClick={() => setBlockConfirm(comment.user_id)}
                          style={{ fontSize: '0.7rem', padding: '0.15rem 0.4rem', background: 'none', border: '1px solid var(--line)', borderRadius: '4px', cursor: 'pointer', color: 'var(--muted)' }}
                          aria-label="Block user"
                        >
                          🚫
                        </button>
                      </div>
                    )}
                  </div>
                </div>
                <p className="comment-text">{comment.text}</p>
              </div>
            ))
          )}
        </div>

        <form onSubmit={handleSubmit} className="comment-form">
          <div className="comment-input-wrapper">
            <textarea
              value={newComment}
              onChange={(e) => {
                setNewComment(e.target.value)
                setRateLimitError(null)
                setProfanityError(null)
              }}
              placeholder="Add a comment..."
              rows={3}
              maxLength={MAX_COMMENT_LENGTH}
            />
            <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
              <span style={{ fontSize: '0.75rem', color: newComment.length > MAX_COMMENT_LENGTH * 0.9 ? 'var(--danger)' : 'var(--muted)' }}>
                {newComment.length}/{MAX_COMMENT_LENGTH}
              </span>
              <button
                type="submit"
                disabled={!newComment.trim() || addCommentMutation.isPending || newComment.length > MAX_COMMENT_LENGTH}
                className="submit-button"
              >
                {addCommentMutation.isPending ? 'Posting...' : 'Post'}
              </button>
            </div>
          </div>
          {rateLimitError && (
            <div role="alert" className="error-message" style={{ color: '#f97316' }}>
              ⏳ {rateLimitError}
            </div>
          )}
          {profanityError && (
            <div role="alert" className="error-message">
              ⚠️ {profanityError}
            </div>
          )}
          {addCommentMutation.error && !rateLimitError && !profanityError && (
            <div className="error-message">
              {(addCommentMutation.error as Error).message}
            </div>
          )}
        </form>

        {/* Report modal */}
        {showReportModal && (
          <div style={{ position: 'absolute', inset: 0, background: 'rgba(0,0,0,0.5)', display: 'flex', alignItems: 'center', justifyContent: 'center', zIndex: 10, padding: '1rem' }}>
            <div style={{ background: 'var(--surface)', borderRadius: '12px', padding: '1.25rem', width: '100%', maxWidth: '320px', border: '1px solid var(--line)' }}>
              <h4 style={{ margin: '0 0 0.75rem' }}>Report Comment</h4>
              <textarea
                value={reportReason}
                onChange={(e) => setReportReason(e.target.value)}
                placeholder="Why are you reporting this? (e.g., spam, harassment, inappropriate)"
                rows={3}
                style={{ width: '100%', padding: '0.5rem', borderRadius: '6px', border: '1px solid var(--line)', fontSize: '0.85rem', resize: 'none' }}
              />
              <div style={{ display: 'flex', gap: '0.5rem', marginTop: '0.75rem', justifyContent: 'flex-end' }}>
                <button type="button" onClick={() => { setShowReportModal(null); setReportReason('') }} style={{ padding: '0.4rem 0.8rem', fontSize: '0.82rem' }}>
                  Cancel
                </button>
                <button
                  type="button"
                  onClick={() => reportMutation.mutate({ commentId: showReportModal, reason: reportReason })}
                  disabled={!reportReason.trim() || reportMutation.isPending}
                  style={{ padding: '0.4rem 0.8rem', fontSize: '0.82rem', background: 'var(--danger)', color: '#fff', border: 'none', borderRadius: '6px' }}
                >
                  {reportMutation.isPending ? 'Submitting...' : 'Submit Report'}
                </button>
              </div>
              {reportMutation.isSuccess && (
                <p style={{ color: 'var(--success)', fontSize: '0.82rem', marginTop: '0.5rem' }}>Report submitted. Thank you.</p>
              )}
            </div>
          </div>
        )}

        {/* Block confirmation */}
        {blockConfirm && (
          <div style={{ position: 'absolute', inset: 0, background: 'rgba(0,0,0,0.5)', display: 'flex', alignItems: 'center', justifyContent: 'center', zIndex: 10, padding: '1rem' }}>
            <div style={{ background: 'var(--surface)', borderRadius: '12px', padding: '1.25rem', width: '100%', maxWidth: '320px', border: '1px solid var(--line)' }}>
              <h4 style={{ margin: '0 0 0.5rem' }}>Block User</h4>
              <p style={{ fontSize: '0.85rem', color: 'var(--muted)', margin: '0 0 0.75rem' }}>
                This user's pins and comments will be hidden from your Global Mirror view. You can unblock them later in Settings.
              </p>
              <div style={{ display: 'flex', gap: '0.5rem', justifyContent: 'flex-end' }}>
                <button type="button" onClick={() => setBlockConfirm(null)} style={{ padding: '0.4rem 0.8rem', fontSize: '0.82rem' }}>
                  Cancel
                </button>
                <button
                  type="button"
                  onClick={() => blockMutation.mutate(blockConfirm)}
                  disabled={blockMutation.isPending}
                  style={{ padding: '0.4rem 0.8rem', fontSize: '0.82rem', background: 'var(--danger)', color: '#fff', border: 'none', borderRadius: '6px' }}
                >
                  {blockMutation.isPending ? 'Blocking...' : 'Block User'}
                </button>
              </div>
            </div>
          </div>
        )}

        <style>{`
          .comments-panel-backdrop {
            position: fixed;
            top: 0;
            left: 0;
            right: 0;
            bottom: 0;
            background: rgba(0, 0, 0, 0.5);
            display: flex;
            justify-content: flex-end;
            z-index: 1000;
          }

          .comments-panel {
            width: 100%;
            max-width: 400px;
            background: white;
            height: 100vh;
            display: flex;
            flex-direction: column;
            box-shadow: -4px 0 12px rgba(0, 0, 0, 0.15);
            position: relative;
          }

          .comments-panel-header {
            display: flex;
            justify-content: space-between;
            align-items: center;
            padding: 1rem;
            border-bottom: 1px solid #e5e7eb;
          }

          .comments-panel-header h3 {
            margin: 0;
            font-size: 1.125rem;
            font-weight: 600;
          }

          .close-button {
            background: none;
            border: none;
            font-size: 1.25rem;
            cursor: pointer;
            color: #6b7280;
            padding: 0.25rem;
            border-radius: 0.25rem;
          }

          .close-button:hover {
            background: #f3f4f6;
          }

          .comments-list {
            flex: 1;
            overflow-y: auto;
            padding: 1rem;
          }

          .loading,
          .empty-state {
            text-align: center;
            color: #6b7280;
            padding: 2rem;
          }

          .comment-item {
            margin-bottom: 1rem;
            padding-bottom: 1rem;
            border-bottom: 1px solid #f3f4f6;
          }

          .comment-item:last-child {
            border-bottom: none;
            margin-bottom: 0;
          }

          .comment-header {
            display: flex;
            justify-content: space-between;
            align-items: center;
            margin-bottom: 0.5rem;
          }

          .comment-author {
            font-weight: 600;
            color: #374151;
            font-size: 0.875rem;
          }

          .comment-time {
            color: #6b7280;
            font-size: 0.75rem;
          }

          .comment-text {
            margin: 0;
            color: #374151;
            line-height: 1.5;
            white-space: pre-wrap;
          }

          .comment-form {
            padding: 1rem;
            border-top: 1px solid #e5e7eb;
          }

          .comment-input-wrapper {
            display: flex;
            flex-direction: column;
            gap: 0.5rem;
          }

          .comment-input-wrapper textarea {
            width: 100%;
            padding: 0.75rem;
            border: 1px solid #d1d5db;
            border-radius: 0.375rem;
            resize: none;
            font-family: inherit;
            font-size: 0.875rem;
          }

          .comment-input-wrapper textarea:focus {
            outline: none;
            border-color: #3b82f6;
            box-shadow: 0 0 0 3px rgba(59, 130, 246, 0.1);
          }

          .submit-button {
            align-self: flex-end;
            padding: 0.5rem 1rem;
            background: #3b82f6;
            color: white;
            border: none;
            border-radius: 0.375rem;
            font-size: 0.875rem;
            font-weight: 500;
            cursor: pointer;
          }

          .submit-button:hover:not(:disabled) {
            background: #2563eb;
          }

          .submit-button:disabled {
            background: #9ca3af;
            cursor: not-allowed;
          }

          .error-message {
            color: #ef4444;
            font-size: 0.875rem;
            margin-top: 0.5rem;
          }

          @media (max-width: 768px) {
            .comments-panel {
              max-width: 100%;
            }
          }
        `}</style>
      </div>
    </div>
  )
}
