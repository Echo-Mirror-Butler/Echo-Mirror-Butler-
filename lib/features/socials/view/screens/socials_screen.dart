import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:animate_do/animate_do.dart';
import '../../../../core/themes/app_theme.dart';
import '../../viewmodel/providers/socials_provider.dart';
import '../widgets/stories_bar.dart';
import '../widgets/start_session_button.dart';
import 'video_call_screen.dart';
import 'story_viewer_screen.dart';
import 'create_story_screen.dart';

/// Socials screen with active sessions and video call functionality
class SocialsScreen extends ConsumerStatefulWidget {
  const SocialsScreen({super.key});

  @override
  ConsumerState<SocialsScreen> createState() => _SocialsScreenState();
}

class _SocialsScreenState extends ConsumerState<SocialsScreen>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Load active sessions when screen opens
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(socialsProvider.notifier).loadActiveSessions();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    // Refresh when app comes to foreground
    if (state == AppLifecycleState.resumed) {
      ref.read(socialsProvider.notifier).loadActiveSessions();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final socialsState = ref.watch(socialsProvider);

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: theme.colorScheme.surface,
        title: Text(
          'Socials',
          style: GoogleFonts.poppins(
            fontSize: 24,
            fontWeight: FontWeight.w700,
            color: theme.colorScheme.onSurface,
          ),
        ),
        actions: [
          IconButton(
            icon: const FaIcon(FontAwesomeIcons.bell),
            onPressed: () {
              // TODO: Show notifications
            },
            color: theme.colorScheme.onSurface,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await ref.read(socialsProvider.notifier).loadActiveSessions();
        },
        child: CustomScrollView(
          slivers: [
            // Stories and Live Sessions Bar
            SliverToBoxAdapter(
              child: StoriesBar(
                liveSessions: socialsState.activeSessions,
                stories: socialsState.stories,
                onSessionTap: (session) async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => VideoCallScreen(
                        sessionId: session.id,
                        isHost: false,
                        sessionTitle: session.title,
                        hostName: session.hostName,
                      ),
                    ),
                  );
                  // Refresh sessions when returning from video call
                  ref.read(socialsProvider.notifier).loadActiveSessions();
                },
                onStoryTap: (story) {
                  // Filter stories to show only this user's stories (like Instagram)
                  final userStories =
                      socialsState.stories
                          .where((s) => s.userId == story.userId)
                          .toList()
                        ..sort(
                          (a, b) => b.createdAt.compareTo(a.createdAt),
                        ); // Most recent first

                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => StoryViewerScreen(
                        stories: userStories,
                        initialIndex:
                            0, // Always start at the first (most recent) story
                      ),
                    ),
                  ).then((_) {
                    // Refresh stories after viewing
                    ref.read(socialsProvider.notifier).loadStories();
                  });
                },
                onAddStory: () async {
                  final result = await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const CreateStoryScreen(),
                    ),
                  );
                  if (result == true) {
                    // Refresh stories after creating
                    ref.read(socialsProvider.notifier).loadStories();
                  }
                },
              ),
            ),

            // Start Session Button (Circle with Plus)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Center(
                  child: StartSessionButton(
                    onTap: () => _showStartSessionDialog(context),
                  ),
                ),
              ),
            ),

            // Recent Sessions or Empty State
            SliverToBoxAdapter(
              child: socialsState.activeSessions.isEmpty
                  ? _buildEmptyState(theme)
                  : _buildRecentSessionsList(socialsState, theme),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          FadeInUp(
            delay: const Duration(milliseconds: 200),
            child: Container(
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: FaIcon(
                FontAwesomeIcons.video,
                size: 64,
                color: AppTheme.primaryColor,
              ),
            ),
          ),
          const SizedBox(height: 24),
          FadeInUp(
            delay: const Duration(milliseconds: 300),
            child: Text(
              'No Active Sessions',
              style: GoogleFonts.poppins(
                fontSize: 24,
                fontWeight: FontWeight.w700,
                color: theme.colorScheme.onSurface,
              ),
            ),
          ),
          const SizedBox(height: 8),
          FadeInUp(
            delay: const Duration(milliseconds: 400),
            child: Text(
              'Start a session to connect with others',
              style: GoogleFonts.poppins(
                fontSize: 16,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecentSessionsList(dynamic state, ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Active Sessions',
            style: GoogleFonts.poppins(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: theme.colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 16),
          ...state.activeSessions.map((session) {
            return FadeInUp(child: _buildSessionCard(session, theme));
          }).toList(),
        ],
      ),
    );
  }

  Widget _buildSessionCard(dynamic session, ThemeData theme) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => VideoCallScreen(
                sessionId: session.id,
                isHost: false,
                sessionTitle: session.title,
                hostName: session.hostName,
              ),
            ),
          );
        },
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // Avatar
              CircleAvatar(
                radius: 28,
                backgroundColor: AppTheme.primaryColor.withValues(alpha: 0.1),
                backgroundImage: session.hostAvatarUrl != null
                    ? NetworkImage(session.hostAvatarUrl!)
                    : null,
                child: session.hostAvatarUrl == null
                    ? FaIcon(
                        FontAwesomeIcons.user,
                        color: AppTheme.primaryColor,
                        size: 20,
                      )
                    : null,
              ),
              const SizedBox(width: 16),
              // Session Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      session.title,
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        FaIcon(
                          FontAwesomeIcons.user,
                          size: 12,
                          color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${session.participantCount} participants',
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              // Join Button
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const FaIcon(
                      FontAwesomeIcons.video,
                      color: Colors.white,
                      size: 14,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Join',
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showStartSessionDialog(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (bottomSheetContext) => _StartSessionBottomSheet(
        onCreateSession: (title, isVoiceOnly) async {
          Navigator.pop(bottomSheetContext);
          final session = await ref
              .read(socialsProvider.notifier)
              .createSession(title: title, isVoiceOnly: isVoiceOnly);
          if (session != null && mounted) {
            // ignore: use_build_context_synchronously
            Navigator.push(
              context, // Use outer context, not bottom sheet context
              MaterialPageRoute(
                builder: (context) => VideoCallScreen(
                  sessionId: session.id,
                  isHost: true,
                  sessionTitle: session.title,
                  hostName: session.hostName,
                ),
              ),
            );
          }
        },
      ),
    );
  }
}

