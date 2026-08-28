# Offline Sync Conflict Resolution Strategy

## Overview (Issue #702)

When an EchoMirror user edits mood logs, habit reflections, or daily notes while offline, their mutations are queued in local persistent storage (`OfflineStorageService`). Upon network reconnection, `MoodSyncService` drains the queue and pushes updates to Supabase.

Before Issue #702, a naive "client always wins" overwriting model was assumed. If a server-side record diverged in the interim (e.g. from an edit on a second device, or asynchronous AI insight generation updating the entry), the offline client could silently clobber newer server modifications.

## Conflict Definition

A **Conflict** is detected when:
1. A locally queued mutation targets a date/record that already exists on the server.
2. The server's `updated_at` timestamp is strictly newer than the base timestamp when the local client began modifying the entry.

## Resolution Rules (Smart Field Merge)

EchoMirror uses a deterministic, non-destructive **Smart Field Merge** (`ConflictResolutionStrategy.smartFieldMerge`):

| Field | Resolution Rule | Rationale |
|---|---|---|
| **Mood Score (1-5)** | Last-Write-Wins (LWW) by timestamp | Mood reflects a momentary emotional snapshot; the most recently recorded assessment is authoritative. |
| **Habits (Array / Set)** | Set Union (`Set.union(server, local)`) | Non-destructive: completing a habit offline and completing a different habit on desktop preserves both completions. |
| **Notes (Free-text)** | Non-destructive Preservation | If both revisions contain distinct text, both are preserved (`<server_note>\n\n[Offline update]:\n<local_note>`). If only one side modified notes, the edited version is kept. |
| **Metadata / Timestamps** | `updated_at: DateTime.now().toUtc()` | Records the timestamp of the successful reconciliation. |

## Extension Guide for New Models (Habits, Goals, Letters)

Future contributors adding offline support to habit logs or other entity repositories should:
1. Inject or call `ConflictResolutionService.instance`.
2. Follow the set-union pattern for collections and non-destructive concatenation for free-text reflections.
3. Add unit tests simulating diverging concurrent updates in `test/core/services/conflict_resolution_service_test.dart`.
