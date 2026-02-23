import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/themes/app_theme.dart';
import '../../../auth/view/widgets/custom_button.dart';
import '../../../auth/view/widgets/custom_text_field.dart';

/// Change password screen for authenticated users
class ChangePasswordScreen extends ConsumerStatefulWidget {
  const ChangePasswordScreen({super.key});

  @override
  ConsumerState<ChangePasswordScreen> createState() =>
      _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends ConsumerState<ChangePasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _currentPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _obscureCurrent = true;
  bool _obscureNew = true;
  bool _obscureConfirm = true;
  bool _isLoading = false;

  @override
  void dispose() {
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _handleChangePassword() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);
      // TODO: integrate change password with auth provider
      await Future.delayed(const Duration(seconds: 1));
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Password updated successfully')),
        );
        context.pop();
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
          onPressed: () => context.pop(),
        ),
        title: const Text('Change Password'),
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
                    'Change your password',
                    style: theme.textTheme.headlineMedium,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 40),
                  CustomTextField(
                    controller: _currentPasswordController,
                    label: 'Current Password',
                    hint: 'Enter current password',
                    obscureText: _obscureCurrent,
                    prefixIcon: FontAwesomeIcons.lock,
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscureCurrent
                            ? FontAwesomeIcons.eye
                            : FontAwesomeIcons.eyeSlash,
                      ),
                      onPressed: () =>
                          setState(() => _obscureCurrent = !_obscureCurrent),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter your current password';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  CustomTextField(
                    controller: _newPasswordController,
                    label: 'New Password',
                    hint: 'Enter new password',
                    obscureText: _obscureNew,
                    prefixIcon: FontAwesomeIcons.lock,
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscureNew
                            ? FontAwesomeIcons.eye
                            : FontAwesomeIcons.eyeSlash,
                      ),
                      onPressed: () =>
                          setState(() => _obscureNew = !_obscureNew),
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
                    label: 'Confirm New Password',
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
                        return 'Please confirm your new password';
                      }
                      if (value != _newPasswordController.text) {
                        return 'Passwords do not match';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 32),
                  CustomButton(
                    onPressed: _isLoading ? null : _handleChangePassword,
                    text: 'Update Password',
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
