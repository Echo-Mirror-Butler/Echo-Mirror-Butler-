import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/themes/app_theme.dart';
import '../../../../core/widgets/shimmer_loading.dart';
import '../../../../core/utils/date_formatter.dart';
import '../../../../core/utils/error_handler.dart';
import '../../../auth/viewmodel/providers/auth_provider.dart';
import '../../../auth/view/widgets/custom_button.dart';
import '../../../ai/viewmodel/providers/ai_provider.dart';
import '../../data/models/log_entry_model.dart';
import '../../viewmodel/providers/logging_provider.dart';
import '../widgets/voice_input_button.dart';
import '../../../global_mirror/viewmodel/providers/global_mirror_provider.dart';

/// Screen for creating a new log entry
class CreateEntryScreen extends ConsumerStatefulWidget {
  const CreateEntryScreen({super.key});

  @override
  ConsumerState<CreateEntryScreen> createState() => _CreateEntryScreenState();
}

class _CreateEntryScreenState extends ConsumerState<CreateEntryScreen> {
  final _formKey = GlobalKey<FormState>();
  final _notesController = TextEditingController();
  final _habitController = TextEditingController();

  DateTime _selectedDate = DateTime.now();
  int? _selectedMood;
  final List<String> _selectedHabits = [];
  bool _isSubmitting = false;
  bool _isListening = false;
  String _voiceTranscription = '';
  bool _shareAnonymously = false;

