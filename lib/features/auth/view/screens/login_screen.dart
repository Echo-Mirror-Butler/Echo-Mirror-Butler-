import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
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

  Future<void> _handleGoogleSignIn() async {
    final authNotifier = ref.read(authProvider.notifier);
    final success = await authNotifier.signInWithGoogle();
    if (mounted && !success) {
      final error = ref.read(authProvider).error;
      ErrorHandler.showError(context, error ?? AppStrings.errorAuth);
    }
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
                  const SizedBox(height: 16),
                  // Divider
                  Row(children: [
                    const Expanded(child: Divider()),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Text('or', style: theme.textTheme.bodySmall),
                    ),
                    const Expanded(child: Divider()),
                  ]),
                  const SizedBox(height: 16),
                  // Google sign-in button
                  OutlinedButton.icon(
                    onPressed: authState.isLoading ? null : _handleGoogleSignIn,
                    icon: const _GoogleLogo(),
                    label: const Text('Continue with Google'),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(48),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
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
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _GoogleLogo extends StatelessWidget {
  const _GoogleLogo();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 18,
      height: 18,
      child: CustomPaint(painter: _GoogleLogoPainter()),
    );
  }
}

class _GoogleLogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width;
    // Blue arc (right)
    canvas.drawArc(
      Rect.fromLTWH(0, 0, s, s),
      -0.52, 3.14, false,
      Paint()..color = const Color(0xFF4285F4)..style = PaintingStyle.stroke..strokeWidth = s * 0.18,
    );
    // Red arc (top-left)
    canvas.drawArc(
      Rect.fromLTWH(0, 0, s, s),
      -2.62, 1.57, false,
      Paint()..color = const Color(0xFFEA4335)..style = PaintingStyle.stroke..strokeWidth = s * 0.18,
    );
    // Yellow arc (bottom-left)
    canvas.drawArc(
      Rect.fromLTWH(0, 0, s, s),
      2.09, 0.87, false,
      Paint()..color = const Color(0xFFFBBC05)..style = PaintingStyle.stroke..strokeWidth = s * 0.18,
    );
    // Green arc (bottom)
    canvas.drawArc(
      Rect.fromLTWH(0, 0, s, s),
      2.62, 0.52, false,
      Paint()..color = const Color(0xFF34A853)..style = PaintingStyle.stroke..strokeWidth = s * 0.18,
    );
    // Horizontal bar
    canvas.drawRect(
      Rect.fromLTWH(s * 0.5, s * 0.38, s * 0.45, s * 0.18),
      Paint()..color = const Color(0xFF4285F4),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
