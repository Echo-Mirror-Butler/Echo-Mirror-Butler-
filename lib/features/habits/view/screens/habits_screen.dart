import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/themes/app_theme.dart';

class HabitsScreen extends ConsumerStatefulWidget {
  const HabitsScreen({super.key});

  @override
  ConsumerState<HabitsScreen> createState() => _HabitsScreenState();
}

class _HabitsScreenState extends ConsumerState<HabitsScreen> {
  final _client = Supabase.instance.client;

  bool _loading = true;

  // All unique habits fetched from log_entries, with usage counts
  Map<String, int> _usageCounts = {};

  // Ordered list of habit names (after applying saved order)
  List<String> _habits = [];

  // Habits hidden by the user (soft-deleted)
  Set<String> _hidden = {};

  // Display aliases: habit -> renamed label
  Map<String, String> _aliases = {};

  // Custom habits added by the user (not from log entries)
  List<String> _customHabits = [];

  static const _kOrder = 'habit_display_order';
  static const _kHidden = 'hidden_habits';
  static const _kAliases = 'habit_aliases';
  static const _kCustom = 'custom_habits';

  @override
  void initState() {
    super.initState();
    _loadHabits();
  }

  Future<void> _loadHabits() async {
    setState(() => _loading = true);
    try {
      final user = _client.auth.currentUser;
      if (user == null) return;

      // Fetch all habits from log_entries
      final rows = await _client
          .from('log_entries')
          .select('habits')
          .eq('user_id', user.id);

      final Map<String, int> counts = {};
      for (final row in (rows as List)) {
        final habits = row['habits'];
        if (habits is List) {
          for (final h in habits) {
            if (h is String && h.isNotEmpty) {
              counts[h] = (counts[h] ?? 0) + 1;
            }
          }
        }
      }

      final prefs = await SharedPreferences.getInstance();
      final hiddenList = prefs.getStringList(_kHidden) ?? [];
      _hidden = hiddenList.toSet();

      final aliasesStr = prefs.getString(_kAliases);
      _aliases = aliasesStr != null
          ? Map<String, String>.from(jsonDecode(aliasesStr) as Map)
          : {};

      final customList = prefs.getStringList(_kCustom) ?? [];
      _customHabits = customList;
      for (final c in customList) {
        counts.putIfAbsent(c, () => 0);
      }

      _usageCounts = counts;

      // Apply saved order
      final savedOrder = prefs.getStringList(_kOrder);
      final allHabits = counts.keys.where((h) => !_hidden.contains(h)).toList();
      if (savedOrder != null && savedOrder.isNotEmpty) {
        final savedSet = savedOrder.toSet();
        final ordered = savedOrder.where((h) => allHabits.contains(h)).toList();
        final remaining = allHabits.where((h) => !savedSet.contains(h)).toList()
          ..sort((a, b) => (counts[b] ?? 0).compareTo(counts[a] ?? 0));
        _habits = [...ordered, ...remaining];
      } else {
        _habits = allHabits
          ..sort((a, b) => (counts[b] ?? 0).compareTo(counts[a] ?? 0));
      }
    } catch (e) {
      debugPrint('[HabitsScreen] load error: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _saveOrder() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_kOrder, _habits);
  }

  Future<void> _hideHabit(String habit) async {
    final prefs = await SharedPreferences.getInstance();
    _hidden.add(habit);
    await prefs.setStringList(_kHidden, _hidden.toList());
    setState(() => _habits.remove(habit));
  }

  Future<void> _undoHide(String habit) async {
    final prefs = await SharedPreferences.getInstance();
    _hidden.remove(habit);
    await prefs.setStringList(_kHidden, _hidden.toList());
    setState(() => _habits.insert(0, habit));
  }

  Future<void> _renameHabit(String original) async {
    final controller = TextEditingController(text: _aliases[original] ?? original);
    final result = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Rename habit'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'New name'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (result != null && result.isNotEmpty) {
      final prefs = await SharedPreferences.getInstance();
      if (result == original) {
        _aliases.remove(original);
      } else {
        _aliases[original] = result;
      }
      await prefs.setString(_kAliases, jsonEncode(_aliases));
      setState(() {});
    }
  }

  Future<void> _addCustomHabit() async {
    final controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Add habit'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'Habit name'),
          textCapitalization: TextCapitalization.sentences,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Add'),
          ),
        ],
      ),
    );
    if (result != null && result.isNotEmpty && !_habits.contains(result)) {
      final prefs = await SharedPreferences.getInstance();
      _customHabits.add(result);
      await prefs.setStringList(_kCustom, _customHabits);
      _usageCounts[result] = 0;
      setState(() => _habits.insert(0, result));
      await _saveOrder();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text('Manage Habits', style: theme.textTheme.headlineSmall),
        elevation: 0,
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addCustomHabit,
        backgroundColor: AppTheme.primaryColor,
        child: Icon(FontAwesomeIcons.plus.data, color: Colors.white, size: 18),
        tooltip: 'Add habit',
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _habits.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(FontAwesomeIcons.listCheck.data, size: 48, color: theme.colorScheme.onSurface.withValues(alpha: 0.3)),
                      const SizedBox(height: 16),
                      Text('No habits yet', style: theme.textTheme.titleMedium?.copyWith(color: theme.colorScheme.onSurface.withValues(alpha: 0.5))),
                      const SizedBox(height: 8),
                      Text('Log some entries to see your habits here', style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurface.withValues(alpha: 0.4))),
                    ],
                  ),
                )
              : ReorderableListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                  itemCount: _habits.length,
                  onReorder: (oldIndex, newIndex) {
                    setState(() {
                      if (newIndex > oldIndex) newIndex--;
                      final item = _habits.removeAt(oldIndex);
                      _habits.insert(newIndex, item);
                    });
                    _saveOrder();
                  },
                  itemBuilder: (context, index) {
                    final habit = _habits[index];
                    final displayName = _aliases[habit] ?? habit;
                    final count = _usageCounts[habit] ?? 0;

                    return Dismissible(
                      key: ValueKey(habit),
                      direction: DismissDirection.endToStart,
                      background: Container(
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsets.only(right: 20),
                        decoration: BoxDecoration(
                          color: Colors.red.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Icon(FontAwesomeIcons.trash.data, color: Colors.red, size: 18),
                      ),
                      confirmDismiss: (_) async => true,
                      onDismissed: (_) {
                        _hideHabit(habit);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('"$displayName" removed'),
                            action: SnackBarAction(
                              label: 'Undo',
                              onPressed: () => _undoHide(habit),
                            ),
                          ),
                        );
                      },
                      child: Card(
                        key: ValueKey('card_$habit'),
                        elevation: 0,
                        margin: const EdgeInsets.symmetric(vertical: 4),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                          side: BorderSide(
                            color: theme.colorScheme.outline.withValues(alpha: 0.12),
                          ),
                        ),
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                          leading: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: AppTheme.primaryColor.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(FontAwesomeIcons.star.data, size: 14, color: AppTheme.primaryColor),
                          ),
                          title: Text(displayName, style: theme.textTheme.titleSmall),
                          subtitle: Text(
                            'Used $count time${count != 1 ? 's' : ''}',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                            ),
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: Icon(FontAwesomeIcons.penToSquare.data, size: 14, color: theme.colorScheme.onSurface.withValues(alpha: 0.4)),
                                onPressed: () => _renameHabit(habit),
                                tooltip: 'Rename',
                              ),
                              ReorderableDragStartListener(
                                index: index,
                                child: Icon(FontAwesomeIcons.gripVertical.data, size: 16, color: theme.colorScheme.onSurface.withValues(alpha: 0.3)),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}
