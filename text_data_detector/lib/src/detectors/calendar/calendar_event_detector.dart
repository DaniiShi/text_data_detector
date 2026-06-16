import '../../data_detector/data_detector_match.dart';
import '../../data_detector/data_detector_rule.dart';
import 'calendar_event_detector_options.dart';
import 'calendar_event_value.dart';

/// Finds date and time expressions.
final class CalendarEventDetector implements DataDetectorRule {
  const CalendarEventDetector({
    this.options = const CalendarEventDetectorOptions(),
  }) : patterns = defaultCalendarPatterns;

  /// Creates a detector using only [patterns].
  const CalendarEventDetector.custom({
    required this.patterns,
    this.options = const CalendarEventDetectorOptions(),
  });

  /// Creates a detector using default patterns plus [additionalPatterns].
  ///
  /// When [additionalPatterns] is omitted, English month-name and relative date
  /// patterns are added.
  CalendarEventDetector.extended({
    List<CalendarPattern>? additionalPatterns,
    this.options = const CalendarEventDetectorOptions(),
  }) : patterns = List<CalendarPattern>.unmodifiable([
          ...defaultCalendarPatterns,
          ...(additionalPatterns ?? defaultAdditionalCalendarPatterns),
        ]);

  /// Calendar parsing options.
  final CalendarEventDetectorOptions options;

  /// Pattern pipeline used by this detector.
  final List<CalendarPattern> patterns;

  /// Returns a detector with the same pattern pipeline and different options.
  CalendarEventDetector withOptions(CalendarEventDetectorOptions options) {
    return CalendarEventDetector.custom(
      patterns: patterns,
      options: options,
    );
  }

  /// Default calendar patterns for the MVP detector.
  static const defaultCalendarPatterns = <CalendarPattern>[
    NumericDatePattern(),
    TimeRangePattern(),
    TimePattern(),
  ];

  /// Extra calendar patterns used by [CalendarEventDetector.extended] when no
  /// custom additional patterns are supplied.
  static const defaultAdditionalCalendarPatterns = <CalendarPattern>[
    EnglishMonthNameDatePattern(),
    EnglishRelativeDatePattern(),
  ];

  @override
  List<DataDetectorMatch> detect(String text) {
    final reference = options.referenceDate ?? DateTime.now();
    final context = CalendarParsingContext(
      referenceDate: _dateOnly(reference),
      numericDateOrder: options.numericDateOrder,
      minYear: options.minYear,
      maxYear: options.maxYear,
    );

    final candidates = <CalendarCandidate>[];
    for (final pattern in patterns) {
      candidates.addAll(pattern.find(text, context));
    }

    candidates.addAll(_mergeDateRanges(text, candidates));
    candidates.addAll(_mergeDateWithFollowingTime(text, candidates));
    final resolved = _resolveOverlaps(candidates);

    return [
      for (final candidate in resolved)
        DataDetectorMatch(
          type: DataMatchType.calendarEvent,
          start: candidate.start,
          end: candidate.end,
          text: text.substring(candidate.start, candidate.end),
          normalizedText: _normalizedText(candidate),
          value: CalendarEventValue(
            start: candidate.value,
            end: candidate.endValue,
            duration: candidate.endValue?.difference(candidate.value),
            hasDate: candidate.hasDate,
            hasTime: candidate.hasTime,
            isAllDay: candidate.hasDate && !candidate.hasTime,
          ),
        ),
    ];
  }

  static List<CalendarCandidate> _mergeDateWithFollowingTime(
    String text,
    List<CalendarCandidate> candidates,
  ) {
    final dates = candidates.where((candidate) {
      return candidate.kind == CalendarCandidateKind.date;
    });
    final timeLike = candidates.where((candidate) {
      return candidate.kind == CalendarCandidateKind.time ||
          candidate.kind == CalendarCandidateKind.timeRange;
    }).toList()
      ..sort((a, b) => a.start.compareTo(b.start));

    final merged = <CalendarCandidate>[];
    for (final date in dates) {
      for (final time in timeLike) {
        if (time.start < date.end) {
          continue;
        }
        final gap = text.substring(date.end, time.start);
        if (!_isMergeGap(gap)) {
          if (gap.trim().isNotEmpty) {
            break;
          }
          continue;
        }

        final start = _combineDateAndTime(date.value, time.value);
        final end = time.endValue == null
            ? null
            : _combineDateAndTime(date.value, time.endValue!);
        merged.add(
          CalendarCandidate(
            kind: end == null
                ? CalendarCandidateKind.dateTime
                : CalendarCandidateKind.dateTimeRange,
            start: date.start,
            end: time.end,
            text: text.substring(date.start, time.end),
            value: start,
            endValue: end,
            hasDate: true,
            hasTime: true,
          ),
        );
        break;
      }
    }
    return merged;
  }

