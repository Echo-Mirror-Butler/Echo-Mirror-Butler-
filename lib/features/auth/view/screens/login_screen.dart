import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show OAuthProvider;
import '../../../../core/constants/app_strings.dart';
import '../../../../core/utils/error_handler.dart';
import '../../../../core/themes/app_theme.dart';
import '../../viewmodel/providers/auth_provider.dart';
import '../widgets/custom_button.dart';
import '../widgets/custom_text_field.dart';

/// Login screen
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _keepMeSignedIn = true;

  @override
  void initState() {
    super.initState();
    SharedPreferences.getInstance().then((prefs) {
      if (mounted) {
        setState(() {
          _keepMeSignedIn = prefs.getBool('echo_remember_me') ?? true;
        });
      }
    });
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    if (_formKey.currentState!.validate()) {
      debugPrint('[LoginScreen] Attempt login -> ${_emailController.text}');
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('echo_remember_me', _keepMeSignedIn);
      final authNotifier = ref.read(authProvider.notifier);
      final success = await authNotifier.signIn(
        _emailController.text.trim(),
        _passwordController.text,
      );

      if (mounted) {
        if (success) {
          ErrorHandler.showSuccess(context, AppStrings.successLogin);
          // Navigation will be handled by router
          debugPrint('[LoginScreen] Login success');
        } else {
          final error = ref.read(authProvider).error;
          debugPrint('[LoginScreen] Login failed -> $error');
          ErrorHandler.showError(context, error ?? AppStrings.errorAuth);
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final theme = Theme.of(context);

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Logo/Icon
                  Icon(
                    FontAwesomeIcons.userAstronaut.data,
                    size: 80,
                    color: AppTheme.primaryColor,
                  ),
                  const SizedBox(height: 24),
                  // Title
                  Text(
                    AppStrings.appName,
                    style: theme.textTheme.headlineLarge,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    AppStrings.appTagline,
                    style: theme.textTheme.bodyMedium,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 48),
                  // Email field
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
                  // Password field
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
                  const SizedBox(height: 8),
                  // Keep me signed in
                  SwitchListTile(
                    value: _keepMeSignedIn,
                    onChanged: (val) async {
                      setState(() => _keepMeSignedIn = val);
                      final prefs = await SharedPreferences.getInstance();
                      await prefs.setBool('echo_remember_me', val);
                    },
                    title: Text(
                      'Keep me signed in',
                      style: theme.textTheme.bodyMedium,
                    ),
                    activeColor: AppTheme.primaryColor,
                    contentPadding: EdgeInsets.zero,
                  ),
                  const SizedBox(height: 16),
                  // Login button
                  CustomButton(
                    onPressed: authState.isLoading ? null : _handleLogin,
                    text: AppStrings.login,
                    isLoading: authState.isLoading,
                    icon: FontAwesomeIcons.rightToBracket.data,
                  ),
                  const SizedBox(height: 8),
                  // Forgot password link
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: () => context.go('/forgot-password'),
                      child: Text(
                        'Forgot Password?',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: AppTheme.primaryColor,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  // Sign up link
                  TextButton(
                    onPressed: () => context.go('/signup'),
                    child: Text(
                      'Don\'t have an account? ${AppStrings.signUp}',
                      style: theme.textTheme.bodyMedium,
                    ),
                  ),
                  const SizedBox(height: 16),
                  // OAuth divider
                  Row(
                    children: [
                      const Expanded(child: Divider()),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: Text(
                          'or continue with',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                      const Expanded(child: Divider()),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // Google OAuth button
                  _OAuthButton(
                    label: 'Continue with Google',
                    icon: FontAwesomeIcons.google,
                    onPressed: authState.isLoading
                        ? null
                        : () => ref
                            .read(authProvider.notifier)
                            .signInWithOAuth(OAuthProvider.google),
                  ),
                  const SizedBox(height: 8),
                  // GitHub OAuth button
                  _OAuthButton(
                    label: 'Continue with GitHub',
                    icon: FontAwesomeIcons.github,
                    onPressed: authState.isLoading
                        ? null
                        : () => ref
                            .read(authProvider.notifier)
                            .signInWithOAuth(OAuthProvider.github),
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

class _OAuthButton extends StatelessWidget {
  const _OAuthButton({
    required this.label,
    required this.icon,
    required this.onPressed,
  });

  final String label;
  final IconData icon;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: FaIcon(icon, size: 18),
      label: Text(label),
      style: OutlinedButton.styleFrom(
        minimumSize: const Size.fromHeight(48),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }
}
