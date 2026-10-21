/// Pure, testable mapping from a booking record to what the tracking UI shows.
library;

enum BookingPhase {
  /// Client sent the request; provider hasn't accepted yet.
  requested,

  /// Accepted and the service date is still ahead.
  upcoming,

  /// Service time reached/passed — both sides need to confirm.
  awaitingConfirmation,

  /// Confirmed and past the scheduled time by a long margin — nudge to act.
  overdue,

  completed,
  disputed,
  cancelled,
}

/// The five steps of the timeline, in order.
enum BookingStep { requested, confirmed, serviceDay, bothConfirm, paidOut }

class BookingProgress {
  final BookingPhase phase;

  /// Index into [BookingStep.values] of the step currently in progress.
  /// Steps before it are done. Equals `BookingStep.values.length` when all done.
  final int currentStep;
  final bool iConfirmed;
  final bool otherConfirmed;
  final bool isSwap;
  final DateTime? scheduledAt;

  const BookingProgress({
    required this.phase,
    required this.currentStep,
    required this.iConfirmed,
    required this.otherConfirmed,
    required this.isSwap,
    required this.scheduledAt,
  });

  /// True when the viewer must do something (confirm) right now.
  bool get myActionNeeded =>
      !iConfirmed &&
      (phase == BookingPhase.awaitingConfirmation || phase == BookingPhase.overdue);

  bool isDone(BookingStep s) => s.index < currentStep;
  bool isCurrent(BookingStep s) => s.index == currentStep;
}

BookingProgress computeBookingProgress(
  Map booking, {
  required bool isClient,
  DateTime? now,
}) {
  now ??= DateTime.now();
  final status = '${booking['status'] ?? ''}'.toLowerCase();
  final scheduledAt = DateTime.tryParse('${booking['scheduled_time'] ?? ''}')?.toLocal();
  final clientOk = booking['client_confirmed'] == true;
  final providerOk = booking['provider_confirmed'] == true;
  final iConfirmed = isClient ? clientOk : providerOk;
  final otherConfirmed = isClient ? providerOk : clientOk;
  final isSwap = (num.tryParse('${booking['total_price']}') ?? 0) == 0;

  BookingProgress make(BookingPhase phase, BookingStep step, {bool allDone = false}) =>
      BookingProgress(
        phase: phase,
        currentStep: allDone ? BookingStep.values.length : step.index,
        iConfirmed: iConfirmed,
        otherConfirmed: otherConfirmed,
        isSwap: isSwap,
        scheduledAt: scheduledAt,
      );

  switch (status) {
    case 'completed':
      return make(BookingPhase.completed, BookingStep.paidOut, allDone: true);
    case 'disputed':
      return make(BookingPhase.disputed, BookingStep.bothConfirm);
    case 'cancelled':
    case 'canceled':
    case 'rejected':
    case 'declined':
      return make(BookingPhase.cancelled, BookingStep.confirmed);
    case 'pending':
      return make(BookingPhase.requested, BookingStep.confirmed);
  }

  // confirmed / accepted / anything active
  final timeReached = scheduledAt == null || !scheduledAt.isAfter(now);
  if (!timeReached && !iConfirmed && !otherConfirmed) {
    return make(BookingPhase.upcoming, BookingStep.serviceDay);
  }
  final overdue = scheduledAt != null &&
      now.difference(scheduledAt) > const Duration(hours: 24) &&
      !(clientOk && providerOk);
  return make(
    overdue || booking['is_overdue'] == true
        ? BookingPhase.overdue
        : BookingPhase.awaitingConfirmation,
    BookingStep.bothConfirm,
  );
}
