import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/themes/app_theme.dart';
import '../../viewmodel/providers/gift_provider.dart';

/// A compact gift button displayed on mood pins and video posts.
/// Tapping it navigates to the gift screen for the given user.
class GiftButtonWidget extends ConsumerWidget {
  const GiftButtonWidget({
    super.key,
    required this.recipientUserId,
    this.compact = false,
  });

  final int recipientUserId;
  final bool compact;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final balance = ref.watch(giftProvider).echoBalance;

    if (compact) {
      return IconButton(
        icon: const Icon(Icons.card_giftcard_rounded),
        color: AppTheme.primaryColor,
        tooltip: 'Send ECHO Gift',
        onPressed: () => _openGiftScreen(context),
      );
    }

    return OutlinedButton.icon(
      onPressed: () => _openGiftScreen(context),
      icon: const Icon(Icons.card_giftcard_rounded, size: 18),
      label: Text('Gift ECHO  •  ${balance.toStringAsFixed(0)} available'),
      style: OutlinedButton.styleFrom(
        foregroundColor: AppTheme.primaryColor,
        side: const BorderSide(color: AppTheme.primaryColor),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
    );
  }

  void _openGiftScreen(BuildContext context) {
    context.push('/gift/$recipientUserId');
  }
}
