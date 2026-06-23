import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/themes/app_theme.dart';
import '../../../../core/utils/error_handler.dart';
import '../../viewmodel/providers/auth_provider.dart';
import '../widgets/custom_button.dart';

/// Screen shown after signup — asks user to verify their email.
class VerifyEmailScreen extends ConsumerStatefulWidget {
  const VerifyEmailScreen({super.key, required this.email});

  final String email;

  @override
  ConsumerState<VerifyEmailScreen> createState() => _VerifyEmailScreenState();
}

class _VerifyEmailScreenState extends ConsumerState<VerifyEmailScreen> {
  static const _resendCooldown = 60;
  int _secondsLeft = 0;
  Timer? _timer;
  StreamSubscription<AuthState>? _authSub;

  @override
  void initState() {
    super.initState();
    _listenForConfirmation();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _authSub?.cancel();
    super.dispose();
  }

  void _listenForConfirmation() {
    _authSub = Supabase.instance.client.auth.onAuthStateChange.listen((data) {
      if (data.event == AuthChangeEvent.userUpdated ||
          data.event == AuthChangeEvent.signedIn) {
        final user = data.session?.user;
        if (user != null && user.emailConfirmedAt != null && mounted) {
          // Refresh auth state then navigate to dashboard
          ref.read(authProvider.notifier).checkAuthStatus().then((_) {
            if (mounted) context.go('/dashboard');
          });
        }
      }
    });
  }

  Future<void> _resend() async {
    if (_secondsLeft > 0) return;
    try {
      await Supabase.instance.client.auth.resend(
        type: OtpType.signup,
        email: widget.email,
      );
      if (mounted) {
        ErrorHandler.showSuccess(context, 'Confirmation email resent.');
        _startCountdown();
      }
    } catch (e) {
      if (mounted) {
        ErrorHandler.showError(context, 'Could not resend email. Try again.');
      }
    }
  }

  void _startCountdown() {
    setState(() => _secondsLeft = _resendCooldown);
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      setState(() {
        _secondsLeft--;
        if (_secondsLeft <= 0) t.cancel();
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final canResend = _secondsLeft <= 0;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/login'),
        ),
        title: const Text('Verify Email'),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Icon(
                  FontAwesomeIcons.envelopeCircleCheck.data,
                  size: 72,
                  color: AppTheme.primaryColor,
                ),
                const SizedBox(height: 24),
                Text(
                  'Check your inbox',
                  style: theme.textTheme.headlineMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                Text(
                  'We sent a confirmation link to\n${widget.email}\n\nClick the link to activate your account.',
                  style: theme.textTheme.bodyMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 40),
                CustomButton(
                  onPressed: canResend ? _resend : null,
                  text: canResend
                      ? 'Resend confirmation email'
                      : 'Resend in ${_secondsLeft}s',
                  icon: FontAwesomeIcons.rotate.data,
                ),
                const SizedBox(height: 16),
                TextButton(
                  onPressed: () => context.go('/login'),
                  child: Text(
                    'Back to Login',
                    style: theme.textTheme.bodyMedium,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
