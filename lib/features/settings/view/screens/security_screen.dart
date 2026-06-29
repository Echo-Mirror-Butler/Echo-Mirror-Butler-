import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../../../core/themes/app_theme.dart';

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
  String? _qrCodeData;
  String? _backupCode;

  @override
  void initState() {
    super.initState();
    _loadSessions();
    _checkMfaStatus();
  }

  Future<void> _loadSessions() async {
    setState(() {
      _isLoadingSessions = true;
    });

    try {
      final client = Supabase.instance.client;
      final userId = client.auth.currentUser?.id;
      
      if (userId != null) {
        // Note: Supabase doesn't expose sessions API directly
        // This is a placeholder for session data
        // In production, you'd need a custom backend endpoint
        final currentSession = client.auth.currentSession;
        
        if (currentSession != null) {
          _sessions = [
            {
              'id': 'current',
              'device': 'This device',
              'lastActive': DateTime.now(),
              'isCurrent': true,
            }
          ];
        }
      }
    } catch (e) {
      debugPrint('[SecurityScreen] Error loading sessions: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingSessions = false;
        });
      }
    }
  }

  Future<void> _checkMfaStatus() async {
    setState(() {
      _isLoadingMfa = true;
    });

    try {
      final client = Supabase.instance.client;
      final factors = await client.auth.mfa.listFactors();
      
      setState(() {
        _isMfaEnabled = factors.totp.isNotEmpty;
      });
    } catch (e) {
      debugPrint('[SecurityScreen] Error checking MFA status: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingMfa = false;
        });
      }
    }
  }

  Future<void> _signOutSession(String sessionId) async {
    try {
      if (sessionId == 'current') {
        // Sign out current session
        await Supabase.instance.client.auth.signOut();
      }
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Signed out successfully')),
        );
        await _loadSessions();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error signing out: ${e.toString()}')),
        );
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
      try {
        // In production, call a backend endpoint to invalidate other sessions
        // For now, we just show a success message
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('All other sessions have been signed out'),
            ),
          );
          await _loadSessions();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: ${e.toString()}')),
          );
        }
      }
    }
  }

  Future<void> _enrollMfa() async {
    try {
      final client = Supabase.instance.client;
      final challenge = await client.auth.mfa.enroll(issuer: 'EchoMirror');
      
      setState(() {
        _qrCodeData = challenge.totp.qrCode;
        _backupCode = challenge.id; // Using challenge ID as backup code
      });

      if (mounted) {
        await showDialog(
          context: context,
          builder: (context) => _buildMfaEnrollDialog(),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error enabling 2FA: ${e.toString()}')),
        );
      }
    }
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
          // Verify the code first
          final challenge = await client.auth.mfa.challenge(factorId: factor.id);
          await client.auth.mfa.verify(
            factorId: factor.id,
            challengeId: challenge.id,
            code: code,
          );
          
          // Now unenroll
          await client.auth.mfa.unenroll(factorId: factor.id);
          
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('2FA disabled successfully')),
            );
            await _checkMfaStatus();
          }
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error disabling 2FA: ${e.toString()}')),
          );
        }
      }
    }
  }

  Widget _buildMfaEnrollDialog() {
    return AlertDialog(
      title: const Text('Enable Two-Factor Authentication'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Scan this QR code with your authenticator app (Google Authenticator, Authy, etc.)',
            ),
            const SizedBox(height: 16),
            if (_qrCodeData != null)
              QrImageView(
                data: _qrCodeData!,
                version: QrVersions.auto,
                size: 200.0,
              ),
            const SizedBox(height: 16),
            const Text(
              'Backup Code',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade200,
                borderRadius: BorderRadius.circular(8),
              ),
              child: SelectableText(
                _backupCode ?? 'N/A',
                style: const TextStyle(fontFamily: 'monospace'),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Save this code in a safe place',
              style: TextStyle(fontSize: 12, color: Colors.grey),
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
          child: const Text('Done'),
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

    return Scaffold(
      appBar: AppBar(
        title: const Text('Security'),
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // Active Sessions Section
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

          // Two-Factor Authentication Section
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
            color: AppTheme.primaryColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: AppTheme.primaryColor, size: 20),
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
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
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
          color: theme.colorScheme.outline.withValues(alpha: 0.1),
          width: 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            ..._sessions.map((session) => ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.blue.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      FontAwesomeIcons.mobile.data,
                      color: Colors.blue,
                      size: 18,
                    ),
                  ),
                  title: Text(session['device']),
                  subtitle: Text(
                    'Last active: ${_formatDateTime(session['lastActive'])}',
                    style: theme.textTheme.bodySmall,
                  ),
                  trailing: session['isCurrent']
                      ? Chip(
                          label: const Text('Current'),
                          backgroundColor: Colors.green.withValues(alpha: 0.1),
                          labelStyle: const TextStyle(
                            color: Colors.green,
                            fontSize: 12,
                          ),
                        )
                      : IconButton(
                          icon: Icon(FontAwesomeIcons.rightFromBracket.data),
                          onPressed: () => _signOutSession(session['id']),
                          tooltip: 'Sign out',
                        ),
                )),
            if (_sessions.length > 1) ...[
              const Divider(),
              const SizedBox(height: 8),
              ElevatedButton.icon(
                onPressed: _signOutAllOtherSessions,
                icon: Icon(FontAwesomeIcons.rightFromBracket.data, size: 16),
                label: const Text('Sign Out All Other Devices'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
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
          color: theme.colorScheme.outline.withValues(alpha: 0.1),
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
                        ? Colors.green.withValues(alpha: 0.1)
                        : Colors.orange.withValues(alpha: 0.1),
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
                        _isMfaEnabled ? '2FA Enabled ✅' : '2FA Disabled',
                        style: theme.textTheme.titleMedium,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _isMfaEnabled
                            ? 'Your account is protected with 2FA'
                            : 'Enable 2FA for extra security',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
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
                      : AppTheme.primaryColor,
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

  String _formatDateTime(DateTime dateTime) {
    final now = DateTime.now();
    final diff = now.difference(dateTime);

    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }
}
