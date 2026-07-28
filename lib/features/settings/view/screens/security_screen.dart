import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../../../core/themes/app_theme.dart';
import '../../../../core/viewmodel/providers/biometric_provider.dart';
import '../../../../core/utils/error_handler.dart';

class SecurityScreen extends ConsumerStatefulWidget {
  const SecurityScreen({super.key});

  @override
  ConsumerState<SecurityScreen> createState() => _SecurityScreenState();
}

class _SecurityScreenState extends ConsumerState<SecurityScreen> {
  List<Map<String, dynamic>> _sessions = [];
  bool _isLoadingSessions = true;
  bool _isMfaEnabled = false;
  bool _isLoadingMfa = true;
  bool _isSigningOutAll = false;
  String? _qrCodeData;
  String? _mfaFactorId;
  List<String>? _recoveryCodes;

  @override
  void initState() {
    super.initState();
    _loadSessions();
    _checkMfaStatus();
  }

  Future<void> _loadSessions() async {
    setState(() => _isLoadingSessions = true);

    try {
      final client = Supabase.instance.client;
      final userId = client.auth.currentUser?.id;
      final currentSession = client.auth.currentSession;

      if (userId != null) {
        final res = await client
            .from('user_sessions')
            .select('id, device_name, user_agent, last_active, created_at')
            .eq('user_id', userId)
            .order('last_active', ascending: false);

        final sessions = (res as List<dynamic>?)
                ?.map((s) => Map<String, dynamic>.from(s as Map))
                .toList() ??
            [];

        if (currentSession != null && sessions.isEmpty) {
          _sessions = [
            {
              'id': 'current',
              'device_name': 'This device',
              'last_active': DateTime.now(),
              'is_current': true,
            },
          ];
        } else {
          _sessions = sessions.map((s) {
            s['is_current'] = s['created_at'] != null &&
                currentSession?.createdAt != null &&
                _closeTimestamps(
                  DateTime.parse(s['created_at'] as String),
                  currentSession!.createdAt,
                );
            return s;
          }).toList();

          if (_sessions.every((s) => s['is_current'] != true) &&
              currentSession != null) {
            _sessions.insert(
              0,
              {
                'id': 'current',
                'device_name': 'This device',
                'last_active': DateTime.now(),
                'is_current': true,
              },
            );
          }
        }
      }
    } catch (e) {
      debugPrint('[SecurityScreen] Error loading sessions: $e');
    } finally {
      if (mounted) setState(() => _isLoadingSessions = false);
    }
  }

  bool _closeTimestamps(DateTime a, DateTime b) {
    return (a.difference(b).inSeconds.abs() < 10);
  }

  Future<void> _checkMfaStatus() async {
    setState(() => _isLoadingMfa = true);

    try {
      final client = Supabase.instance.client;
      final factors = await client.auth.mfa.listFactors();
      setState(() => _isMfaEnabled = factors.totp.isNotEmpty);
    } catch (e) {
      debugPrint('[SecurityScreen] Error checking MFA status: $e');
    } finally {
      if (mounted) setState(() => _isLoadingMfa = false);
    }
  }

  Future<void> _revokeSession(String sessionId) async {
    try {
      final client = Supabase.instance.client;

      if (sessionId == 'current') {
        await client.auth.signOut();
        if (mounted) {
          ErrorHandler.showSuccess(context, 'Signed out successfully');
        }
        return;
      }

      await client
          .from('user_sessions')
          .delete()
          .eq('id', sessionId)
          .eq('user_id', client.auth.currentUser!.id);

      if (mounted) {
        ErrorHandler.showSuccess(context, 'Session revoked');
        await _loadSessions();
      }
    } catch (e) {
      if (mounted) {
        ErrorHandler.showError(context, ErrorHandler.getErrorMessage(e));
      }
    }
  }

