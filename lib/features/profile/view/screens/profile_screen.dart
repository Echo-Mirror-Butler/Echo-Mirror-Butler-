import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/themes/app_theme.dart';
import '../../../../core/utils/error_handler.dart';
import '../../../../core/widgets/shimmer_loading.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  final _client = Supabase.instance.client;
  final _nameController = TextEditingController();

  bool _loading = true;
  bool _editing = false;
  bool _saving = false;
  bool _uploadingAvatar = false;

  String? _email;
  String? _avatarUrl;
  String? _displayName;
  String? _memberSince;
  int _totalLogs = 0;
  int _streak = 0;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    setState(() => _loading = true);
    try {
      final user = _client.auth.currentUser;
      if (user == null) return;

      _email = user.email;
      _memberSince = user.createdAt.split('T').first;

      // Fetch profile row
      final profileRes = await _client
          .from('profiles')
          .select('display_name, avatar_url')
          .eq('id', user.id)
          .maybeSingle();

      if (profileRes != null) {
        _displayName = profileRes['display_name'] as String?;
        _avatarUrl = profileRes['avatar_url'] as String?;
      }

      // Fetch log count
      final countRes = await _client
          .from('log_entries')
          .select('date')
          .eq('user_id', user.id)
          .order('date', ascending: false)
          .limit(365);

      final dates =
          (countRes as List).map((e) => e['date'] as String).toList();
      _totalLogs = dates.length;
      _streak = _calculateStreak(dates);

      _nameController.text = _displayName ?? '';
    } catch (e) {
      debugPrint('[ProfileScreen] load error: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  int _calculateStreak(List<String> dates) {
    if (dates.isEmpty) return 0;
    int streak = 0;
    DateTime cursor = DateTime.now();
    for (final d in dates) {
      final day = DateTime.tryParse(d);
      if (day == null) break;
      final diff = DateTime(cursor.year, cursor.month, cursor.day)
          .difference(DateTime(day.year, day.month, day.day))
          .inDays;
      if (diff == 0 || diff == 1) {
        streak++;
        cursor = day;
      } else {
        break;
      }
    }
    return streak;
  }

  Future<void> _saveProfile() async {
    final user = _client.auth.currentUser;
    if (user == null) return;
    setState(() => _saving = true);
    try {
      final name = _nameController.text.trim();
      await _client.auth.updateUser(UserAttributes(data: {'display_name': name}));
      await _client.from('profiles').upsert({
        'id': user.id,
        'display_name': name.isEmpty ? null : name,
      });
      setState(() {
        _displayName = name.isEmpty ? null : name;
        _editing = false;
      });
      if (mounted) ErrorHandler.showSuccess(context, 'Profile updated');
    } catch (e) {
      if (mounted) ErrorHandler.showError(context, 'Failed to save profile');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _pickAndUploadAvatar() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery, maxWidth: 512, maxHeight: 512);
    if (picked == null) return;

    final user = _client.auth.currentUser;
    if (user == null) return;

    setState(() => _uploadingAvatar = true);
    try {
      final bytes = await File(picked.path).readAsBytes();
      final ext = picked.path.split('.').last.toLowerCase();
      final path = '${user.id}/avatar.$ext';

      await _client.storage
          .from('avatars')
          .uploadBinary(path, bytes, fileOptions: FileOptions(upsert: true, contentType: 'image/$ext'));

      final url = _client.storage.from('avatars').getPublicUrl(path);
      await _client.from('profiles').upsert({'id': user.id, 'avatar_url': url});
      setState(() => _avatarUrl = '$url?t=${DateTime.now().millisecondsSinceEpoch}');
      if (mounted) ErrorHandler.showSuccess(context, 'Avatar updated');
    } catch (e) {
      if (mounted) ErrorHandler.showError(context, 'Avatar upload failed');
    } finally {
      if (mounted) setState(() => _uploadingAvatar = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text('My Profile', style: theme.textTheme.headlineSmall),
        elevation: 0,
        actions: [
          if (!_editing && !_loading)
            IconButton(
              icon: Icon(FontAwesomeIcons.penToSquare.data, size: 18),
              onPressed: () => setState(() => _editing = true),
              tooltip: 'Edit profile',
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(24),
              children: [
                // Avatar
                Center(
                  child: GestureDetector(
                    onTap: _pickAndUploadAvatar,
                    child: Stack(
                      alignment: Alignment.bottomRight,
                      children: [
                        CircleAvatar(
                          radius: 52,
                          backgroundColor: AppTheme.primaryColor.withValues(alpha: 0.15),
                          backgroundImage:
                              _avatarUrl != null ? NetworkImage(_avatarUrl!) : null,
                          child: _uploadingAvatar
                              ? const CircularProgressIndicator()
                              : (_avatarUrl == null
                                  ? Icon(FontAwesomeIcons.userAstronaut.data,
                                      size: 40, color: AppTheme.primaryColor)
                                  : null),
                        ),
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: AppTheme.primaryColor,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2),
                          ),
                          child: Icon(FontAwesomeIcons.camera.data,
                              size: 13, color: Colors.white),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Display name
                Card(
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: BorderSide(
                      color: theme.colorScheme.outline.withValues(alpha: 0.12),
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Display name', style: theme.textTheme.labelMedium?.copyWith(color: theme.colorScheme.onSurface.withValues(alpha: 0.6))),
                        const SizedBox(height: 8),
                        if (_editing)
                          Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: _nameController,
                                  decoration: const InputDecoration(
                                    hintText: 'Enter your name',
                                    border: OutlineInputBorder(),
                                    isDense: true,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              TextButton(
                                onPressed: _saving ? null : _saveProfile,
                                child: _saving
                                    ? ShimmerLoading(width: 16, height: 16)
                                    : const Text('Save'),
                              ),
                              TextButton(
                                onPressed: () {
                                  _nameController.text = _displayName ?? '';
                                  setState(() => _editing = false);
                                },
                                child: const Text('Cancel'),
                              ),
                            ],
                          )
                        else
                          Text(
                            _displayName?.isNotEmpty == true ? _displayName! : 'Not set',
                            style: theme.textTheme.titleMedium,
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Info cards
                _infoCard(theme, [
                  _infoRow(theme, FontAwesomeIcons.envelope, 'Email', _email ?? '—', Colors.blue),
                  Divider(height: 1, color: theme.colorScheme.outline.withValues(alpha: 0.1)),
                  _infoRow(theme, FontAwesomeIcons.calendarCheck, 'Member since', _memberSince ?? '—', Colors.green),
                ]),
                const SizedBox(height: 16),
                _infoCard(theme, [
                  _infoRow(theme, FontAwesomeIcons.bookOpen, 'Total logs', '$_totalLogs entries', AppTheme.primaryColor),
                  Divider(height: 1, color: theme.colorScheme.outline.withValues(alpha: 0.1)),
                  _infoRow(theme, FontAwesomeIcons.fire, 'Current streak', '$_streak day${_streak != 1 ? 's' : ''}', Colors.orange),
                ]),
              ],
            ),
    );
  }

  Widget _infoCard(ThemeData theme, List<Widget> children) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: theme.colorScheme.outline.withValues(alpha: 0.12)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: Column(children: children),
      ),
    );
  }

  Widget _infoRow(ThemeData theme, IconData icon, String label, String value, Color iconColor) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 16, color: iconColor),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurface.withValues(alpha: 0.6))),
                const SizedBox(height: 2),
                Text(value, style: theme.textTheme.titleSmall),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
