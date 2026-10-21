import 'package:flutter_test/flutter_test.dart';
import 'package:lifekit_frontend/core/services/api_service.dart';
import 'package:lifekit_frontend/core/utils/error_handler.dart';
import 'package:lifekit_frontend/features/bookings/booking_progress.dart';

void main() {
  final now = DateTime(2026, 10, 21, 12);
  Map<String, dynamic> booking(String status, {
    DateTime? at,
    bool client = false,
    bool provider = false,
    num price = 50,
  }) =>
      {
        'status': status,
        'scheduled_time': (at ?? now).toUtc().toIso8601String(),
        'client_confirmed': client,
        'provider_confirmed': provider,
        'total_price': price,
      };

  group('computeBookingProgress', () {
    test('pending → waiting on acceptance', () {
      final p = computeBookingProgress(booking('pending'), isClient: true, now: now);
      expect(p.phase, BookingPhase.requested);
      expect(p.isDone(BookingStep.requested), isTrue);
      expect(p.isCurrent(BookingStep.confirmed), isTrue);
    });

    test('confirmed in the future → upcoming, service day current', () {
      final p = computeBookingProgress(
        booking('confirmed', at: now.add(const Duration(days: 2))),
        isClient: true,
        now: now,
      );
      expect(p.phase, BookingPhase.upcoming);
      expect(p.isCurrent(BookingStep.serviceDay), isTrue);
      expect(p.myActionNeeded, isFalse);
    });

    test('time reached → my confirmation needed', () {
      final p = computeBookingProgress(
        booking('confirmed', at: now.subtract(const Duration(hours: 1))),
        isClient: true,
        now: now,
      );
      expect(p.phase, BookingPhase.awaitingConfirmation);
      expect(p.myActionNeeded, isTrue);
    });

    test('I confirmed, other has not → waiting, no action for me', () {
      final p = computeBookingProgress(
        booking('confirmed', at: now.subtract(const Duration(hours: 1)), provider: true),
        isClient: false,
        now: now,
      );
      expect(p.iConfirmed, isTrue);
      expect(p.myActionNeeded, isFalse);
    });

    test('over 24h past and unconfirmed → overdue', () {
      final p = computeBookingProgress(
        booking('confirmed', at: now.subtract(const Duration(days: 2))),
        isClient: true,
        now: now,
      );
      expect(p.phase, BookingPhase.overdue);
    });

    test('completed → every step done; zero price is a swap', () {
      final p = computeBookingProgress(booking('completed', price: 0), isClient: true, now: now);
      expect(p.phase, BookingPhase.completed);
      expect(BookingStep.values.every(p.isDone), isTrue);
      expect(p.isSwap, isTrue);
    });

    test('disputed and cancelled phases', () {
      expect(computeBookingProgress(booking('disputed'), isClient: true, now: now).phase,
          BookingPhase.disputed);
      expect(computeBookingProgress(booking('cancelled'), isClient: true, now: now).phase,
          BookingPhase.cancelled);
    });
  });

  group('classifyError', () {
    test('maps common failures', () {
      expect(classifyError(Exception('NO_INTERNET')), AppErrorKind.noInternet);
      expect(classifyError(UserFriendlyTimeoutException()), AppErrorKind.timeout);
      expect(classifyError(ApiException(402, 'Insufficient wallet balance.')),
          AppErrorKind.insufficientFunds);
      expect(classifyError(ApiException(500, 'boom')), AppErrorKind.server);
      expect(classifyError(Exception('Invalid login credentials')),
          AppErrorKind.wrongCredentials);
    });

    test('friendlyError hides technical noise but keeps human messages', () {
      expect(friendlyError(Exception('Price does not match the service.')),
          'Price does not match the service.');
      expect(friendlyError("type 'Null' is not a subtype of type 'String'"),
          'Something went wrong. Please try again.');
    });
  });
}
