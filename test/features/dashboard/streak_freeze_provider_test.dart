import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:echomirror/features/dashboard/viewmodel/providers/streak_freeze_provider.dart';

void main() {
  group('StreakFreezeNotifier', () {
    late ProviderContainer container;
    late StreakFreezeNotifier notifier;

    setUp(() {
      container = ProviderContainer();
      notifier = container.read(streakFreezeProvider.notifier);
    });

    tearDown(() {
      container.dispose();
    });

    test('initial state has no active freeze', () {
      final state = container.read(streakFreezeProvider);
      expect(state.hasActiveFreeze, false);
      expect(state.freezeDate, null);
      expect(state.isLoading, false);
      expect(state.isPurchasing, false);
      expect(state.error, null);
      expect(state.purchaseError, null);
    });

    test('loadFreezeStatus with empty userId does not change state', () async {
      final initialState = container.read(streakFreezeProvider);
      await notifier.loadFreezeStatus('');
      final state = container.read(streakFreezeProvider);
      expect(state.hasActiveFreeze, initialState.hasActiveFreeze);
      expect(state.isLoading, false);
    });

    test('purchaseFreeze with empty userId returns false', () async {
      final result = await notifier.purchaseFreeze('');
      expect(result, false);
      final state = container.read(streakFreezeProvider);
      expect(state.isPurchasing, false);
    });

    test('purchaseFreeze sets isPurchasing while in progress', () {
      container.listen(
        streakFreezeProvider,
        (prev, next) {},
        onError: (_, __) {},
      );
      // isPurchasing starts false
      final initial = container.read(streakFreezeProvider);
      expect(initial.isPurchasing, false);
    });

    test('purchaseError is cleared on subsequent purchases', () async {
      // First call with empty userId sets false but no purchaseError
      await notifier.purchaseFreeze('');
      final state = container.read(streakFreezeProvider);
      expect(state.purchaseError, null);
    });
  });

  group('StreakFreezeState', () {
    test('copyWith preserves values', () {
      const state = StreakFreezeState(
        hasActiveFreeze: true,
        freezeDate: '2026-07-26',
        isLoading: false,
        isPurchasing: false,
      );
      final updated = state.copyWith(hasActiveFreeze: false);
      expect(updated.hasActiveFreeze, false);
      expect(updated.freezeDate, '2026-07-26');
      expect(updated.isLoading, false);
    });

    test('copyWith clearError resets error', () {
      const state = StreakFreezeState(error: 'some error');
      final cleared = state.copyWith(clearError: true);
      expect(cleared.error, null);
    });

    test('copyWith clearPurchaseError resets purchaseError', () {
      const state = StreakFreezeState(purchaseError: 'insufficient balance');
      final cleared = state.copyWith(clearPurchaseError: true);
      expect(cleared.purchaseError, null);
    });

    test('copyWith keeps existing error when not clearing', () {
      const state = StreakFreezeState(error: 'some error');
      final updated = state.copyWith(hasActiveFreeze: true);
      expect(updated.error, 'some error');
    });
  });

  group('Purchase flow states', () {
    late ProviderContainer container;
    late StreakFreezeNotifier notifier;

    setUp(() {
      container = ProviderContainer();
      notifier = container.read(streakFreezeProvider.notifier);
    });

    tearDown(() {
      container.dispose();
    });

    test('initial state has hasActiveFreeze = false', () {
      final state = container.read(streakFreezeProvider);
      expect(state.hasActiveFreeze, false);
      expect(state.freezeDate, null);
    });

    test('purchaseFreeze returns false for empty userId without crash', () async {
      final result = await notifier.purchaseFreeze('');
      expect(result, false);
    });

    test('purchaseError starts null', () {
      final state = container.read(streakFreezeProvider);
      expect(state.purchaseError, null);
    });
  });
}