  static List<CalendarCandidate> _mergeDateRanges(
    String text,
    List<CalendarCandidate> candidates,
  ) {
    final dates = candidates.where((candidate) {
      return candidate.kind == CalendarCandidateKind.date;
    }).toList()
      ..sort((a, b) => a.start.compareTo(b.start));

    final merged = <CalendarCandidate>[];
    for (var i = 0; i < dates.length - 1; i++) {
      final startDate = dates[i];
      final endDate = dates[i + 1];
      if (endDate.start < startDate.end) {
        continue;
      }
      final gap = text.substring(startDate.end, endDate.start);
      if (!_isDateRangeGap(gap) || !endDate.value.isAfter(startDate.value)) {
        continue;
      }

      merged.add(
        CalendarCandidate(
          kind: CalendarCandidateKind.dateRange,
          start: startDate.start,
          end: endDate.end,
          text: text.substring(startDate.start, endDate.end),
          value: startDate.value,
          endValue: endDate.value,
          hasDate: true,
          hasTime: false,
        ),
      );
    }
    return merged;
  }

  static bool _isMergeGap(String gap) {
    return RegExp(
      r'^\s*(?:(?:,\s*)?at\s*|,\s*)?$',
      caseSensitive: false,
    ).hasMatch(gap);
  }

  static bool _isDateRangeGap(String gap) {
    return RegExp(r'^\s*(?:-|–|—)\s*$').hasMatch(gap);
  }

  static List<CalendarCandidate> _resolveOverlaps(
    List<CalendarCandidate> candidates,
  ) {
    final sorted = [...candidates]..sort((a, b) {
        final byStart = a.start.compareTo(b.start);
        if (byStart != 0) {
          return byStart;
        }
        final byPriority = _priority(b.kind).compareTo(_priority(a.kind));
        if (byPriority != 0) {
          return byPriority;
        }
        return (b.end - b.start).compareTo(a.end - a.start);
      });

    final result = <CalendarCandidate>[];
    for (final candidate in sorted) {
      final overlappingIndex = result.indexWhere((current) {
        return candidate.start < current.end && candidate.end > current.start;
      });
      if (overlappingIndex == -1) {
        result.add(candidate);
        result.sort((a, b) => a.start.compareTo(b.start));
        continue;
      }

      final current = result[overlappingIndex];
      if (_isBetter(candidate, current)) {
        result[overlappingIndex] = candidate;
        result.sort((a, b) => a.start.compareTo(b.start));
      }
    }
    return result;
  }

  static bool _isBetter(
      CalendarCandidate candidate, CalendarCandidate current) {
    final candidatePriority = _priority(candidate.kind);
    final currentPriority = _priority(current.kind);
    if (candidatePriority != currentPriority) {
      return candidatePriority > currentPriority;
    }

    return candidate.end - candidate.start > current.end - current.start;
  }

  static int _priority(CalendarCandidateKind kind) {
    return switch (kind) {
      CalendarCandidateKind.dateTimeRange => 50,
      CalendarCandidateKind.dateTime => 40,
      CalendarCandidateKind.timeRange => 30,
      CalendarCandidateKind.dateRange => 25,
      CalendarCandidateKind.date => 20,
      CalendarCandidateKind.time => 10,
    };
  }

  static String _normalizedText(CalendarCandidate candidate) {
    final start = candidate.hasTime
        ? _formatDateTime(candidate.value)
        : _formatDate(candidate.value);
    final end = candidate.endValue;
    if (end == null) {
      return start;
    }
    final formattedEnd =
        candidate.hasTime ? _formatDateTime(end) : _formatDate(end);
    return '$start/$formattedEnd';
  }
}

/// A pattern that finds calendar candidates in text.
abstract interface class CalendarPattern {
  /// Returns candidates detected by this pattern.
  List<CalendarCandidate> find(
    String text,
    CalendarParsingContext context,
  );
}

