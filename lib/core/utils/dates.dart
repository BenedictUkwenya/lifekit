/// Parses a date from the API without throwing. A missing or malformed value
/// falls back to now, so one bad row can't crash a whole screen.
DateTime parseApiDate(Object? value) =>
    DateTime.tryParse('${value ?? ''}') ?? DateTime.now();
