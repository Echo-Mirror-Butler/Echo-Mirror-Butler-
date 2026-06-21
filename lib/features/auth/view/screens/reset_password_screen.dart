import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/themes/app_theme.dart';
import '../../viewmodel/providers/auth_provider.dart';
import '../widgets/custom_button.dart';
import '../widgets/custom_text_field.dart';

/// Reset password screen
class ResetPasswordScreen extends ConsumerStatefulWidget {
  const ResetPasswordScreen({
    super.key,
    required this.email,
    required this.token,
  });

  final String email;
  final String token;

  @override
  ConsumerState<ResetPasswordScreen> createState() =>
      _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends ConsumerState<ResetPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _obscurePassword = true;
  bool _obscureConfirm = true;
  bool _isLoading = false;
  bool _linkExpired = false;

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  bool _isExpiredError(Object e) {
    final msg = e.toString().toLowerCase();
    return msg.contains('expired') ||
        msg.contains('invalid') ||
        msg.contains('token');
  }

  Future<void> _handleReset() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    try {
      final authRepository = ref.read(authRepositoryProvider);
      final success = await authRepository.resetPassword(
        widget.email,
        widget.token,
        _passwordController.text,
      );

      if (mounted) {
        setState(() => _isLoading = false);
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Password reset successfully! Please log in with your new password.',
              ),
              backgroundColor: AppTheme.successColor,
            ),
          );
          context.go('/login');
        } else {
          setState(() => _linkExpired = true);
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          if (_isExpiredError(e)) {
            _linkExpired = true;
          }
        });
        if (!_linkExpired) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error: ${e.toString()}'),
              backgroundColor: AppTheme.errorColor,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/login'),
        ),
        title: const Text('Reset Password'),
        elevation: 0,
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: _linkExpired
                ? _ExpiredLinkView(email: widget.email)
                : _ResetFormView(
                    formKey: _formKey,
                    passwordController: _passwordController,
                    confirmPasswordController: _confirmPasswordController,
                    obscurePassword: _obscurePassword,
                    obscureConfirm: _obscureConfirm,
                    isLoading: _isLoading,
                    email: widget.email,
                    onTogglePassword: () =>
                        setState(() => _obscurePassword = !_obscurePassword),
                    onToggleConfirm: () =>
                        setState(() => _obscureConfirm = !_obscureConfirm),
                    onReset: _handleReset,
                  ),
          ),
        ),
      ),
    );
  }
}

class _ResetFormView extends StatelessWidget {
  const _ResetFormView({
    required this.formKey,
    required this.passwordController,
    required this.confirmPasswordController,
    required this.obscurePassword,
    required this.obscureConfirm,
    required this.isLoading,
    required this.email,
    required this.onTogglePassword,
    required this.onToggleConfirm,
    required this.onReset,
  });

  final GlobalKey<FormState> formKey;
  final TextEditingController passwordController;
  final TextEditingController confirmPasswordController;
  final bool obscurePassword;
  final bool obscureConfirm;
  final bool isLoading;
  final String email;
  final VoidCallback onTogglePassword;
  final VoidCallback onToggleConfirm;
  final VoidCallback onReset;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Form(
      key: formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Icon(
            FontAwesomeIcons.key.data,
            size: 64,
            color: AppTheme.primaryColor,
          ),
          const SizedBox(height: 24),
          Text(
            'Create new password',
            style: theme.textTheme.headlineMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'Enter a new password for $email',
            style: theme.textTheme.bodyMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          // Expiry notice
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.amber.shade100,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.amber.shade400),
            ),
            child: Row(
              children: [
                Icon(Icons.access_time, size: 16, color: Colors.amber.shade800),
                const SizedBox(width: 8),
                Text(
                  'This link expires in 1 hour.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: Colors.amber.shade900,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),
          CustomTextField(
            controller: passwordController,
            label: 'New Password',
            hint: 'Enter new password',
            obscureText: obscurePassword,
            prefixIcon: FontAwesomeIcons.lock.data,
            suffixIcon: IconButton(
              icon: Icon(
                obscurePassword
                    ? FontAwesomeIcons.eye.data
                    : FontAwesomeIcons.eyeSlash.data,
              ),
              onPressed: onTogglePassword,
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please enter a new password';
              }
              if (value.length < 8) {
                return 'Password must be at least 8 characters';
              }
              if (!RegExp(r'[\d!@#\$%^&*(),.?":{}|<>_\-]').hasMatch(value)) {
                return 'Must contain at least one number or special character';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),
          CustomTextField(
            controller: confirmPasswordController,
            label: 'Confirm Password',
            hint: 'Confirm new password',
            obscureText: obscureConfirm,
            prefixIcon: FontAwesomeIcons.lock.data,
            suffixIcon: IconButton(
              icon: Icon(
                obscureConfirm
                    ? FontAwesomeIcons.eye.data
                    : FontAwesomeIcons.eyeSlash.data,
              ),
              onPressed: onToggleConfirm,
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please confirm your password';
              }
              if (value != passwordController.text) {
                return 'Passwords do not match';
              }
              return null;
            },
          ),
          const SizedBox(height: 32),
          CustomButton(
            onPressed: isLoading ? null : onReset,
            text: 'Reset Password',
            isLoading: isLoading,
            icon: FontAwesomeIcons.check.data,
          ),
        ],
      ),
    );
  }
}

/// Shown when the reset link has expired
class _ExpiredLinkView extends ConsumerWidget {
  const _ExpiredLinkView({required this.email});
  final String email;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    Future<void> requestNew() async {
      final repo = ref.read(authRepositoryProvider);
      await repo.requestPasswordReset(email);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('A new reset link has been sent to your inbox.'),
            backgroundColor: AppTheme.successColor,
          ),
        );
        context.go('/login');
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Icon(
          FontAwesomeIcons.triangleExclamation.data,
          size: 64,
          color: AppTheme.errorColor,
        ),
        const SizedBox(height: 24),
        Text(
          'Link expired',
          style: theme.textTheme.headlineMedium,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 12),
        Text(
          'This password reset link has expired or is invalid. '
          'Request a new one to continue.',
          style: theme.textTheme.bodyMedium,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 40),
        CustomButton(
          onPressed: requestNew,
          text: 'Request a new link',
          icon: FontAwesomeIcons.rotate.data,
        ),
        const SizedBox(height: 16),
        TextButton(
          onPressed: () => context.go('/login'),
          child: const Text('Back to Login'),
        ),
      ],
    );
  }
}