/// Bottom sheet for starting a new session
class _StartSessionBottomSheet extends StatefulWidget {
  final Function(String title, bool isVoiceOnly) onCreateSession;

  const _StartSessionBottomSheet({required this.onCreateSession});

  @override
  State<_StartSessionBottomSheet> createState() =>
      _StartSessionBottomSheetState();
}

class _StartSessionBottomSheetState extends State<_StartSessionBottomSheet> {
  final _titleController = TextEditingController();
  bool _isVoiceOnly = false;
  bool _scheduleForLater = false;
  DateTime? _scheduledTime;

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  Future<void> _selectDateTime() async {
    final date = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(hours: 1)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 30)),
    );

    if (date != null && mounted) {
      final time = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.now(),
      );

      if (time != null && mounted) {
        setState(() {
          _scheduledTime = DateTime(
            date.year,
            date.month,
            date.day,
            time.hour,
            time.minute,
          );
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        left: 24,
        right: 24,
        top: 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Handle bar
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Start New Session',
            style: GoogleFonts.poppins(
              fontSize: 24,
              fontWeight: FontWeight.w700,
              color: theme.colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 24),
          TextField(
            controller: _titleController,
            decoration: InputDecoration(
              labelText: 'Session Title',
              hintText: 'e.g., Morning Check-in, Study Group',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          const SizedBox(height: 16),
          // Voice/Video Toggle
          Row(
            children: [
              Expanded(
                child: InkWell(
                  onTap: () => setState(() => _isVoiceOnly = false),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: !_isVoiceOnly
                          ? AppTheme.primaryColor.withValues(alpha: 0.1)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: !_isVoiceOnly
                            ? AppTheme.primaryColor
                            : theme.colorScheme.onSurface.withValues(alpha: 0.2),
                      ),
                    ),
                    child: Column(
                      children: [
                        FaIcon(
                          FontAwesomeIcons.video,
                          color: !_isVoiceOnly
                              ? AppTheme.primaryColor
                              : theme.colorScheme.onSurface.withValues(alpha: 0.6),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Video Call',
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            fontWeight: !_isVoiceOnly
                                ? FontWeight.w600
                                : FontWeight.normal,
                            color: !_isVoiceOnly
                                ? AppTheme.primaryColor
                                : theme.colorScheme.onSurface.withValues(alpha: 0.6),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: InkWell(
                  onTap: () => setState(() => _isVoiceOnly = true),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: _isVoiceOnly
                          ? AppTheme.primaryColor.withValues(alpha: 0.1)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: _isVoiceOnly
                            ? AppTheme.primaryColor
                            : theme.colorScheme.onSurface.withValues(alpha: 0.2),
                      ),
                    ),
                    child: Column(
                      children: [
                        FaIcon(
                          FontAwesomeIcons.phone,
                          color: _isVoiceOnly
                              ? AppTheme.primaryColor
                              : theme.colorScheme.onSurface.withValues(alpha: 0.6),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Voice Only',
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            fontWeight: _isVoiceOnly
                                ? FontWeight.w600
                                : FontWeight.normal,
                            color: _isVoiceOnly
                                ? AppTheme.primaryColor
                                : theme.colorScheme.onSurface.withValues(alpha: 0.6),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Schedule for later toggle
          CheckboxListTile(
            title: Text(
              'Schedule for later',
              style: GoogleFonts.poppins(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: theme.colorScheme.onSurface,
              ),
            ),
            value: _scheduleForLater,
            onChanged: (value) {
              setState(() {
                _scheduleForLater = value ?? false;
                if (_scheduleForLater && _scheduledTime == null) {
                  _selectDateTime();
                }
              });
            },
            activeColor: AppTheme.primaryColor,
            contentPadding: EdgeInsets.zero,
          ),
          if (_scheduleForLater && _scheduledTime != null) ...[
            const SizedBox(height: 8),
            InkWell(
              onTap: _selectDateTime,
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.primaryColor),
                ),
                child: Row(
                  children: [
                    const FaIcon(
                      FontAwesomeIcons.clock,
                      color: AppTheme.primaryColor,
                      size: 16,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      '${_scheduledTime!.day}/${_scheduledTime!.month}/${_scheduledTime!.year} at ${_scheduledTime!.hour.toString().padLeft(2, '0')}:${_scheduledTime!.minute.toString().padLeft(2, '0')}',
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.primaryColor,
                      ),
                    ),
                    const Spacer(),
                    const FaIcon(
                      FontAwesomeIcons.penToSquare,
                      color: AppTheme.primaryColor,
                      size: 14,
                    ),
                  ],
                ),
              ),
            ),
          ],
          const SizedBox(height: 24),
          // Start Button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () async {
                if (_titleController.text.trim().isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Please enter a session title'),
                      backgroundColor: AppTheme.errorColor,
                    ),
                  );
                  return;
                }

                if (_scheduleForLater && _scheduledTime == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Please select a date and time'),
                      backgroundColor: AppTheme.errorColor,
                    ),
                  );
                  return;
                }

                if (_scheduleForLater) {
                  // Handle scheduled session
                  Navigator.pop(context);
                  // TODO: Call schedule session endpoint
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        'Session scheduled for ${_scheduledTime!.day}/${_scheduledTime!.month} at ${_scheduledTime!.hour}:${_scheduledTime!.minute.toString().padLeft(2, '0')}',
                      ),
                      backgroundColor: AppTheme.successColor,
                    ),
                  );
                } else {
                  // Start session immediately
                  widget.onCreateSession(
                    _titleController.text.trim(),
                    _isVoiceOnly,
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                _scheduleForLater ? 'Schedule Session' : 'Start Session',
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}
