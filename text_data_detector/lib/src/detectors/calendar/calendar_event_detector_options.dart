/// Numeric date interpretation for ambiguous dates such as `01/02/2026`.
enum NumericDateOrder {
  /// `11/06/2026` means 11 June 2026.
  dayMonthYear,

  /// `06/11/2026` means June 11 2026.
  monthDayYear,

  /// `2026/06/11` means June 11 2026.
  yearMonthDay,
}

/// Calendar event detector configuration.
final class CalendarEventDetectorOptions {
  const CalendarEventDetectorOptions({
    this.referenceDate,
    this.numericDateOrder = NumericDateOrder.dayMonthYear,
    this.minYear = 1900,
    this.maxYear = 2100,
  });

  /// Date used to resolve relative dates and time-only matches.
  ///
  /// When omitted, the detector uses `DateTime.now()` at scan time.
  final DateTime? referenceDate;

  /// Date order used for non-ISO numeric dates.
  final NumericDateOrder numericDateOrder;

  /// Lowest accepted year.
  final int minYear;

  /// Highest accepted year.
  final int maxYear;
}
