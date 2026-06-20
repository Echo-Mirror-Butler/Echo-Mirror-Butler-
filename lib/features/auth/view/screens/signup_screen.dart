import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/themes/app_theme.dart';
import '../../../../core/utils/error_handler.dart';
import '../../viewmodel/providers/auth_provider.dart';
import '../widgets/custom_button.dart';
import '../widgets/custom_text_field.dart';

/// Password strength level
enum _PasswordStrength { none, weak, fair, strong }

_PasswordStrength _scorePassword(String password) {
  if (password.isEmpty) return _PasswordStrength.none;
  final hasLength = password.length >= 8;
  final hasNumber = RegExp(r'\d').hasMatch(password);
  final hasSpecial = RegExp(r'[!@#\$%^&*(),.?":{}|<>_\-]').hasMatch(password);
  final hasUpper = RegExp(r'[A-Z]').hasMatch(password);

  final score = (hasLength ? 1 : 0) +
      (hasNumber || hasSpecial ? 1 : 0) +
      (hasUpper ? 1 : 0);

  if (score >= 3) return _PasswordStrength.strong;
  if (score == 2) return _PasswordStrength.fair;
  return _PasswordStrength.weak;
}

/// Signup screen
class SignupScreen extends ConsumerStatefulWidget {
  const SignupScreen({super.key});

  @override
  ConsumerState<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends ConsumerState<SignupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _nameController = TextEditingController();
  bool _obscurePassword = true;
  bool _obscureConfirm = true;
  bool _isProcessingSignup = false;
  _PasswordStrength _strength = _PasswordStrength.none;
  String _confirmValue = '';

