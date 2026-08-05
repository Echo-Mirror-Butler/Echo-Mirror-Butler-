import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:local_auth/local_auth.dart';

part 'biometric_provider.g.dart';

@riverpod
class BiometricEnabled extends _$BiometricEnabled {
  static const _key = 'biometric_enabled';

  @override
  bool build() {
    _loadState();
    return false; // Default to false
  }

  Future<void> _loadState() async {
    final prefs = await SharedPreferences.getInstance();
    final isEnabled = prefs.getBool(_key) ?? false;
    state = isEnabled;
  }

  Future<bool> setEnabled(bool value) async {
    if (value) {
      final localAuth = LocalAuthentication();
      final canCheckBiometrics = await localAuth.canCheckBiometrics;
      final isDeviceSupported = await localAuth.isDeviceSupported();

      if (!canCheckBiometrics && !isDeviceSupported) {
        return false;
      }

      final authenticated = await localAuth.authenticate(
        localizedReason: 'Authenticate to enable biometric lock',
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: false,
        ),
      );
      
      if (!authenticated) {
        return false;
      }
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_key, value);
    state = value;
    return true;
  }
}
