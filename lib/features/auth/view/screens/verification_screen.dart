import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/themes/app_theme.dart';
import '../../../../core/utils/error_handler.dart';
import '../../viewmodel/providers/auth_provider.dart';
import '../widgets/custom_button.dart';
import '../widgets/custom_text_field.dart';

/// Verification screen for email verification code
class VerificationScreen extends ConsumerStatefulWidget {
  final String email;
  final String accountRequestId;
  final String password;
  final String? name;

  const VerificationScreen({
    super.key,
    required this.email,
    required this.accountRequestId,
    required this.password,
    this.name,
  });

  @override
  ConsumerState<VerificationScreen> createState() => _VerificationScreenState();
}

class _VerificationScreenState extends ConsumerState<VerificationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _codeController = TextEditingController();

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _handleVerification() async {
    if (_formKey.currentState!.validate()) {
      debugPrint(
        '[VerificationScreen] Attempt verification -> ${widget.email}',
      );
      final authNotifier = ref.read(authProvider.notifier);
      final success = await authNotifier.completeSignUp(
        accountRequestId: widget.accountRequestId,
        verificationCode: _codeController.text.trim(),
        password: widget.password,
      );

      if (mounted) {
        if (success) {
          ErrorHandler.showSuccess(context, 'Account verified successfully!');
          context.go('/dashboard');
          debugPrint('[VerificationScreen] Verification success');
        } else {
          final error = ref.read(authProvider).error;
          debugPrint('[VerificationScreen] Verification failed -> $error');
          ErrorHandler.showError(context, error ?? 'Verification failed');
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Verify Email')),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Icon(
                    FontAwesomeIcons.envelopeCircleCheck,
                    size: 72,
                    color: AppTheme.primaryColor,
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Verify your email',
                    style: theme.textTheme.headlineMedium,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'We sent a verification code to\n${widget.email}',
                    style: theme.textTheme.bodyMedium,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Check your inbox (and spam folder) for the code.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontStyle: FontStyle.italic,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 32),
                  CustomTextField(
                    controller: _codeController,
                    label: 'Verification Code',
                    hint: 'Enter verification code',
                    prefixIcon: FontAwesomeIcons.key,
                    keyboardType: TextInputType.text,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter the verification code';
                      }
                      if (value.length < 6) {
                        return 'Code must be at least 6 characters';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 24),
                  CustomButton(
                    onPressed: authState.isLoading ? null : _handleVerification,
                    text: 'Verify',
                    isLoading: authState.isLoading,
                    icon: FontAwesomeIcons.check,
                  ),
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: () => context.go('/signup'),
                    child: Text(
                      'Back to signup',
                      style: theme.textTheme.bodyMedium,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
