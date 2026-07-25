# Issue #593: Fix AI Insight Generation Trigger

## Problem
The AI insight generation may not trigger reliably when users cross the 3-log threshold. Users can get stuck in an indefinite loading state with no insight generated.

## Root Cause Investigation Steps

```bash
# 1. Check if generate-insight is called from anywhere
grep -r "generate-insight" frontend/src/features/ lib/features/
grep -r "generate-insight" supabase/functions/

# 2. Check if there's a client-side trigger
grep -r "triggerGeneration\|generateInsight" lib/features/ai/

# 3. Check if there's a database trigger
psql -U postgres -c "SELECT * FROM pg_trigger WHERE tgname LIKE '%insight%';"
```

## Solution: Multi-Layer Approach

### Layer 1: Reliable Server-Side Trigger (Postgres)

Add this migration to trigger generation automatically:

```sql
-- Create trigger to generate insights when threshold is met
CREATE OR REPLACE FUNCTION trigger_generate_insight_on_threshold()
RETURNS TRIGGER AS $$
DECLARE
  log_count INTEGER;
  user_has_insight BOOLEAN;
BEGIN
  -- Count logs for this user
  SELECT COUNT(*) INTO log_count FROM log_entries WHERE user_id = NEW.user_id;
  
  -- Check if user already has an insight
  SELECT EXISTS(SELECT 1 FROM insights WHERE user_id = NEW.user_id) INTO user_has_insight;
  
  -- If exactly 3 logs and no insight yet, trigger generation
  IF log_count = 3 AND NOT user_has_insight THEN
    -- Call Supabase Edge Function to generate insight
    -- This is non-blocking and doesn't slow down the log insert
    PERFORM http_post(
      current_setting('app.settings.supabase_url') || '/functions/v1/generate-insight',
      json_build_object('userId', NEW.user_id),
      json_build_object('Authorization', 'Bearer ' || current_setting('app.settings.supabase_key'))
    );
  END IF;
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Attach trigger to log_entries
DROP TRIGGER IF EXISTS on_log_entry_insight_check ON log_entries;
CREATE TRIGGER on_log_entry_insight_check
  AFTER INSERT ON log_entries
  FOR EACH ROW
  EXECUTE FUNCTION trigger_generate_insight_on_threshold();
```

### Layer 2: Client-Side Fallback Button

If user has 3+ logs but no insight, show actionable CTA:

```dart
// lib/features/ai/view/widgets/ai_insight_section.dart
class AIInsightSection extends StatefulWidget {
  @override
  State<AIInsightSection> createState() => _AIInsightSectionState();
}

class _AIInsightSectionState extends State<AIInsightSection> {
  late Future<void> _generationFuture;
  bool _generationFailed = false;
  bool _isRetrying = false;

  @override
  void initState() {
    super.initState();
    _generationFuture = _initializeInsightGeneration();
  }

  Future<void> _initializeInsightGeneration() async {
    final logCount = await context.read<LogBloc>().getLogCount();
    
    // If user has 3+ logs but no insight, generate or show CTA
    if (logCount >= 3) {
      final hasInsight = await context.read<InsightBloc>().checkIfInsightExists();
      
      if (!hasInsight) {
        // Trigger generation with timeout
        try {
          await context.read<InsightBloc>().generateInsight().timeout(
            Duration(seconds: 30),
            onTimeout: () {
              setState(() => _generationFailed = true);
              throw TimeoutException('Insight generation timed out');
            },
          );
        } on Exception catch (e) {
          print('Insight generation error: $e');
          setState(() => _generationFailed = true);
        }
      }
    }
  }

  void _retryGeneration() async {
    setState(() => _isRetrying = true);
    try {
      await context.read<InsightBloc>().generateInsight();
      setState(() {
        _generationFailed = false;
        _isRetrying = false;
      });
    } on Exception catch (e) {
      setState(() => _isRetrying = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to generate insight: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<LogBloc, LogState>(
      builder: (context, logState) {
        if (logState is LogLoadingState) {
          return _buildLoadingShimmer();
        }

        final logCount = logState.logs.length;

        if (logCount < 3) {
          return _buildComingSoonPlaceholder(logsNeeded: 3 - logCount);
        }

        return BlocBuilder<InsightBloc, InsightState>(
          builder: (context, insightState) {
            if (insightState is InsightLoadingState && !_generationFailed) {
              // Show loading shimmer with timeout handling
              return _buildLoadingShimmerWithTimeout();
            }

            if (_generationFailed) {
              // Show error state with retry
              return _buildErrorState();
            }

            if (insightState is InsightLoadedState) {
              return _buildInsightCard(insightState.insight);
            }

            if (insightState is InsightEmptyState) {
              // Show generate button
              return _buildGenerateButton();
            }

            return SizedBox.shrink();
          },
        );
      },
    );
  }

  Widget _buildLoadingShimmerWithTimeout() {
    return FutureBuilder<void>(
      future: Future.delayed(Duration(seconds: 30), () {
        if (mounted && !_generationFailed) {
          setState(() => _generationFailed = true);
        }
      }),
      builder: (context, snapshot) {
        if (_generationFailed) {
          return _buildErrorState();
        }
        return _buildLoadingShimmer();
      },
    );
  }

  Widget _buildErrorState() {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.red.shade300),
        borderRadius: BorderRadius.circular(12),
        color: Colors.red.shade50,
      ),
      child: Column(
        children: [
          Icon(Icons.error_outline, color: Colors.red, size: 32),
          SizedBox(height: 12),
          Text(
            'Unable to generate insight',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          SizedBox(height: 8),
          Text(
            'The insight generation timed out. Please try again.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.red.shade600),
          ),
          SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: _isRetrying ? null : _retryGeneration,
            icon: Icon(Icons.refresh),
            label: Text(_isRetrying ? 'Retrying...' : 'Retry'),
          ),
        ],
      ),
    );
  }

  Widget _buildGenerateButton() {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.blue.shade300),
        borderRadius: BorderRadius.circular(12),
        color: Colors.blue.shade50,
      ),
      child: Column(
        children: [
          Icon(Icons.lightbulb_outline, color: Colors.blue, size: 32),
          SizedBox(height: 12),
          Text(
            'Generate Your First Insight',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          SizedBox(height: 8),
          Text(
            'You have enough mood logs. Get personalized insights about your emotional patterns.',
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 16),
          ElevatedButton(
            onPressed: _retryGeneration,
            child: Text('Generate Insight'),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingShimmer() {
    return Shimmer.fromColors(
      baseColor: Colors.grey[300]!,
      highlightColor: Colors.grey[100]!,
      child: Container(
        height: 200,
        decoration: BoxDecoration(
          color: Colors.grey[300],
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }

  Widget _buildInsightCard(Insight insight) {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Your AI Insight',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
            SizedBox(height: 12),
            Text(insight.content),
          ],
        ),
      ),
    );
  }

  Widget _buildComingSoonPlaceholder({required int logsNeeded}) {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Icon(Icons.hourglass_empty, color: Colors.grey, size: 32),
          SizedBox(height: 12),
          Text(
            'AI Insights Coming Soon',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          SizedBox(height: 8),
          Text(
            'Add $logsNeeded more ${logsNeeded == 1 ? 'mood log' : 'mood logs'} to unlock insights',
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
```

### Layer 3: Update generate-insight Edge Function

Ensure the function is robust and returns proper errors:

```typescript
// supabase/functions/generate-insight/index.ts
import { createLogger, extractTraceId } from '../_shared/logger.ts';

const logger = createLogger('generate-insight');

export async function generateInsight(req: Request): Promise<Response> {
  const traceId = extractTraceId(Object.fromEntries(req.headers));
  
  try {
    const { userId } = await req.json();
    
    logger.info('Generating insight', { userId }, traceId);
    
    // ... generate insight logic ...
    
    return new Response(
      JSON.stringify({ success: true, traceId }),
      { status: 200, headers: { 'X-Trace-ID': traceId } }
    );
  } catch (error) {
    logger.error('Failed to generate insight', error, { userId }, traceId);
    return new Response(
      JSON.stringify({ error: 'Generation failed', traceId }),
      { status: 500, headers: { 'X-Trace-ID': traceId } }
    );
  }
}
```

## Test Coverage

```dart
// test/features/ai/insight_generation_test.dart
void main() {
  group('AI Insight Generation', () {
    test('generates insight when user crosses 3-log threshold', () async {
      // Create user with 2 logs
      final user = await createTestUser();
      await createLogEntry(user.id);
      await createLogEntry(user.id);
      
      // Verify no insight exists
      final initialInsight = await fetchInsight(user.id);
      expect(initialInsight, isNull);
      
      // Add 3rd log
      await createLogEntry(user.id);
      
      // Wait for generation
      await Future.delayed(Duration(seconds: 5));
      
      // Verify insight was generated
      final generatedInsight = await fetchInsight(user.id);
      expect(generatedInsight, isNotNull);
    });

    test('shows error and retry button if generation times out', () async {
      // Implement timeout simulation and verify UI shows error state
    });

    test('recovery works after retry button clicked', () async {
      // Simulate failed generation, then successful retry
    });
  });
}
```

## Deployment Checklist

- [ ] Deploy migration with Postgres trigger
- [ ] Update generate-insight function
- [ ] Update Flutter AI insight section UI
- [ ] Add timeout/error handling
- [ ] Add test coverage
- [ ] Test with real data (3+ mood logs)
- [ ] Monitor logs for generation failures