/// Shared parsing configuration for calendar patterns.
final class CalendarParsingContext {
  const CalendarParsingContext({
    required this.referenceDate,
    required this.numericDateOrder,
    required this.minYear,
    required this.maxYear,
  });

  /// Reference date for relative dates and time-only matches.
  final DateTime referenceDate;

  /// Date order for non-ISO numeric dates.
  final NumericDateOrder numericDateOrder;

  /// Lowest accepted year.
  final int minYear;

  /// Highest accepted year.
  final int maxYear;
}

/// Calendar candidate kind.
enum CalendarCandidateKind {
  date,
  time,
  dateTime,
  dateRange,
  timeRange,
  dateTimeRange,
}

/// Internal calendar candidate.
final class CalendarCandidate {
  const CalendarCandidate({
    required this.kind,
    required this.start,
    required this.end,
    required this.text,
    required this.value,
    this.endValue,
    required this.hasDate,
    required this.hasTime,
  });

  /// Candidate kind.
  final CalendarCandidateKind kind;

  /// Inclusive start offset in the source string.
  final int start;

  /// Exclusive end offset in the source string.
  final int end;

  /// Original candidate text.
  final String text;

  /// Start date/time value.
  final DateTime value;

  /// End date/time value for ranges.
  final DateTime? endValue;

  /// Whether this candidate has an explicit date.
  final bool hasDate;

  /// Whether this candidate has an explicit time.
  final bool hasTime;
}

/// Finds numeric dates such as `11.06.2026` and `11/06/2026`.
final class NumericDatePattern implements CalendarPattern {
  const NumericDatePattern();

  static final RegExp _pattern = RegExp(
    r'(?<![\d.])(\d{1,4})([./])(\d{1,2})\2(\d{1,4})(?!\d)',
  );

  @override
  List<CalendarCandidate> find(String text, CalendarParsingContext context) {
    final candidates = <CalendarCandidate>[];
    for (final match in _pattern.allMatches(text)) {
      final first = int.parse(match.group(1)!);
      final firstText = match.group(1)!;
      final second = int.parse(match.group(3)!);
      final third = int.parse(match.group(4)!);
      final thirdText = match.group(4)!;
      final yearText = context.numericDateOrder == NumericDateOrder.yearMonthDay
          ? firstText
          : thirdText;
      if (!_hasSupportedNumericYearLength(yearText)) {
        continue;
      }
      final date = switch (context.numericDateOrder) {
        NumericDateOrder.dayMonthYear =>
          _dateFromParts(third, second, first, context),
        NumericDateOrder.monthDayYear =>
          _dateFromParts(third, first, second, context),
        NumericDateOrder.yearMonthDay =>
          _dateFromParts(first, second, third, context),
      };
      if (date == null) {
        continue;
      }
      candidates.add(_dateCandidate(match, date));
    }
    return candidates;
  }
}

bool _hasSupportedNumericYearLength(String text) {
  return text.length == 4;
}

/// Finds English month-name dates such as `June 11, 2026` and `June 11`.
final class EnglishMonthNameDatePattern implements CalendarPattern {
  const EnglishMonthNameDatePattern();

  static final RegExp _monthDayYearPattern = RegExp(
    r'\b([A-Za-z]+)\s+(\d{1,2})(?:st|nd|rd|th)?(?:(?:,\s*|\s+)(\d{4})\b)?',
    caseSensitive: false,
  );

  static final RegExp _dayMonthYearPattern = RegExp(
    r'\b(\d{1,2})(?:st|nd|rd|th)?\s+([A-Za-z]+)(?:(?:,\s*|\s+)(\d{4})\b)?',
    caseSensitive: false,
  );

  static const _months = <String, int>{
    'jan': 1,
    'january': 1,
    'feb': 2,
    'february': 2,
    'mar': 3,
    'march': 3,
    'apr': 4,
    'april': 4,
    'may': 5,
    'jun': 6,
    'june': 6,
    'jul': 7,
    'july': 7,
    'aug': 8,
    'august': 8,
    'sep': 9,
    'sept': 9,
    'september': 9,
    'oct': 10,
    'october': 10,
    'nov': 11,
    'november': 11,
    'dec': 12,
    'december': 12,
  };

