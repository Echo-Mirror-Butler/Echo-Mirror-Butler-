import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../../core/constants/environment_config.dart';

const _testnetDismissKey = 'testnet_banner_dismissed';

/// Dismissible warning shown on testnet builds that ECHO and XLM have no
/// real-world value. The dismissal is persisted in [SharedPreferences].
class WalletTestnetBanner extends StatefulWidget {
  const WalletTestnetBanner({super.key});

  @override
  State<WalletTestnetBanner> createState() => _WalletTestnetBannerState();
}

class _WalletTestnetBannerState extends State<WalletTestnetBanner> {
  bool _dismissed = false;

  @override
  void initState() {
    super.initState();
    _loadDismissed();
  }

  Future<void> _loadDismissed() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() => _dismissed = prefs.getBool(_testnetDismissKey) ?? false);
    }
  }

  Future<void> _dismiss() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_testnetDismissKey, true);
    if (mounted) {
      setState(() => _dismissed = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Only show on testnet
    if (!EnvironmentConfig.isTestnet) return const SizedBox.shrink();
    if (_dismissed) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.amber.shade100,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.amber.shade300),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.warning_amber_rounded,
            color: Colors.amber,
            size: 20,
          ),
          const SizedBox(width: 10),
          const Expanded(
            child: Text(
              '⚠ Testnet — ECHO and XLM here have no real-world value',
              style: TextStyle(fontSize: 13, color: Colors.brown),
            ),
          ),
          GestureDetector(
            onTap: _dismiss,
            child: const Icon(Icons.close, size: 18, color: Colors.brown),
          ),
        ],
      ),
    );
  }
}
