import 'package:flutter_test/flutter_test.dart';
import 'package:lifekit_frontend/core/utils/store_rules.dart';
import 'package:lifekit_frontend/features/bookings/booking_progress.dart';

void main() {
  test('LifeKit does not take payments, so upgrades are hidden', () {
    expect(StoreRules.inAppPayments, isFalse);
    expect(StoreRules.showUpgrades, isFalse);
  });

  test('only paid wallet bookings count as money held in the app', () {
    expect(StoreRules.heldInApp({'payment_method': 'wallet', 'total_price': 10}), isTrue);
    expect(StoreRules.heldInApp({'payment_method': 'wallet', 'total_price': '15.50'}), isTrue);
    expect(StoreRules.heldInApp({'payment_method': 'direct', 'total_price': 10}), isFalse);
    expect(StoreRules.heldInApp({'payment_method': 'wallet', 'total_price': 0}), isFalse);
    expect(StoreRules.heldInApp({'total_price': 10}), isFalse); // missing field
    expect(StoreRules.heldInApp(null), isFalse);
  });

  test('booking progress knows whether money is held', () {
    Map<String, dynamic> b(String method, num price) => {
          'status': 'pending',
          'payment_method': method,
          'total_price': price,
          'scheduled_time': DateTime.now().add(const Duration(days: 2)).toIso8601String(),
        };
    expect(computeBookingProgress(b('wallet', 10), isClient: true).paidInApp, isTrue);
    expect(computeBookingProgress(b('direct', 10), isClient: true).paidInApp, isFalse);
    // Swaps are free: never "paid in app", even on old rows.
    final swap = computeBookingProgress(b('wallet', 0), isClient: true);
    expect(swap.isSwap, isTrue);
    expect(swap.paidInApp, isFalse);
  });
}
