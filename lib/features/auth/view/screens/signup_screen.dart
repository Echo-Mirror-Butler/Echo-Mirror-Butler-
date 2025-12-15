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
  final _nameController = TextEditingController();
  bool _obscurePassword = true;
  bool _isProcessingSignup = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _handleSignup() async {
    if (!_formKey.currentState!.validate()) return;
    if (_isProcessingSignup) return; // Prevent multiple submissions
    
    setState(() {
      _isProcessingSignup = true;
    });
    
    debugPrint('[SignupScreen] Attempt signup -> ${_emailController.text}');
    
    // Store values in local variables before async operation
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    final name = _nameController.text.trim().isEmpty
        ? null
        : _nameController.text.trim();
    
    // Get the router context before async operation
    final router = GoRouter.of(context);
    
    try {
      // Perform signup - this returns accountRequestId
      final authNotifier = ref.read(authProvider.notifier);
      final accountRequestId = await authNotifier.signUp(email, password, name);

      debugPrint('[SignupScreen] signUp returned -> accountRequestId: $accountRequestId');
      
      if (accountRequestId != null && accountRequestId.isNotEmpty) {
        // Build verification URL
        final encodedEmail = Uri.encodeComponent(email);
        final encodedPassword = Uri.encodeComponent(password);
        final encodedName = name != null ? Uri.encodeComponent(name) : '';
        final verifyUrl = '/verify?email=$encodedEmail&accountRequestId=${Uri.encodeComponent(accountRequestId)}&password=$encodedPassword${name != null ? '&name=$encodedName' : ''}';
        
        debugPrint('[SignupScreen] Navigating to: $verifyUrl');
        
        // Use the router instance we got before async operation
        router.go(verifyUrl);
        
        // Clear loading state after navigation
        authNotifier.clearLoadingState();
        debugPrint('[SignupScreen] Navigation complete');
      } else {
        // Signup failed
        final error = ref.read(authProvider).error;
        debugPrint('[SignupScreen] Signup failed. Error: $error');
        
        if (mounted) {
          setState(() {
            _isProcessingSignup = false;
          });
          ErrorHandler.showError(
            context,
            error ?? 'Signup failed. Please try again.',
          );
        }
      }
    } catch (e, stackTrace) {
      debugPrint('[SignupScreen] Signup error: $e');
      debugPrint('[SignupScreen] Stack trace: $stackTrace');
      
      if (mounted) {
        setState(() {
          _isProcessingSignup = false;
        });
        ErrorHandler.showError(
          context,
          'An error occurred. Please try again.',
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text(AppStrings.signUp),
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
                    FontAwesomeIcons.userPlus,
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
                    prefixIcon: FontAwesomeIcons.user,
                  ),
                  const SizedBox(height: 16),
                  CustomTextField(
                    controller: _emailController,
                    label: AppStrings.email,
                    hint: 'Enter your email',
                    keyboardType: TextInputType.emailAddress,
                    prefixIcon: FontAwesomeIcons.envelope,
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
                    prefixIcon: FontAwesomeIcons.lock,
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscurePassword
                            ? FontAwesomeIcons.eye
                            : FontAwesomeIcons.eyeSlash,
                      ),
                      onPressed: () {
                        setState(() {
                          _obscurePassword = !_obscurePassword;
                        });
                      },
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter your password';
                      }
                      if (value.length < 6) {
                        return 'Password must be at least 6 characters';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 24),
                  CustomButton(
                    onPressed: (authState.isLoading || _isProcessingSignup) ? null : _handleSignup,
                    text: AppStrings.signUp,
                    isLoading: authState.isLoading || _isProcessingSignup,
                    icon: FontAwesomeIcons.userPlus,
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

