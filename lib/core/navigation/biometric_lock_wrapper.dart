import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:local_auth/local_auth.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../../core/viewmodel/providers/biometric_provider.dart';

class BiometricLockWrapper extends ConsumerStatefulWidget {
  final Widget child;

  const BiometricLockWrapper({super.key, required this.child});

  @override
  ConsumerState<BiometricLockWrapper> createState() => _BiometricLockWrapperState();
}

class _BiometricLockWrapperState extends ConsumerState<BiometricLockWrapper>
    with WidgetsBindingObserver {
  bool _isAuthenticated = false;
  bool _isAuthenticating = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkBiometricOnStart();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkBiometricOnStart();
    } else if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) {
      final isEnabled = ref.read(biometricEnabledProvider);
      if (isEnabled) {
        setState(() {
          _isAuthenticated = false;
        });
      }
    }
  }

  Future<void> _checkBiometricOnStart() async {
    final isEnabled = ref.read(biometricEnabledProvider);
    if (!isEnabled || _isAuthenticated || _isAuthenticating) return;

    await _authenticate();
  }

  Future<void> _authenticate() async {
    if (_isAuthenticating) return;
    
    setState(() {
      _isAuthenticating = true;
    });

    try {
      final localAuth = LocalAuthentication();
      final authenticated = await localAuth.authenticate(
        localizedReason: 'Please authenticate to unlock EchoMirror',
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: false,
        ),
      );

      if (mounted) {
        setState(() {
          _isAuthenticated = authenticated;
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isAuthenticating = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEnabled = ref.watch(biometricEnabledProvider);

    if (!isEnabled || _isAuthenticated) {
      return widget.child;
    }

    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              FontAwesomeIcons.lock.data,
              size: 64,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 24),
            Text(
              'App Locked',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 12),
            Text(
              'Unlock with Biometrics or Passcode',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                  ),
            ),
            const SizedBox(height: 32),
            FilledButton.icon(
              onPressed: _isAuthenticating ? null : _authenticate,
              icon: const Icon(Icons.fingerprint),
              label: const Text('Unlock'),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
