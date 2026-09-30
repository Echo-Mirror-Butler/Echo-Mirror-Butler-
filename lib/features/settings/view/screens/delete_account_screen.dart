import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/services/toast_service.dart';
import '../../../../core/utils/date_formatter.dart';
import '../../../auth/viewmodel/providers/auth_provider.dart';
import '../../data/repositories/account_deletion_repository.dart';

/// Grace period before data is hard-deleted, in days.
///
/// Mirrors GRACE_PERIOD_DAYS in supabase/functions/delete-account/index.ts.
const int _kGracePeriodDays = 14;

/// "Delete my account" screen (Issue #759).
///
/// Requires the user to type a confirmation phrase, explains the 14-day
/// grace period in plain language, then calls the `delete-account` edge
/// function. On success the user is signed out locally (clearing caches)
/// and shown a success state explaining recovery.
class DeleteAccountScreen extends ConsumerStatefulWidget {
  const DeleteAccountScreen({super.key});

  @override
  ConsumerState<DeleteAccountScreen> createState() =>
      _DeleteAccountScreenState();
}

class _DeleteAccountScreenState extends ConsumerState<DeleteAccountScreen> {
  final _confirmationController = TextEditingController();
  bool _isSubmitting = false;
  DateTime? _gracePeriodEndsAt;

  @override
  void dispose() {
    _confirmationController.dispose();
    super.dispose();
  }

  bool get _confirmationMatches =>
      _confirmationController.text.trim().toUpperCase() ==
      AccountDeletionRepository.confirmationPhrase;

  Future<void> _submit() async {
    final userId = ref.read(authProvider).user?.id;
    if (userId == null || userId.isEmpty) {
      ToastService.errorMessage(
        context,
        'You need to be signed in to do that.',
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final result = await ref
          .read(accountDeletionRepositoryProvider)
          .requestDeletion(userId: userId);

      if (!mounted) return;
      setState(() {
        _isSubmitting = false;
        _gracePeriodEndsAt = result.gracePeriodEndsAt;
      });

      // Show the success state while still signed in — signing out first
      // would trigger the auth redirect and tear down this screen before
      // the dialog could render.
      await _showSuccessDialog();

      // User acknowledged; now sign out locally (clears caches via
      // AuthNotifier). The router redirect lands them on the login screen.
      await ref.read(authProvider.notifier).signOut();
    } on AccountDeletionException catch (e) {
      if (!mounted) return;
      setState(() => _isSubmitting = false);
      // Show a friendly, non-raw message mapped from the failure kind.
      ToastService.errorMessage(
        context,
        friendlyDeletionErrorMessage(e.failure),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _isSubmitting = false);
      ToastService.errorMessage(
        context,
        'Something went wrong. Please try again.',
      );
    }
  }

  Future<void> _showSuccessDialog() {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        final theme = Theme.of(dialogContext);
        final graceEndsAt = _gracePeriodEndsAt;
        return AlertDialog(
          title: Row(
            children: [
              Icon(
                FontAwesomeIcons.circleCheck.data,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(width: 8),
              const Expanded(child: Text('Account scheduled for deletion')),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                graceEndsAt != null
                    ? 'Your account will be permanently deleted on '
                        '${DateFormatter.formatDate(graceEndsAt)}.'
                    : 'Your account will be permanently deleted in '
                        '$_kGracePeriodDays days.',
              ),
              const SizedBox(height: 12),
              const Text(
                'Changed your mind? Simply sign back in within the next 14 '
                'days to recover your account and all your data.',
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final user = ref.watch(authProvider).user;
    final email = user?.email;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Delete my account'),
        elevation: 0,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Icon(
                FontAwesomeIcons.triangleExclamation.data,
                size: 56,
                color: theme.colorScheme.error,
              ),
              const SizedBox(height: 24),
              Text(
                'This will permanently delete your EchoMirror account',
                style: theme.textTheme.headlineSmall,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              _buildExplanationCard(theme, email),
              const SizedBox(height: 24),
              _buildGracePeriodCard(theme),
              const SizedBox(height: 24),
              Text(
                'Type DELETE MY ACCOUNT to confirm',
                style: theme.textTheme.titleMedium,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _confirmationController,
                enabled: !_isSubmitting,
                decoration: const InputDecoration(
                  hintText: 'Type the confirmation phrase',
                  border: OutlineInputBorder(),
                ),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 24),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: theme.colorScheme.error,
                  foregroundColor: theme.colorScheme.onError,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                onPressed:
                    _isSubmitting || !_confirmationMatches ? null : _submit,
                child: _isSubmitting
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Permanently delete my account'),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: _isSubmitting
                    ? null
                    : () {
                        // Fall back to /settings when there is no route to
                        // pop (e.g. the user deep-linked straight here).
                        if (context.canPop()) {
                          context.pop();
                        } else {
                          context.go('/settings');
                        }
                      },
                child: const Text('Cancel'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildExplanationCard(ThemeData theme, String? email) {
    return Card(
      elevation: 0,
      color: theme.colorScheme.error.withValues(alpha: 0.05),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: theme.colorScheme.error.withValues(alpha: 0.3),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildBulletPoint(
              theme,
              'Your account${email != null && email.isNotEmpty ? ' ($email)' : ''} '
              'and all your data will be scheduled for deletion.',
            ),
            const SizedBox(height: 8),
            _buildBulletPoint(
              theme,
              'You will be signed out of EchoMirror on this device.',
            ),
            const SizedBox(height: 8),
            _buildBulletPoint(
              theme,
              'Your profile, moods, habits, ECHO balance, and gifts will be '
              'removed.',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGracePeriodCard(ThemeData theme) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: theme.colorScheme.outline.withValues(alpha: 0.2),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  FontAwesomeIcons.clockRotateLeft.data,
                  size: 18,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text('Changed your mind?', style: theme.textTheme.titleMedium),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Deleting starts a $_kGracePeriodDays-day waiting period. Your '
              'data is hidden right away, but not permanently removed until '
              'the period ends. If you sign back in before then, you can '
              'recover your account and nothing will be lost. After '
              '$_kGracePeriodDays days, deletion is permanent and cannot be '
              'undone.',
              style: theme.textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBulletPoint(ThemeData theme, String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Icon(
            FontAwesomeIcons.circleDot.data,
            size: 8,
            color: theme.colorScheme.error,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(child: Text(text, style: theme.textTheme.bodyMedium)),
      ],
    );
  }
}