  @override
  void initState() {
    super.initState();
    _passwordController.addListener(() {
      setState(() {
        _strength = _scorePassword(_passwordController.text);
      });
    });
    _confirmPasswordController.addListener(() {
      setState(() {
        _confirmValue = _confirmPasswordController.text;
      });
    });
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _handleSignup() async {
    if (!_formKey.currentState!.validate()) return;
    if (_isProcessingSignup) return;

    setState(() => _isProcessingSignup = true);

    final email = _emailController.text.trim();
    final password = _passwordController.text;
    final name = _nameController.text.trim().isEmpty
        ? null
        : _nameController.text.trim();
    final router = GoRouter.of(context);

    try {
      final authNotifier = ref.read(authProvider.notifier);
      final userId = await authNotifier.signUp(email, password, name);

      if (userId != null && userId.isNotEmpty) {
        if (mounted) {
          setState(() => _isProcessingSignup = false);
          router.go('/verify-email?email=${Uri.encodeComponent(email)}');
        }
      } else {
        final error = ref.read(authProvider).error;
        if (mounted) {
          setState(() => _isProcessingSignup = false);
          ErrorHandler.showError(
            context,
            error ?? 'Signup failed. Please try again.',
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isProcessingSignup = false);
        ErrorHandler.showError(context, 'An error occurred. Please try again.');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final theme = Theme.of(context);
    final password = _passwordController.text;

    // Requirement checks
    final hasLength = password.length >= 8;
    final hasNumberOrSpecial =
        RegExp(r'[\d!@#\$%^&*(),.?":{}|<>_\-]').hasMatch(password);
    final confirmMismatch = _confirmValue.isNotEmpty &&
        _confirmValue != _passwordController.text;

    return Scaffold(
      appBar: AppBar(title: const Text(AppStrings.signUp)),
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
                    FontAwesomeIcons.userPlus.data,
                    size: 72,
                    color: AppTheme.primaryColor,
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Create your account',
                    style: theme.textTheme.headlineMedium,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    AppStrings.appTagline,
                    style: theme.textTheme.bodyMedium,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 32),
                  CustomTextField(
                    controller: _nameController,
                    label: 'Name (optional)',
                    hint: 'Enter your name',
                    prefixIcon: FontAwesomeIcons.user.data,
                  ),
                  const SizedBox(height: 16),
                  CustomTextField(
                    controller: _emailController,
                    label: AppStrings.email,
                    hint: 'Enter your email',
                    keyboardType: TextInputType.emailAddress,
                    prefixIcon: FontAwesomeIcons.envelope.data,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter your email';
                      }
                      if (!value.contains('@')) {
                        return 'Please enter a valid email';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  CustomTextField(
                    controller: _passwordController,
                    label: AppStrings.password,
                    hint: 'Enter your password',
                    obscureText: _obscurePassword,
                    prefixIcon: FontAwesomeIcons.lock.data,
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscurePassword
                            ? FontAwesomeIcons.eye.data
                            : FontAwesomeIcons.eyeSlash.data,
                      ),
                      onPressed: () =>
                          setState(() => _obscurePassword = !_obscurePassword),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter your password';
                      }
                      if (value.length < 8) {
                        return 'Password must be at least 8 characters';
                      }
                      if (!RegExp(
                        r'[\d!@#\$%^&*(),.?":{}|<>_\-]',
                      ).hasMatch(value)) {
                        return 'Must contain at least one number or special character';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 8),
                  // Password requirements & strength meter
                  _PasswordRequirements(
                    hasLength: hasLength,
                    hasNumberOrSpecial: hasNumberOrSpecial,
                    strength: _strength,
                  ),
                  const SizedBox(height: 16),
                  CustomTextField(
                    controller: _confirmPasswordController,
                    label: 'Confirm Password',
                    hint: 'Re-enter your password',
                    obscureText: _obscureConfirm,
                    prefixIcon: FontAwesomeIcons.lock.data,
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscureConfirm
                            ? FontAwesomeIcons.eye.data
                            : FontAwesomeIcons.eyeSlash.data,
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
                  // Inline mismatch hint (shown before submit)
                  if (confirmMismatch)
                    Padding(
                      padding: const EdgeInsets.only(top: 4, left: 4),
                      child: Text(
                        'Passwords do not match',
                        style: theme.textTheme.bodySmall
                            ?.copyWith(color: AppTheme.errorColor),
                      ),
                    ),
                  const SizedBox(height: 24),
                  CustomButton(
                    onPressed: (authState.isLoading || _isProcessingSignup)
                        ? null
                        : _handleSignup,
                    text: AppStrings.signUp,
                    isLoading: authState.isLoading || _isProcessingSignup,
                    icon: FontAwesomeIcons.userPlus.data,
                  ),
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: () => context.go('/login'),
                    child: Text(
                      'Already have an account? ${AppStrings.login}',
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

/// Displays password requirements and a strength meter
class _PasswordRequirements extends StatelessWidget {
  const _PasswordRequirements({
    required this.hasLength,
    required this.hasNumberOrSpecial,
    required this.strength,
  });

  final bool hasLength;
  final bool hasNumberOrSpecial;
  final _PasswordStrength strength;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    Color strengthColor;
    String strengthLabel;
    double strengthFraction;

    switch (strength) {
      case _PasswordStrength.strong:
        strengthColor = AppTheme.successColor;
        strengthLabel = 'Strong';
        strengthFraction = 1.0;
        break;
      case _PasswordStrength.fair:
        strengthColor = Colors.orange;
        strengthLabel = 'Fair';
        strengthFraction = 0.6;
        break;
      case _PasswordStrength.weak:
        strengthColor = AppTheme.errorColor;
        strengthLabel = 'Weak';
        strengthFraction = 0.25;
        break;
      case _PasswordStrength.none:
        strengthColor = Colors.grey;
        strengthLabel = '';
        strengthFraction = 0.0;
        break;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (strength != _PasswordStrength.none) ...[
          Row(
            children: [
              Expanded(
                child: LinearProgressIndicator(
                  value: strengthFraction,
                  color: strengthColor,
                  backgroundColor: Colors.grey.shade300,
                  minHeight: 4,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                strengthLabel,
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: strengthColor, fontWeight: FontWeight.w600),
              ),
            ],
          ),
          const SizedBox(height: 6),
        ],
        _Requirement(met: hasLength, label: 'At least 8 characters'),
        _Requirement(
          met: hasNumberOrSpecial,
          label: 'At least one number or special character',
        ),
      ],
    );
  }
}

class _Requirement extends StatelessWidget {
  const _Requirement({required this.met, required this.label});
  final bool met;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Icon(
            met ? Icons.check_circle : Icons.cancel,
            size: 14,
            color: met ? AppTheme.successColor : AppTheme.errorColor,
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: met ? AppTheme.successColor : AppTheme.errorColor,
                ),
          ),
        ],
      ),
    );
  }
}