  @override
  List<CalendarCandidate> find(String text, CalendarParsingContext context) {
    final candidates = <CalendarCandidate>[];
    for (final match in _monthDayYearPattern.allMatches(text)) {
      final month = _months[match.group(1)!.toLowerCase()];
      if (month == null) {
        continue;
      }
      final date = _dateFromParts(
        _parseMonthNameYear(match.group(3), context),
        month,
        int.parse(match.group(2)!),
        context,
      );
      if (date != null) {
        candidates.add(_dateCandidate(match, date));
      }
    }
    for (final match in _dayMonthYearPattern.allMatches(text)) {
      final month = _months[match.group(2)!.toLowerCase()];
      if (month == null) {
        continue;
      }
      final date = _dateFromParts(
        _parseMonthNameYear(match.group(3), context),
        month,
        int.parse(match.group(1)!),
        context,
      );
      if (date != null) {
        candidates.add(_dateCandidate(match, date));
      }
    }
    return candidates;
  }
}

int _parseMonthNameYear(String? yearText, CalendarParsingContext context) {
  return yearText == null ? context.referenceDate.year : int.parse(yearText);
}

/// Finds English relative dates: `today`, `tomorrow`, and `3 days ago`.
final class EnglishRelativeDatePattern implements CalendarPattern {
  const EnglishRelativeDatePattern();

  static final RegExp _namedPattern = RegExp(
    r'\b(today|tomorrow|yesterday)\b',
    caseSensitive: false,
  );

  static final RegExp _agoPattern = RegExp(
    r'\b(\d+)\s+(day|days|week|weeks)\s+ago\b',
    caseSensitive: false,
  );

  @override
  List<CalendarCandidate> find(String text, CalendarParsingContext context) {
    final candidates = <CalendarCandidate>[
      for (final match in _namedPattern.allMatches(text))
        _dateCandidate(match, _namedRelativeDate(match, context)),
    ];

    for (final match in _agoPattern.allMatches(text)) {
      final amount = int.parse(match.group(1)!);
      final unit = match.group(2)!.toLowerCase();
      final days = unit.startsWith('week') ? amount * 7 : amount;
      candidates.add(
        _dateCandidate(
          match,
          context.referenceDate.subtract(Duration(days: days)),
        ),
      );
    }
    return candidates;
  }

  static DateTime _namedRelativeDate(
    RegExpMatch match,
    CalendarParsingContext context,
  ) {
    return switch (match.group(1)!.toLowerCase()) {
      'tomorrow' => context.referenceDate.add(const Duration(days: 1)),
      'yesterday' => context.referenceDate.subtract(const Duration(days: 1)),
      _ => context.referenceDate,
    };
  }
}

/// Finds time-only expressions such as `18:30`, `6 PM`, and `6:30pm`.
final class TimePattern implements CalendarPattern {
  const TimePattern();

  static final RegExp _pattern = RegExp(
    r'(?<![\d:])(\d{1,2})(?::(\d{2}))?(?:\s*(am|pm))?(?![\d:])',
    caseSensitive: false,
  );

  @override
  List<CalendarCandidate> find(String text, CalendarParsingContext context) {
    final candidates = <CalendarCandidate>[];
    for (final match in _pattern.allMatches(text)) {
      final hasMinutes = match.group(2) != null;
      final meridiem = match.group(3);
      if (!hasMinutes && meridiem == null) {
        continue;
      }
      if (!_hasTimeBoundary(text, match.start, match.end)) {
        continue;
      }
      final parsed = _parseTime(
        hourText: match.group(1)!,
        minuteText: match.group(2),
        meridiem: meridiem,
      );
      if (parsed == null) {
        continue;
      }
      final value = _combineDateAndTime(context.referenceDate, parsed);
      candidates.add(
        CalendarCandidate(
          kind: CalendarCandidateKind.time,
          start: match.start,
          end: match.end,
          text: match.group(0)!,
          value: value,
          hasDate: false,
          hasTime: true,
        ),
      );
    }
    return candidates;
  }
}

/// Finds time ranges such as `18:00-19:00` and `6 PM - 7 PM`.
final class TimeRangePattern implements CalendarPattern {
  const TimeRangePattern();

  static final RegExp _pattern = RegExp(
    r'(?<![\d:])(\d{1,2})(?::(\d{2}))?\s*(am|pm)?\s*-\s*(\d{1,2})(?::(\d{2}))?\s*(am|pm)?(?![\d:])',
    caseSensitive: false,
  );

