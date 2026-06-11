/// Structured value for detected calendar events.
final class CalendarEventValue {
  const CalendarEventValue({
    this.start,
    this.end,
    this.timeZone,
    this.duration,
    this.hasDate = false,
    this.hasTime = false,
    this.isAllDay = false,
  });

  /// Event start, if the detector could resolve one.
  final DateTime? start;

  /// Event end for ranges.
  final DateTime? end;

  /// Time zone label, reserved for future time-zone parsing.
  final String? timeZone;

  /// Event duration, usually derived from [start] and [end].
  final Duration? duration;

  /// Whether the source text contained an explicit date.
  final bool hasDate;

  /// Whether the source text contained an explicit time.
  final bool hasTime;

  /// Whether the source text describes an all-day date.
  final bool isAllDay;

  @override
  bool operator ==(Object other) {
    return other is CalendarEventValue &&
        other.start == start &&
        other.end == end &&
        other.timeZone == timeZone &&
        other.duration == duration &&
        other.hasDate == hasDate &&
        other.hasTime == hasTime &&
        other.isAllDay == isAllDay;
  }

  @override
  int get hashCode {
    return Object.hash(
      start,
      end,
      timeZone,
      duration,
      hasDate,
      hasTime,
      isAllDay,
    );
  }

  @override
  String toString() {
    return 'CalendarEventValue('
        'start: $start, '
        'end: $end, '
        'timeZone: $timeZone, '
        'duration: $duration, '
        'hasDate: $hasDate, '
        'hasTime: $hasTime, '
        'isAllDay: $isAllDay'
        ')';
  }
}
