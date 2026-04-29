import { useState, useEffect, useCallback, useRef } from 'react'
import { useQuery, useQueryClient, useMutation } from '@tanstack/react-query'
import type { RealtimeChannel } from '@supabase/supabase-js'
import { supabase } from '../lib/supabase'
import { useAuth } from '../lib/auth-context'
import { formatDateTime } from '../lib/date'

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

export function MoodPinCommentsPanel({ pinId, onClose }: MoodPinCommentsPanelProps) {
  const { user } = useAuth()
  const queryClient = useQueryClient()
  const [newComment, setNewComment] = useState('')
  const channelRef = useRef<RealtimeChannel | null>(null)

  // Fetch comments for the selected pin
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

  // Realtime subscription for new comments
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

  // Add comment mutation
  const addCommentMutation = useMutation({
    mutationFn: async (text: string) => {
      if (!user?.id) throw new Error('User not authenticated')

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
      // Cancel any outgoing refetches
      await queryClient.cancelQueries({ queryKey: ['mood-pin-comments', pinId] })

      // Snapshot the previous value
      const previousComments = queryClient.getQueryData<MoodPinComment[]>(['mood-pin-comments', pinId])

      // Optimistically update to the new value
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
    onError: (err, newText, context) => {
      // If the mutation fails, use the context returned from onMutate to roll back
      if (context?.previousComments) {
        queryClient.setQueryData(['mood-pin-comments', pinId], context.previousComments)
      }
    },
    onSuccess: () => {
      setNewComment('')
    },
  })

  const handleSubmit = useCallback((e: React.FormEvent) => {
    e.preventDefault()
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
          ) : comments.length === 0 ? (
            <div className="empty-state">No comments yet. Be the first to share!</div>
          ) : (
            comments.map((comment) => (
              <div key={comment.id} className="comment-item">
                <div className="comment-header">
                  <span className="comment-author">
                    {comment.user_id === user?.id ? 'You' : 'Anonymous'}
                  </span>
                  <span className="comment-time">
                    {formatDateTime(comment.created_at)}
                  </span>
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
              onChange={(e) => setNewComment(e.target.value)}
              placeholder="Add a comment..."
              rows={3}
              maxLength={500}
            />
            <button
              type="submit"
              disabled={!newComment.trim() || addCommentMutation.isPending}
              className="submit-button"
            >
              {addCommentMutation.isPending ? 'Posting...' : 'Post'}
            </button>
          </div>
          {addCommentMutation.error && (
            <div className="error-message">
              {(addCommentMutation.error as Error).message}
            </div>
          )}
        </form>

        <style jsx>{`
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