  @override
  void dispose() {
    _notesController.dispose();
    _habitController.dispose();
    super.dispose();
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: AppTheme.primaryColor,
              onPrimary: Colors.white,
              surface: Theme.of(context).colorScheme.surface,
              onSurface: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  void _addHabit() {
    final habit = _habitController.text.trim();
    if (habit.isNotEmpty && !_selectedHabits.contains(habit)) {
      setState(() {
        _selectedHabits.add(habit);
        _habitController.clear();
      });
    }
  }

  void _removeHabit(String habit) {
    setState(() {
      _selectedHabits.remove(habit);
    });
  }

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final authState = ref.read(authProvider);
    if (!authState.isAuthenticated || authState.user == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please log in to create entries'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      // Create log entry model
      // Use UTC for date to avoid timezone issues - dates are date-only values
      final entry = LogEntryModel(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        userId: authState.user!.id,
        date: DateTime.utc(
          _selectedDate.year,
          _selectedDate.month,
          _selectedDate.day,
        ),
        mood: _selectedMood,
        habits: _selectedHabits,
        notes: _notesController.text.trim().isEmpty
            ? null
            : _notesController.text.trim(),
        createdAt: DateTime.now(),
      );

      final success = await ref
          .read(loggingProvider.notifier)
          .createLogEntry(entry);

      if (mounted) {
        if (success) {
          ErrorHandler.showSuccess(context, 'Entry created successfully!');

          // Share mood anonymously if opted in
          if (_shareAnonymously && _selectedMood != null) {
            debugPrint(
              '[CreateEntryScreen] Sharing mood anonymously: mood=$_selectedMood, shareAnonymously=$_shareAnonymously',
            );
            final sentiment = _getMoodSentiment(_selectedMood!);
            debugPrint(
              '[CreateEntryScreen] Mapped mood $_selectedMood to sentiment: $sentiment',
            );
            final shareResult = await ref
                .read(globalMirrorProvider.notifier)
                .shareMood(sentiment);
            debugPrint('[CreateEntryScreen] Share mood result: $shareResult');
            if (!shareResult && mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: const Text(
                    'Failed to share mood. Check location permissions.',
                  ),
                  backgroundColor: Colors.orange,
                  duration: const Duration(seconds: 3),
                ),
              );
            }
          } else {
            debugPrint(
              '[CreateEntryScreen] Not sharing mood: shareAnonymously=$_shareAnonymously, selectedMood=$_selectedMood',
            );
          }

          // Trigger AI insight generation if we have at least 3 logs
          final loggingState = ref.read(loggingProvider);
          final allLogs = loggingState.value ?? [];
          if (allLogs.length >= 3) {
            // Get recent logs (last 7-14 days)
            final now = DateTime.now();
            final recentLogs =
                allLogs
                    .where(
                      (log) => log.date.isAfter(
                        now.subtract(const Duration(days: 14)),
                      ),
                    )
                    .toList()
                  ..sort((a, b) => b.date.compareTo(a.date));

            if (recentLogs.length >= 3) {
              // Trigger insight generation (don't await - let it run in background)
              ref.read(aiInsightProvider.notifier).generateInsight(recentLogs);
            }
          }

          if (mounted) {
            context.pop();
          }
        } else {
          // Get error message from provider state
          final loggingState = ref.read(loggingProvider);
          final errorMessage = loggingState.hasError
              ? ErrorHandler.getErrorMessage(loggingState.error!)
              : 'Failed to create entry. Please try again.';

          ErrorHandler.showError(context, errorMessage);
        }
      }
    } catch (e) {
      if (mounted) {
        ErrorHandler.showError(context, ErrorHandler.getErrorMessage(e));
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('New Entry')),
      body: Stack(
        children: [
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Header icon
                    Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            AppTheme.primaryColor,
                            AppTheme.secondaryColor,
                          ],
                        ),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: AppTheme.primaryColor.withValues(alpha: 0.3),
                            blurRadius: 20,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: const Icon(
                        FontAwesomeIcons.pen,
                        size: 36,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Date picker section
                    Card(
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: InkWell(
                        onTap: () => _selectDate(context),
                        borderRadius: BorderRadius.circular(16),
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: AppTheme.primaryColor.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Icon(
                                  FontAwesomeIcons.calendar,
                                  color: AppTheme.primaryColor,
                                  size: 20,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Date',
                                      style: theme.textTheme.labelMedium
                                          ?.copyWith(
                                            color: theme.colorScheme.onSurface
                                                .withValues(alpha: 0.6),
                                          ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      DateFormatter.formatDateLong(
                                        _selectedDate,
                                      ),
                                      style: theme.textTheme.titleMedium
                                          ?.copyWith(
                                            fontWeight: FontWeight.w600,
                                          ),
                                    ),
                                  ],
                                ),
                              ),
                              Icon(
                                FontAwesomeIcons.chevronRight,
                                size: 16,
                                color: theme.colorScheme.onSurface.withValues(alpha: 
                                  0.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Mood selection section
                    Text(
                      'How are you feeling?',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Card(
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: List.generate(5, (index) {
                            final moodValue = index + 1;
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
                                        : theme.colorScheme.outline.withValues(alpha: 
                                            0.3,
                                          ),
                                    width: isSelected ? 2 : 1,
                                  ),
                                ),
                                child: Icon(
                                  _getMoodIcon(moodValue),
                                  size: 28,
                                  color: isSelected
                                      ? AppTheme.accentColor
                                      : theme.colorScheme.onSurface.withValues(alpha: 
                                          0.6,
                                        ),
                                ),
                              ),
                            );
                          }),
                        ),
                      ),
                    ),
                    if (_selectedMood != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        'Mood: $_selectedMood/5',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: AppTheme.accentColor,
                          fontWeight: FontWeight.w600,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                    const SizedBox(height: 24),

                    // Habits section
                    Text(
                      'Habits',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _habitController,
                            decoration: InputDecoration(
                              labelText: 'Add a habit',
                              hintText: 'e.g., Exercise, Meditation',
                              prefixIcon: const Icon(
                                FontAwesomeIcons.plus,
                                size: 18,
                              ),
                            ),
                            textInputAction: TextInputAction.done,
                            onFieldSubmitted: (_) => _addHabit(),
                          ),
                        ),
                        const SizedBox(width: 12),
                        ElevatedButton(
                          onPressed: _addHabit,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.primaryColor,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.all(16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Icon(FontAwesomeIcons.plus, size: 18),
                        ),
                      ],
                    ),
                    if (_selectedHabits.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: _selectedHabits.map((habit) {
                          return Chip(
                            label: Text(habit),
                            onDeleted: () => _removeHabit(habit),
                            deleteIcon: const Icon(
                              FontAwesomeIcons.xmark,
                              size: 16,
                            ),
                            backgroundColor: AppTheme.primaryColor.withValues(alpha: 
                              0.1,
                            ),
                            labelStyle: TextStyle(
                              color: AppTheme.primaryColor,
                              fontWeight: FontWeight.w600,
                            ),
                          );
                        }).toList(),
                      ),
                    ],
                    const SizedBox(height: 24),

                    // Notes section
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Notes (Optional)',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        // Voice input hint
                        if (!_isListening)
                          TextButton.icon(
                            onPressed: () {
                              // Voice button will handle this
                            },
                            icon: const Icon(
                              FontAwesomeIcons.microphone,
                              size: 16,
                            ),
                            label: const Text('Voice'),
                            style: TextButton.styleFrom(
                              foregroundColor: AppTheme.primaryColor,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _notesController,
                      maxLines: 5,
                      decoration: InputDecoration(
                        hintText:
                            'Write about your day, thoughts, or anything else...',
                        prefixIcon: const Icon(
                          FontAwesomeIcons.noteSticky,
                          size: 18,
                        ),
                        suffixIcon: _isListening
                            ? const Padding(
                                padding: EdgeInsets.all(12),
                                child: ShimmerLoading(width: 20, height: 20),
                              )
                            : null,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Anonymous sharing opt-in - Made more prominent
                    if (_selectedMood != null)
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: AppTheme.primaryColor.withValues(alpha: 0.5),
                            width: 2,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: AppTheme.primaryColor.withValues(alpha: 0.1),
                              blurRadius: 8,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            Checkbox(
                              value: _shareAnonymously,
                              onChanged: (value) {
                                setState(() {
                                  _shareAnonymously = value ?? false;
                                });
                              },
                              activeColor: AppTheme.primaryColor,
                            ),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Icon(
                                        FontAwesomeIcons.globe,
                                        size: 16,
                                        color: AppTheme.primaryColor,
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          'Share mood on Global Mirror',
                                          style: theme.textTheme.bodyLarge
                                              ?.copyWith(
                                                fontWeight: FontWeight.w700,
                                                color: AppTheme.primaryColor,
                                              ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    'Help the global community by sharing your mood anonymously. Your location is anonymized (~11km) and data expires in 24 hours.',
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: theme.colorScheme.onSurface
                                          .withValues(alpha: 0.7),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              icon: const Icon(
                                FontAwesomeIcons.circleInfo,
                                size: 18,
                              ),
                              color: AppTheme.primaryColor,
                              onPressed: () {
                                showDialog(
                                  context: context,
                                  builder: (context) => AlertDialog(
                                    title: const Text('Anonymous Sharing'),
                                    content: const Text(
                                      'When enabled, your mood will be shared anonymously on the Global Mirror map. '
                                      'Your location is anonymized to ~11km precision and no personal information is stored. '
                                      'All shared data expires after 24 hours.',
                                    ),
                                    actions: [
                                      TextButton(
                                        onPressed: () => Navigator.pop(context),
                                        child: const Text('Got It'),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                    const SizedBox(height: 32),

                    // Submit button
                    CustomButton(
                      onPressed: _isSubmitting ? null : _handleSubmit,
                      text: 'Create Entry',
                      isLoading: _isSubmitting,
                      icon: FontAwesomeIcons.check,
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
          ),
          // Voice input overlay
          if (_isListening)
            VoiceInputOverlay(
              isListening: _isListening,
              transcription: _voiceTranscription,
              onStop: () {
                setState(() {
                  _isListening = false;
                });
              },
            ),
          // Floating voice input button
          Positioned(
            bottom: 24,
            right: 24,
            child: VoiceInputButton(
              notesController: _notesController,
              onListeningStateChanged: (isListening) {
                setState(() {
                  _isListening = isListening;
                });
              },
              onTranscriptionComplete: (transcription) {
                setState(() {
                  _voiceTranscription = transcription;
                  _isListening = false;
                });
                // Append to existing notes if any
                if (_notesController.text.isNotEmpty &&
                    transcription.isNotEmpty) {
                  _notesController.text =
                      '${_notesController.text} $transcription';
                } else if (transcription.isNotEmpty) {
                  _notesController.text = transcription;
                }
              },
            ),
          ),
        ],
      ),
    );
  }

  IconData _getMoodIcon(int mood) {
    switch (mood) {
      case 1:
        return FontAwesomeIcons.faceFrown;
      case 2:
        return FontAwesomeIcons.faceMeh;
      case 3:
        return FontAwesomeIcons.faceSmile;
      case 4:
        return FontAwesomeIcons.faceSmileBeam;
      case 5:
        return FontAwesomeIcons.faceGrinStars;
      default:
        return FontAwesomeIcons.faceSmile;
    }
  }

  String _getMoodSentiment(int mood) {
    switch (mood) {
      case 1:
        return 'negative';
      case 2:
        return 'neutral';
      case 3:
        return 'positive';
      case 4:
        return 'excited';
      case 5:
        return 'excited';
      default:
        return 'neutral';
    }
  }
}