  Future<void> _signOutAllOtherSessions() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sign Out All Other Devices?'),
        content: const Text(
          'This will sign you out of all other devices. You will remain signed in on this device.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Sign Out All'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      setState(() => _isSigningOutAll = true);
      try {
        final client = Supabase.instance.client;
        await client.auth.signOut(scope: SignOutScope.others);

        final userId = client.auth.currentUser?.id;
        if (userId != null) {
          await client
              .from('user_sessions')
              .delete()
              .neq('id', 'current')
              .eq('user_id', userId);
        }

        if (mounted) {
          ErrorHandler.showSuccess(
            context,
            'All other sessions have been signed out',
          );
          await _loadSessions();
        }
      } catch (e) {
        if (mounted) {
          ErrorHandler.showError(context, ErrorHandler.getErrorMessage(e));
        }
      } finally {
        if (mounted) setState(() => _isSigningOutAll = false);
      }
    }
  }

  Future<void> _enrollMfa() async {
    try {
      final client = Supabase.instance.client;
      final challenge = await client.auth.mfa.enroll(issuer: 'EchoMirror');

      setState(() {
        _qrCodeData = challenge.totp.qrCode;
        _mfaFactorId = challenge.id;
      });

      if (mounted) {
        final verified = await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (context) => _buildMfaEnrollDialog(),
        );

        if (verified == true && _mfaFactorId != null) {
          await _generateAndStoreRecoveryCodes();
          if (mounted) {
            await _showRecoveryCodesDialog();
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ErrorHandler.showError(
          context,
          'Error enabling 2FA: ${ErrorHandler.getErrorMessage(e)}',
        );
      }
    }
  }

  Future<void> _generateAndStoreRecoveryCodes() async {
    final client = Supabase.instance.client;
    final userId = client.auth.currentUser?.id;
    if (userId == null) return;

    final codes = List<String>.generate(10, (_) {
      return _generateRecoveryCode();
    });

    for (final code in codes) {
      final codeHash = base64.encode(utf8.encode('${userId}_$code'));
      await client.from('mfa_recovery_codes').insert({
        'user_id': userId,
        'code_hash': codeHash,
      });
    }

    setState(() => _recoveryCodes = codes);
  }

  String _generateRecoveryCode() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final random = Random.secure();
    return List.generate(8, (_) => chars[random.nextInt(chars.length)]).join();
  }

  Future<void> _showRecoveryCodesDialog() async {
    if (_recoveryCodes == null) return;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('\u{1F510} Recovery Codes'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Save these recovery codes in a safe place. '
                'Each code can be used once to regain access to your account '
                'if you lose your authenticator device.',
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  children: _recoveryCodes!.map((code) {
                    return SelectableText(
                      code,
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 2,
                      ),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'These codes will not be shown again.',
                style: TextStyle(fontSize: 12, color: Colors.red),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _checkMfaStatus();
            },
            child: const Text('I\'ve saved them'),
          ),
        ],
      ),
    );
  }

  Future<void> _disableMfa() async {
    final code = await showDialog<String>(
      context: context,
      builder: (context) => _buildMfaDisableDialog(),
    );

    if (code != null && code.isNotEmpty) {
      try {
        final client = Supabase.instance.client;
        final factors = await client.auth.mfa.listFactors();

        if (factors.totp.isNotEmpty) {
          final factor = factors.totp.first;
          final challenge = await client.auth.mfa.challenge(factorId: factor.id);
          await client.auth.mfa.verify(
            factorId: factor.id,
            challengeId: challenge.id,
            code: code,
          );

          await client.auth.mfa.unenroll(factorId: factor.id);

          final userId = client.auth.currentUser?.id;
          if (userId != null) {
            await client
                .from('mfa_recovery_codes')
                .delete()
                .eq('user_id', userId);
          }

          if (mounted) {
            ErrorHandler.showSuccess(context, '2FA disabled successfully');
            await _checkMfaStatus();
          }
        }
      } catch (e) {
        if (mounted) {
          ErrorHandler.showError(
            context,
            'Error disabling 2FA: ${ErrorHandler.getErrorMessage(e)}',
          );
        }
      }
    }
  }

  Widget _buildMfaEnrollDialog() {
    final totpController = TextEditingController();

    return AlertDialog(
      title: const Text('Enable Two-Factor Authentication'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              '1. Scan this QR code with your authenticator app (Google Authenticator, Authy, etc.)',
            ),
            const SizedBox(height: 12),
            if (_qrCodeData != null)
              QrImageView(
                data: _qrCodeData!,
                version: QrVersions.auto,
                size: 200.0,
              ),
            const SizedBox(height: 16),
            const Text(
              '2. Enter the 6-digit code from your app to verify:',
            ),
            const SizedBox(height: 8),
            TextField(
              controller: totpController,
              decoration: const InputDecoration(
                labelText: 'Verification Code',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
              maxLength: 6,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () {
            setState(() {
              _qrCodeData = null;
              _mfaFactorId = null;
            });
            Navigator.pop(context, false);
          },
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () async {
            final code = totpController.text.trim();
            if (code.length != 6 || _mfaFactorId == null) {
              ErrorHandler.showError(
                context,
                'Please enter the 6-digit code from your authenticator app',
              );
              return;
            }

            try {
              final client = Supabase.instance.client;
              final challenge = await client.auth.mfa.challenge(
                factorId: _mfaFactorId!,
              );
              await client.auth.mfa.verify(
                factorId: _mfaFactorId!,
                challengeId: challenge.id,
                code: code,
              );

              Navigator.pop(context, true);
            } catch (e) {
              ErrorHandler.showError(
                context,
                'Verification failed: ${ErrorHandler.getErrorMessage(e)}',
              );
            }
          },
          child: const Text('Verify'),
        ),
      ],
    );
  }

  Widget _buildMfaDisableDialog() {
    final controller = TextEditingController();

    return AlertDialog(
      title: const Text('Disable Two-Factor Authentication'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('Enter your current TOTP code to confirm:'),
          const SizedBox(height: 16),
          TextField(
            controller: controller,
            decoration: const InputDecoration(
              labelText: 'TOTP Code',
              border: OutlineInputBorder(),
            ),
            keyboardType: TextInputType.number,
            maxLength: 6,
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, controller.text),
          style: TextButton.styleFrom(foregroundColor: Colors.red),
          child: const Text('Disable'),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isAppLockEnabled = ref.watch(biometricEnabledProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Security'),
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _buildSectionHeader(
            theme,
            icon: FontAwesomeIcons.lock.data,
            title: 'App Lock',
            subtitle: 'Require Face ID or Fingerprint to open the app',
          ),
          const SizedBox(height: 12),
          _buildAppLockCard(theme, isAppLockEnabled),
          const SizedBox(height: 24),

          _buildSectionHeader(
            theme,
            icon: FontAwesomeIcons.mobile.data,
            title: 'Active Sessions',
            subtitle: 'Manage devices signed into your account',
          ),
          const SizedBox(height: 12),
          _isLoadingSessions
              ? const Center(child: CircularProgressIndicator())
              : _buildSessionsCard(theme),
          const SizedBox(height: 24),

          _buildSectionHeader(
            theme,
            icon: FontAwesomeIcons.shield.data,
            title: 'Two-Factor Authentication',
            subtitle: 'Add an extra layer of security',
          ),
          const SizedBox(height: 12),
          _isLoadingMfa
              ? const Center(child: CircularProgressIndicator())
              : _buildMfaCard(theme),
        ],
      ),
    );
  }

  Widget _buildAppLockCard(ThemeData theme, bool isAppLockEnabled) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: theme.colorScheme.outline.withOpacity(0.1),
          width: 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(FontAwesomeIcons.fingerprint.data,
                        color: theme.colorScheme.primary, size: 18),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Biometric Unlock',
                            style: theme.textTheme.titleMedium),
                        const SizedBox(height: 4),
                        Text(
                          'Use device biometrics to unlock',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurface.withOpacity(0.6),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Switch(
                    value: isAppLockEnabled,
                    onChanged: (value) async {
                      final success = await ref
                          .read(biometricEnabledProvider.notifier)
                          .setEnabled(value);
                      if (!success && value && mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                                'Authentication failed or not available.'),
                          ),
                        );
                      }
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(
    ThemeData theme, {
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: theme.colorScheme.primary.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: theme.colorScheme.primary, size: 20),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: theme.textTheme.titleLarge),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurface.withOpacity(0.6),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSessionsCard(ThemeData theme) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: theme.colorScheme.outline.withOpacity(0.1),
          width: 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            if (_sessions.isEmpty)
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text('No active sessions found'),
              )
            else
              ..._sessions.map((session) {
                final isCurrent = session['is_current'] == true ||
                    session['id'] == 'current';
                return ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: (isCurrent ? Colors.green : Colors.blue)
                          .withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      FontAwesomeIcons.mobile.data,
                      color: isCurrent ? Colors.green : Colors.blue,
                      size: 18,
                    ),
                  ),
                  title: Text(
                    session['device_name']?.toString() ?? 'Unknown device',
                  ),
                  subtitle: Text(
                    'Last active: ${_formatDateTime(session['last_active'] ?? session['created_at'])}',
                    style: theme.textTheme.bodySmall,
                  ),
                  trailing: isCurrent
                      ? Chip(
                          label: const Text('Current'),
                          backgroundColor: Colors.green.withOpacity(0.1),
                          labelStyle: const TextStyle(
                            color: Colors.green,
                            fontSize: 12,
                          ),
                        )
                      : IconButton(
                          icon: Icon(
                            FontAwesomeIcons.rightFromBracket.data,
                            size: 16,
                          ),
                          onPressed: () =>
                              _revokeSession(session['id'].toString()),
                          tooltip: 'Sign out',
                        ),
                );
              }),
            if (_sessions.length > 1) ...[
              const Divider(),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed:
                      _isSigningOutAll ? null : _signOutAllOtherSessions,
                  icon: _isSigningOutAll
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Icon(
                          FontAwesomeIcons.rightFromBracket.data,
                          size: 16,
                        ),
                  label: Text(
                    _isSigningOutAll
                        ? 'Signing out...'
                        : 'Sign Out All Other Devices',
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildMfaCard(ThemeData theme) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: theme.colorScheme.outline.withOpacity(0.1),
          width: 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: _isMfaEnabled
                        ? Colors.green.withOpacity(0.1)
                        : Colors.orange.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    _isMfaEnabled
                        ? FontAwesomeIcons.check.data
                        : FontAwesomeIcons.xmark.data,
                    color: _isMfaEnabled ? Colors.green : Colors.orange,
                    size: 18,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _isMfaEnabled ? '2FA Enabled' : '2FA Disabled',
                        style: theme.textTheme.titleMedium,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _isMfaEnabled
                            ? 'Your account is protected with 2FA'
                            : 'Enable 2FA for extra security',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurface.withOpacity(0.6),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isMfaEnabled ? _disableMfa : _enrollMfa,
                icon: Icon(
                  _isMfaEnabled
                      ? FontAwesomeIcons.xmark.data
                      : FontAwesomeIcons.shield.data,
                  size: 16,
                ),
                label: Text(_isMfaEnabled ? 'Disable 2FA' : 'Enable 2FA'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _isMfaEnabled
                      ? Colors.red
                      : theme.colorScheme.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDateTime(dynamic dateTime) {
    DateTime dt;
    if (dateTime is String) {
      dt = DateTime.tryParse(dateTime) ?? DateTime.now();
    } else if (dateTime is DateTime) {
      dt = dateTime;
    } else {
      return 'Unknown';
    }

    final now = DateTime.now();
    final diff = now.difference(dt);

    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }
}