  @override
  List<CalendarCandidate> find(String text, CalendarParsingContext context) {
    final candidates = <CalendarCandidate>[];
    for (final match in _pattern.allMatches(text)) {
      final firstHasMinutes = match.group(2) != null;
      final secondHasMinutes = match.group(5) != null;
      final firstMeridiem = match.group(3);
      final secondMeridiem = match.group(6);
      if ((!firstHasMinutes && firstMeridiem == null) ||
          (!secondHasMinutes && secondMeridiem == null)) {
        continue;
      }
      if (!_hasTimeBoundary(text, match.start, match.end)) {
        continue;
      }

      final startTime = _parseTime(
        hourText: match.group(1)!,
        minuteText: match.group(2),
        meridiem: firstMeridiem ?? secondMeridiem,
      );
      final endTime = _parseTime(
        hourText: match.group(4)!,
        minuteText: match.group(5),
        meridiem: secondMeridiem ?? firstMeridiem,
      );
      if (startTime == null || endTime == null) {
        continue;
      }

      final start = _combineDateAndTime(context.referenceDate, startTime);
      final end = _combineDateAndTime(context.referenceDate, endTime);
      if (!end.isAfter(start)) {
        continue;
      }
      candidates.add(
        CalendarCandidate(
          kind: CalendarCandidateKind.timeRange,
          start: match.start,
          end: match.end,
          text: match.group(0)!,
          value: start,
          endValue: end,
          hasDate: false,
          hasTime: true,
        ),
      );
    }
    return candidates;
  }
}

CalendarCandidate _dateCandidate(RegExpMatch match, DateTime date) {
  return CalendarCandidate(
    kind: CalendarCandidateKind.date,
    start: match.start,
    end: match.end,
    text: match.group(0)!,
    value: date,
    hasDate: true,
    hasTime: false,
  );
}

DateTime? _dateFromParts(
  int year,
  int month,
  int day,
  CalendarParsingContext context,
) {
  if (year < context.minYear || year > context.maxYear) {
    return null;
  }
  if (month < 1 || month > 12 || day < 1 || day > 31) {
    return null;
  }
  final date = DateTime(year, month, day);
  if (date.year != year || date.month != month || date.day != day) {
    return null;
  }
  return date;
}

DateTime? _parseTime({
  required String hourText,
  String? minuteText,
  String? meridiem,
}) {
  var hour = int.parse(hourText);
  final minute = minuteText == null ? 0 : int.parse(minuteText);
  if (minute > 59) {
    return null;
  }

  final lowerMeridiem = meridiem?.toLowerCase();
  if (lowerMeridiem != null) {
    if (hour < 1 || hour > 12) {
      return null;
    }
    if (lowerMeridiem == 'pm' && hour != 12) {
      hour += 12;
    } else if (lowerMeridiem == 'am' && hour == 12) {
      hour = 0;
    }
  } else if (hour > 23) {
    return null;
  }

  return DateTime(0, 1, 1, hour, minute);
}

bool _hasTimeBoundary(String text, int start, int end) {
  final before = start == 0 ? null : text.codeUnitAt(start - 1);
  final after = end == text.length ? null : text.codeUnitAt(end);
  return !_isAsciiLetter(before) && !_isAsciiLetter(after);
}

bool _isAsciiLetter(int? codeUnit) {
  if (codeUnit == null) {
    return false;
  }
  return (codeUnit >= 0x41 && codeUnit <= 0x5a) ||
      (codeUnit >= 0x61 && codeUnit <= 0x7a);
}

DateTime _dateOnly(DateTime value) {
  return DateTime(value.year, value.month, value.day);
}

DateTime _combineDateAndTime(DateTime date, DateTime time) {
  return DateTime(date.year, date.month, date.day, time.hour, time.minute);
}

String _formatDate(DateTime value) {
  return '${value.year.toString().padLeft(4, '0')}-'
      '${value.month.toString().padLeft(2, '0')}-'
      '${value.day.toString().padLeft(2, '0')}';
}

String _formatDateTime(DateTime value) {
  return '${_formatDate(value)}T'
      '${value.hour.toString().padLeft(2, '0')}:'
      '${value.minute.toString().padLeft(2, '0')}:'
      '${value.second.toString().padLeft(2, '0')}';
}
