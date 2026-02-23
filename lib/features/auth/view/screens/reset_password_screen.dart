import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/themes/app_theme.dart';
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

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _handleReset() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);
      // TODO: integrate password reset with auth provider using widget.token
      await Future.delayed(const Duration(seconds: 1));
      if (mounted) {
        setState(() => _isLoading = false);
        context.go('/login');
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
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Icon(
                    FontAwesomeIcons.key,
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
                    'Enter a new password for ${widget.email}',
                    style: theme.textTheme.bodyMedium,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 40),
                  CustomTextField(
                    controller: _passwordController,
                    label: 'New Password',
                    hint: 'Enter new password',
                    obscureText: _obscurePassword,
                    prefixIcon: FontAwesomeIcons.lock,
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscurePassword
                            ? FontAwesomeIcons.eye
                            : FontAwesomeIcons.eyeSlash,
                      ),
                      onPressed: () =>
                          setState(() => _obscurePassword = !_obscurePassword),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter a new password';
                      }
                      if (value.length < 6) {
                        return 'Password must be at least 6 characters';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  CustomTextField(
                    controller: _confirmPasswordController,
                    label: 'Confirm Password',
                    hint: 'Confirm new password',
                    obscureText: _obscureConfirm,
                    prefixIcon: FontAwesomeIcons.lock,
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscureConfirm
                            ? FontAwesomeIcons.eye
                            : FontAwesomeIcons.eyeSlash,
                      ),
                      onPressed: () =>
                          setState(() => _obscureConfirm = !_obscureConfirm),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please confirm your password';
                      }
                      if (value != _passwordController.text) {
                        return 'Passwords do not match';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 32),
                  CustomButton(
                    onPressed: _isLoading ? null : _handleReset,
                    text: 'Reset Password',
                    isLoading: _isLoading,
                    icon: FontAwesomeIcons.check,
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
