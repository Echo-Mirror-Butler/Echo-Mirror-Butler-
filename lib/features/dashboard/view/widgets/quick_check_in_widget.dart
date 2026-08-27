import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/themes/app_theme.dart';
import '../../../auth/viewmodel/providers/auth_provider.dart';
import '../../../logging/data/models/log_entry_model.dart';
import '../../../logging/data/models/quick_check_in_data.dart';
import '../../../logging/viewmodel/providers/logging_provider.dart';

enum _WidgetState { idle, submitting, confirming }

/// A quick mood check-in card shown at the top of the dashboard
/// when the user has not yet logged today.
class QuickCheckInWidget extends ConsumerStatefulWidget {
  const QuickCheckInWidget({super.key});

  @override
  ConsumerState<QuickCheckInWidget> createState() =>
      _QuickCheckInWidgetState();
}

class _QuickCheckInWidgetState extends ConsumerState<QuickCheckInWidget> {
  int? _selectedMood;
  final TextEditingController _noteController = TextEditingController();
  _WidgetState _state = _WidgetState.idle;
  String? _errorMessage;

  static const Map<int, String> _moodEmojis = {
    1: '😞',
    2: '😕',
    3: '😐',
    4: '🙂',
    5: '😄',
  };

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  String? get _trimmedNote {
    final trimmed = _noteController.text.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  Future<void> _handleSubmit() async {
    if (_selectedMood == null || _state != _WidgetState.idle) return;

    setState(() {
      _state = _WidgetState.submitting;
      _errorMessage = null;
    });

    final auth = ref.read(authProvider);
    if (auth.user == null) {
      setState(() {
        _state = _WidgetState.idle;
        _errorMessage = 'Please log in first.';
      });
      return;
    }

    final now = DateTime.now();
    final entry = LogEntryModel(
      id: now.millisecondsSinceEpoch.toString(),
      userId: auth.user!.id,
      date: DateTime.utc(now.year, now.month, now.day),
      mood: _selectedMood,
      notes: _trimmedNote,
      habits: const [],
      createdAt: now,
    );

    final success =
        await ref.read(loggingProvider.notifier).createLogEntry(entry);

    if (!mounted) return;

    if (success) {
      setState(() {
        _state = _WidgetState.confirming;
      });
    } else {
      setState(() {
        _state = _WidgetState.idle;
        _errorMessage = 'Something went wrong. Please try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Card(
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'How are you feeling today?',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              if (_state == _WidgetState.confirming) ...[
                const SizedBox(height: 16),
                Center(
                  child: Text(
                    'Logged! +1 ECHO earned 🎉',
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: AppTheme.successColor,
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(height: 16),
              ] else ...[
                _buildMoodRow(theme),
                const SizedBox(height: 16),
                TextField(
                  controller: _noteController,
                  maxLength: 120,
                  maxLines: 1,
                  decoration: const InputDecoration(
                    labelText: 'One thing on your mind?',
                  ),
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed:
                      (_selectedMood == null || _state != _WidgetState.idle)
                          ? null
                          : _handleSubmit,
                  child: _state == _WidgetState.submitting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('Log it'),
                ),
                if (_errorMessage != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    _errorMessage!,
                    style: const TextStyle(
                      color: AppTheme.errorColor,
                      fontSize: 13,
                    ),
                  ),
                ],
                const SizedBox(height: 4),
                if (_state == _WidgetState.idle)
                  TextButton(
                    onPressed: () {
                      context.push(
                        '/logging/create',
                        extra: QuickCheckInData(
                          mood: _selectedMood,
                          note: _trimmedNote,
                        ),
                      );
                    },
                    child: const Text('Add more detail →'),
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMoodRow(ThemeData theme) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: _moodEmojis.entries.map((entry) {
        final moodValue = entry.key;
        final emoji = entry.value;
        final isSelected = _selectedMood == moodValue;

        return GestureDetector(
          onTap: () {
            setState(() {
              _selectedMood = isSelected ? null : moodValue;
            });
          },
          child: Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: isSelected
                  ? AppTheme.accentColor.withValues(alpha: 0.2)
                  : theme.colorScheme.surface,
              shape: BoxShape.circle,
              border: Border.all(
                color: isSelected
                    ? AppTheme.accentColor
                    : theme.colorScheme.outline.withValues(alpha: 0.3),
                width: isSelected ? 2.0 : 1.0,
              ),
            ),
            child: Center(
              child: Text(
                emoji,
                style: TextStyle(
                  fontSize: 26,
                  color: isSelected
                      ? AppTheme.accentColor
                      : theme.colorScheme.onSurface.withValues(alpha: 0.6),
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}
