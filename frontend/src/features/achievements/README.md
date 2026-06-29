# Achievement Badges Feature

This feature implements achievement badges with milestone celebrations and ECHO rewards for user engagement.

## Components

### 1. Database Schema
- **Table**: `user_achievements`
- **Migration**: `supabase/migrations/20260629000001_add_user_achievements.sql`
- **RLS**: Users can read and insert their own achievements

### 2. Achievement Definitions
- **File**: `achievements.ts`
- **Achievements**: 8 total
  - `first_log` - Log your first mood entry
  - `week_warrior` - 7-day logging streak (+10 ECHO)
  - `month_master` - 30-day logging streak (+50 ECHO)
  - `century` - 100-day logging streak (+200 ECHO)
  - `insight_seeker` - Generate your first AI insight
  - `echo_gifter` - Send ECHO to another user
  - `habit_hero` - Log the same habit 10 days in a row
  - `global_citizen` - Drop a pin on the Global Mirror

### 3. UI Components
- **AchievementsPage**: Grid of badge cards showing locked/unlocked state
- **AchievementModal**: Full-screen celebration modal with confetti
- **useAchievements**: Hook for achievement checking and state management

### 4. Achievement Checkers
- **File**: `achievement-checks.ts`
- Contains async functions to check if achievement conditions are met

## Integration Guide

To integrate achievement checking into your components:

### Step 1: Import the hook and checkers
```typescript
import { useAchievements } from '../achievements/use-achievements'
import { achievementCheckers } from '../achievements/achievement-checks'
```

### Step 2: Use the hook in your component
```typescript
const { checkAndUnlockAchievement } = useAchievements()
```

### Step 3: Check achievements after user actions
```typescript
// After saving a log entry
await checkAndUnlockAchievement('first_log', () => achievementCheckers.first_log(userId))
await checkAndUnlockAchievement('week_warrior', () => achievementCheckers.week_warrior(userId))
await checkAndUnlockAchievement('month_master', () => achievementCheckers.month_master(userId))
await checkAndUnlockAchievement('century', () => achievementCheckers.century(userId))
await checkAndUnlockAchievement('habit_hero', () => achievementCheckers.habit_hero(userId))

// After generating an AI insight
await checkAndUnlockAchievement('insight_seeker', () => achievementCheckers.insight_seeker(userId))

// After sending ECHO
await checkAndUnlockAchievement('echo_gifter', () => achievementCheckers.echo_gifter(userId))

// After dropping a Global Mirror pin
await checkAndUnlockAchievement('global_citizen', () => achievementCheckers.global_citizen(userId))
```

### Example: Log Form Integration
In `log-form-page.tsx`, add this to the `saveMutation.onSuccess` callback:

```typescript
onSuccess: async () => {
  // ... existing invalidation logic ...
  
  // Check achievements
  const { checkAndUnlockAchievement } = useAchievements()
  await Promise.all([
    checkAndUnlockAchievement('first_log', () => achievementCheckers.first_log(user.id)),
    checkAndUnlockAchievement('week_warrior', () => achievementCheckers.week_warrior(user.id)),
    checkAndUnlockAchievement('month_master', () => achievementCheckers.month_master(user.id)),
    checkAndUnlockAchievement('century', () => achievementCheckers.century(user.id)),
    checkAndUnlockAchievement('habit_hero', () => achievementCheckers.habit_hero(user.id)),
  ])
}
```

## How It Works

1. **Achievement Checking**: When a user completes an action, the system checks if any achievement conditions are met
2. **Unlocking**: If a condition is met and the achievement hasn't been unlocked yet, it's recorded in the database
3. **ECHO Rewards**: Achievements with ECHO rewards automatically award the specified amount to the user's wallet
4. **Celebration**: The first time an achievement is unlocked, a modal with confetti animation is displayed
5. **Badge Display**: The achievements page shows all badges with their locked/unlocked state and unlock dates

## Database Functions Required

The achievement system relies on these existing Supabase functions:
- `get_current_streak` - For streak-based achievements
- `add_echo_to_wallet` - For awarding ECHO rewards (if not available, use direct table insertion)

## Notes

- The modal only shows on the **first unlock** of each achievement
- ECHO rewards are automatically added to the user's wallet balance
- The achievement badge count is shown in the sidebar navigation
- All achievement checks are idempotent - checking multiple times won't cause issues
