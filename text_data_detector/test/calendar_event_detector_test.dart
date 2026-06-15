import 'package:test/test.dart';
import 'package:text_data_detector/text_data_detector.dart';

void main() {
  group('CalendarEventDetector', () {
    final referenceDate = DateTime(2026, 6, 11, 12, 0);

    DataDetector detector({
      CalendarEventDetectorOptions options =
          const CalendarEventDetectorOptions(),
      List<CalendarPattern>? calendarPatterns,
      bool includeBuiltIns = false,
    }) {
      final calendarOptions = CalendarEventDetectorOptions(
        referenceDate: options.referenceDate ?? referenceDate,
        numericDateOrder: options.numericDateOrder,
        minYear: options.minYear,
        maxYear: options.maxYear,
      );
      return DataDetector(
        baseRules: includeBuiltIns ? null : const [],
        additionalRules: [
          if (calendarPatterns == null)
            CalendarEventDetector(options: calendarOptions)
          else
            CalendarEventDetector.custom(
              options: calendarOptions,
              patterns: calendarPatterns,
            ),
        ],
      );
    }

    DataDetectorMatch singleCalendarMatch(
      String text, {
      CalendarEventDetectorOptions options =
          const CalendarEventDetectorOptions(),
      List<CalendarPattern>? calendarPatterns,
      bool includeBuiltIns = false,
    }) {
      final matches = detector(
        options: options,
        calendarPatterns: calendarPatterns,
        includeBuiltIns: includeBuiltIns,
      ).matches(text);
      final calendarMatches = matches
          .where((match) => match.type == DataMatchType.calendarEvent)
          .toList();

      expect(calendarMatches, hasLength(1));
      return calendarMatches.single;
    }

    CalendarEventValue calendarValue(DataDetectorMatch match) {
      expect(match.value, isA<CalendarEventValue>());
      return match.value! as CalendarEventValue;
    }

    group('numeric dates: dayMonthYear', () {
      test('detects dot-separated DMY date', () {
        final match = singleCalendarMatch(
          'meet 11.06.2026',
          options: CalendarEventDetectorOptions(
            referenceDate: referenceDate,
            numericDateOrder: NumericDateOrder.dayMonthYear,
          ),
        );

        expect(match.text, '11.06.2026');

        final value = calendarValue(match);
        expect(value.start, DateTime(2026, 6, 11));
      });

      test('detects slash-separated DMY date', () {
        final match = singleCalendarMatch(
          'meet 11/06/2026',
          options: CalendarEventDetectorOptions(
            referenceDate: referenceDate,
            numericDateOrder: NumericDateOrder.dayMonthYear,
          ),
        );

        final value = calendarValue(match);
        expect(value.start, DateTime(2026, 6, 11));
      });

      test('does not detect dash-separated DMY date by default', () {
        final matches = detector(
          includeBuiltIns: true,
          options: CalendarEventDetectorOptions(
            referenceDate: referenceDate,
            numericDateOrder: NumericDateOrder.dayMonthYear,
          ),
        ).matches('meet 11-06-2026');

        expect(
          matches.where((match) => match.type == DataMatchType.calendarEvent),
          isEmpty,
        );
      });

      test('parses ambiguous date using DMY order', () {
        final match = singleCalendarMatch(
          'date 01/02/2026',
          options: CalendarEventDetectorOptions(
            referenceDate: referenceDate,
            numericDateOrder: NumericDateOrder.dayMonthYear,
          ),
        );

        final value = calendarValue(match);
        expect(value.start, DateTime(2026, 2, 1));
      });

      test('parses unambiguous DMY date', () {
        final match = singleCalendarMatch(
          'date 13/02/2026',
          options: CalendarEventDetectorOptions(
            referenceDate: referenceDate,
            numericDateOrder: NumericDateOrder.dayMonthYear,
          ),
        );

        final value = calendarValue(match);
        expect(value.start, DateTime(2026, 2, 13));
      });

      test('rejects invalid DMY date', () {
        final matches = detector(
          includeBuiltIns: true,
          options: CalendarEventDetectorOptions(
            referenceDate: referenceDate,
            numericDateOrder: NumericDateOrder.dayMonthYear,
          ),
        ).matches('date 32/01/2026');

        expect(
          matches.where((match) => match.type == DataMatchType.calendarEvent),
          isEmpty,
        );
      });

      test('rejects invalid DMY month', () {
        final matches = detector(
          includeBuiltIns: true,
          options: CalendarEventDetectorOptions(
            referenceDate: referenceDate,
            numericDateOrder: NumericDateOrder.dayMonthYear,
          ),
        ).matches('date 11/13/2026');

        expect(
          matches.where((match) => match.type == DataMatchType.calendarEvent),
          isEmpty,
        );
      });
    });

    group('numeric dates: monthDayYear', () {
      test('parses ambiguous date using MDY order', () {
        final match = singleCalendarMatch(
          'date 01/02/2026',
          options: CalendarEventDetectorOptions(
            referenceDate: referenceDate,
            numericDateOrder: NumericDateOrder.monthDayYear,
          ),
        );

        final value = calendarValue(match);
        expect(value.start, DateTime(2026, 1, 2));
      });

      test('detects US-style date', () {
        final match = singleCalendarMatch(
          'date 06/11/2026',
          options: CalendarEventDetectorOptions(
            referenceDate: referenceDate,
            numericDateOrder: NumericDateOrder.monthDayYear,
          ),
        );

        final value = calendarValue(match);
        expect(value.start, DateTime(2026, 6, 11));
      });

      test('rejects invalid MDY month', () {
        final matches = detector(
          options: CalendarEventDetectorOptions(
            referenceDate: referenceDate,
            numericDateOrder: NumericDateOrder.monthDayYear,
          ),
        ).matches('date 13/11/2026');

        expect(
          matches.where((match) => match.type == DataMatchType.calendarEvent),
          isEmpty,
        );
      });

      test('rejects invalid MDY day', () {
        final matches = detector(
          options: CalendarEventDetectorOptions(
            referenceDate: referenceDate,
            numericDateOrder: NumericDateOrder.monthDayYear,
          ),
        ).matches('date 06/32/2026');

        expect(
          matches.where((match) => match.type == DataMatchType.calendarEvent),
          isEmpty,
        );
      });
    });

    group('numeric dates: yearMonthDay', () {
      test('parses numeric YMD date', () {
        final match = singleCalendarMatch(
          'date 2026/06/11',
          options: CalendarEventDetectorOptions(
            referenceDate: referenceDate,
            numericDateOrder: NumericDateOrder.yearMonthDay,
          ),
        );

        final value = calendarValue(match);
        expect(value.start, DateTime(2026, 6, 11));
      });
    });

    group('two-digit years', () {
      test('does not detect DMY date with zero two-digit year', () {
        final matches = detector(
          options: CalendarEventDetectorOptions(
            referenceDate: referenceDate,
            numericDateOrder: NumericDateOrder.dayMonthYear,
          ),
        ).matches('date 11/06/00');

        expect(
          matches.where((match) => match.type == DataMatchType.calendarEvent),
          isEmpty,
        );
      });

      test('does not detect DMY date with non-zero two-digit year', () {
        final matches = detector(
          options: CalendarEventDetectorOptions(
            referenceDate: referenceDate,
            numericDateOrder: NumericDateOrder.dayMonthYear,
          ),
        ).matches('date 11/06/26');

        expect(
          matches.where((match) => match.type == DataMatchType.calendarEvent),
          isEmpty,
        );
      });

      test('does not detect YMD date with two-digit year', () {
        final matches = detector(
          options: CalendarEventDetectorOptions(
            referenceDate: referenceDate,
            numericDateOrder: NumericDateOrder.yearMonthDay,
          ),
        ).matches('date 26/06/11');

        expect(
          matches.where((match) => match.type == DataMatchType.calendarEvent),
          isEmpty,
        );
      });
    });

    group('English month names', () {
      test('detects full month name before day and year', () {
        final match = singleCalendarMatch('meet June 11, 2026');

        expect(match.text, 'June 11, 2026');

        final value = calendarValue(match);
        expect(value.start, DateTime(2026, 6, 11));
      });

      test('detects full month name without comma', () {
        final match = singleCalendarMatch('meet June 11 2026');

        final value = calendarValue(match);
        expect(value.start, DateTime(2026, 6, 11));
      });

      test('detects short month name before day and year', () {
        final match = singleCalendarMatch('meet Jun 11 2026');

        final value = calendarValue(match);
        expect(value.start, DateTime(2026, 6, 11));
      });

      test('detects day before full month name', () {
        final match = singleCalendarMatch('meet 11 June 2026');

        expect(match.text, '11 June 2026');

        final value = calendarValue(match);
        expect(value.start, DateTime(2026, 6, 11));
      });

      test('detects day before short month name', () {
        final match = singleCalendarMatch('meet 11 Jun 2026');

        final value = calendarValue(match);
        expect(value.start, DateTime(2026, 6, 11));
      });

      test('is case-insensitive for month names', () {
        final match = singleCalendarMatch('meet jUnE 11, 2026');

        final value = calendarValue(match);
        expect(value.start, DateTime(2026, 6, 11));
      });

      test('rejects invalid month-name day', () {
        final matches = detector().matches('meet June 32, 2026');

        expect(
          matches.where((match) => match.type == DataMatchType.calendarEvent),
          isEmpty,
        );
      });

      test('rejects invalid leap day with month name', () {
        final matches = detector().matches('meet February 29, 2026');

        expect(
          matches.where((match) => match.type == DataMatchType.calendarEvent),
          isEmpty,
        );
      });
    });

    group('relative dates', () {
      test('detects today', () {
        final match = singleCalendarMatch('meet today');

        expect(match.text, 'today');

        final value = calendarValue(match);
        expect(value.start, DateTime(2026, 6, 11));
        expect(value.hasDate, isTrue);
        expect(value.hasTime, isFalse);
        expect(value.isAllDay, isTrue);
      });

      test('detects tomorrow', () {
        final match = singleCalendarMatch('meet tomorrow');

        expect(match.text, 'tomorrow');

        final value = calendarValue(match);
        expect(value.start, DateTime(2026, 6, 12));
      });

      test('detects yesterday', () {
        final match = singleCalendarMatch('met yesterday');

        expect(match.text, 'yesterday');

        final value = calendarValue(match);
        expect(value.start, DateTime(2026, 6, 10));
      });

      test('relative dates are case-insensitive', () {
        final match = singleCalendarMatch('meet Tomorrow');

        final value = calendarValue(match);
        expect(value.start, DateTime(2026, 6, 12));
      });

      test('does not detect relative date inside another word', () {
        final matches = detector().matches('mytomorrowtext');

        expect(
          matches.where((match) => match.type == DataMatchType.calendarEvent),
          isEmpty,
        );
      });
    });

    group('time-only', () {
      test('detects 24-hour time', () {
        final match = singleCalendarMatch('meet at 18:00');

        expect(match.text, '18:00');
        expect(match.normalizedText, '2026-06-11T18:00:00');

        final value = calendarValue(match);
        expect(value.start, DateTime(2026, 6, 11, 18, 0));
        expect(value.hasDate, isFalse);
        expect(value.hasTime, isTrue);
        expect(value.isAllDay, isFalse);
      });

      test('detects 24-hour time with minutes', () {
        final match = singleCalendarMatch('meet at 18:30');

        final value = calendarValue(match);
        expect(value.start, DateTime(2026, 6, 11, 18, 30));
      });

      test('detects midnight', () {
        final match = singleCalendarMatch('starts 00:00');

        final value = calendarValue(match);
        expect(value.start, DateTime(2026, 6, 11, 0, 0));
      });

      test('detects last valid minute of day', () {
        final match = singleCalendarMatch('ends 23:59');

        final value = calendarValue(match);
        expect(value.start, DateTime(2026, 6, 11, 23, 59));
      });

      test('rejects invalid hour', () {
        final matches = detector().matches('meet at 24:00');

        expect(
          matches.where((match) => match.type == DataMatchType.calendarEvent),
          isEmpty,
        );
      });

      test('rejects invalid minute', () {
        final matches = detector().matches('meet at 18:99');

        expect(
          matches.where((match) => match.type == DataMatchType.calendarEvent),
          isEmpty,
        );
      });

      test('detects AM time', () {
        final match = singleCalendarMatch('meet at 6 AM');

        expect(match.text, '6 AM');

        final value = calendarValue(match);
        expect(value.start, DateTime(2026, 6, 11, 6, 0));
      });

      test('detects PM time', () {
        final match = singleCalendarMatch('meet at 6 PM');

        final value = calendarValue(match);
        expect(value.start, DateTime(2026, 6, 11, 18, 0));
      });

      test('detects compact PM time', () {
        final match = singleCalendarMatch('meet at 6pm');

        final value = calendarValue(match);
        expect(value.start, DateTime(2026, 6, 11, 18, 0));
      });

      test('detects AM/PM time with minutes', () {
        final match = singleCalendarMatch('meet at 6:30pm');

        final value = calendarValue(match);
        expect(value.start, DateTime(2026, 6, 11, 18, 30));
      });

      test('parses 12 AM as midnight', () {
        final match = singleCalendarMatch('meet at 12 AM');

        final value = calendarValue(match);
        expect(value.start, DateTime(2026, 6, 11, 0, 0));
      });

      test('parses 12 PM as noon', () {
        final match = singleCalendarMatch('meet at 12 PM');

        final value = calendarValue(match);
        expect(value.start, DateTime(2026, 6, 11, 12, 0));
      });

      test('rejects invalid AM/PM hour', () {
        final matches = detector().matches('meet at 13 PM');

        expect(
          matches.where((match) => match.type == DataMatchType.calendarEvent),
          isEmpty,
        );
      });

      test('does not detect single number as time', () {
        final matches = detector().matches('meet at 6');

        expect(
          matches.where((match) => match.type == DataMatchType.calendarEvent),
          isEmpty,
        );
      });
    });

    group('date + time merge', () {
      test('merges dot-separated date and 24-hour time', () {
        final match = singleCalendarMatch('meet 11.06.2026 18:00');

        expect(match.text, '11.06.2026 18:00');
        expect(match.normalizedText, '2026-06-11T18:00:00');

        final value = calendarValue(match);
        expect(value.start, DateTime(2026, 6, 11, 18, 0));
        expect(value.hasDate, isTrue);
        expect(value.hasTime, isTrue);
        expect(value.isAllDay, isFalse);
      });

      test('merges slash-separated date and time with comma', () {
        final match = singleCalendarMatch('meet 11/06/2026, 18:00');

        expect(match.text, '11/06/2026, 18:00');

        final value = calendarValue(match);
        expect(value.start, DateTime(2026, 6, 11, 18, 0));
      });

      test('merges month-name date and time with at', () {
        final match = singleCalendarMatch('meet June 11, 2026 at 18:00');

        expect(match.text, 'June 11, 2026 at 18:00');

        final value = calendarValue(match);
        expect(value.start, DateTime(2026, 6, 11, 18, 0));
      });

      test('merges relative date and time', () {
        final match = singleCalendarMatch('meet tomorrow at 18:00');

        expect(match.text, 'tomorrow at 18:00');

        final value = calendarValue(match);
        expect(value.start, DateTime(2026, 6, 12, 18, 0));
        expect(value.hasDate, isTrue);
        expect(value.hasTime, isTrue);
      });

      test('merges relative date and compact PM time', () {
        final match = singleCalendarMatch('meet tomorrow 6pm');

        expect(match.text, 'tomorrow 6pm');

        final value = calendarValue(match);
        expect(value.start, DateTime(2026, 6, 12, 18, 0));
      });

      test('merges English month date and PM time', () {
        final match = singleCalendarMatch('meet June 11, 2026 at 6 PM');

        expect(match.text, 'June 11, 2026 at 6 PM');

        final value = calendarValue(match);
        expect(value.start, DateTime(2026, 6, 11, 18, 0));
      });

      test('does not merge date and far away time', () {
        final matches = detector().matches(
          'date 11.06.2026 and then many words later maybe at 18:00',
        );

        final calendarMatches = matches
            .where((match) => match.type == DataMatchType.calendarEvent)
            .toList();

        expect(calendarMatches.length, greaterThanOrEqualTo(2));
        expect(
            calendarMatches.any((match) => match.text == '11.06.2026'), isTrue);
        expect(calendarMatches.any((match) => match.text == '18:00'), isTrue);
      });
    });

    group('time ranges', () {
      test('detects 24-hour time range', () {
        final match = singleCalendarMatch('busy 18:00-19:00');

        expect(match.text, '18:00-19:00');
        expect(match.normalizedText, '2026-06-11T18:00:00/2026-06-11T19:00:00');

        final value = calendarValue(match);
        expect(value.start, DateTime(2026, 6, 11, 18, 0));
        expect(value.end, DateTime(2026, 6, 11, 19, 0));
        expect(value.duration, const Duration(hours: 1));
        expect(value.hasDate, isFalse);
        expect(value.hasTime, isTrue);
      });

      test('detects 24-hour time range with spaces', () {
        final match = singleCalendarMatch('busy 18:00 - 19:30');

        expect(match.text, '18:00 - 19:30');

        final value = calendarValue(match);
        expect(value.start, DateTime(2026, 6, 11, 18, 0));
        expect(value.end, DateTime(2026, 6, 11, 19, 30));
      });

      test('detects AM/PM time range', () {
        final match = singleCalendarMatch('busy 6 PM - 7 PM');

        final value = calendarValue(match);
        expect(value.start, DateTime(2026, 6, 11, 18, 0));
        expect(value.end, DateTime(2026, 6, 11, 19, 0));
      });

      test('detects compact AM/PM time range', () {
        final match = singleCalendarMatch('busy 6pm-7pm');

        final value = calendarValue(match);
        expect(value.start, DateTime(2026, 6, 11, 18, 0));
        expect(value.end, DateTime(2026, 6, 11, 19, 0));
      });

      test('rejects invalid time range start', () {
        final matches = detector().matches('busy 25:00-26:00');

        expect(
          matches.where((match) => match.type == DataMatchType.calendarEvent),
          isEmpty,
        );
      });

      test('rejects invalid time range end', () {
        final matches = detector().matches('busy 18:00-26:00');

        final calendarMatches = matches
            .where((match) => match.type == DataMatchType.calendarEvent)
            .toList();

        expect(calendarMatches.any((match) => match.text == '18:00-26:00'),
            isFalse);
      });

      test('rejects reversed same-day time range', () {
        final matches = detector().matches('busy 19:00-18:00');

        final calendarMatches = matches
            .where((match) => match.type == DataMatchType.calendarEvent)
            .toList();

        expect(calendarMatches.any((match) => match.text == '19:00-18:00'),
            isFalse);
      });
    });

    group('date + time ranges', () {
      test('merges relative date with time range', () {
        final match = singleCalendarMatch('busy tomorrow 18:00-19:00');

        expect(match.text, 'tomorrow 18:00-19:00');

        final value = calendarValue(match);
        expect(value.start, DateTime(2026, 6, 12, 18, 0));
        expect(value.end, DateTime(2026, 6, 12, 19, 0));
        expect(value.duration, const Duration(hours: 1));
        expect(value.hasDate, isTrue);
        expect(value.hasTime, isTrue);
      });

      test('merges relative date with time range using at', () {
        final match = singleCalendarMatch('busy tomorrow at 18:00-19:00');

        expect(match.text, 'tomorrow at 18:00-19:00');

        final value = calendarValue(match);
        expect(value.start, DateTime(2026, 6, 12, 18, 0));
        expect(value.end, DateTime(2026, 6, 12, 19, 0));
      });

      test('merges dot-separated date with time range', () {
        final match = singleCalendarMatch('busy 11.06.2026 18:00-19:00');

        expect(match.text, '11.06.2026 18:00-19:00');

        final value = calendarValue(match);
        expect(value.start, DateTime(2026, 6, 11, 18, 0));
        expect(value.end, DateTime(2026, 6, 11, 19, 0));
      });

      test('merges English month date with time range', () {
        final match = singleCalendarMatch('busy June 11, 2026 6 PM - 7 PM');

        expect(match.text, 'June 11, 2026 6 PM - 7 PM');

        final value = calendarValue(match);
        expect(value.start, DateTime(2026, 6, 11, 18, 0));
        expect(value.end, DateTime(2026, 6, 11, 19, 0));
      });
    });

    group('multiple calendar events', () {
      test('detects multiple dates in one text', () {
        final matches = detector().matches('from 11.06.2026 to 12.06.2026');

        final calendarMatches = matches
            .where((match) => match.type == DataMatchType.calendarEvent)
            .toList();

        expect(calendarMatches, hasLength(2));
        expect(calendarMatches[0].text, '11.06.2026');
        expect(calendarMatches[1].text, '12.06.2026');
      });

      test('detects multiple times in one text', () {
        final matches = detector().matches('first 10:00 second 18:00');

        final calendarMatches = matches
            .where((match) => match.type == DataMatchType.calendarEvent)
            .toList();

        expect(calendarMatches, hasLength(2));
        expect(calendarMatches[0].text, '10:00');
        expect(calendarMatches[1].text, '18:00');
      });

      test('keeps matches sorted by start offset', () {
        final matches = detector().matches('18:00 tomorrow 11.06.2026');

        final calendarMatches = matches
            .where((match) => match.type == DataMatchType.calendarEvent)
            .toList();

        expect(calendarMatches, isNotEmpty);

        for (var i = 1; i < calendarMatches.length; i++) {
          expect(calendarMatches[i].start,
              greaterThan(calendarMatches[i - 1].start));
        }
      });
    });

    group('boundaries and punctuation', () {
      test('trims trailing period after date', () {
        final match = singleCalendarMatch('meet 11.06.2026.');

        expect(match.text, '11.06.2026');
      });

      test('trims trailing comma after date', () {
        final match = singleCalendarMatch('meet 11.06.2026, please');

        expect(match.text, '11.06.2026');
      });

      test('trims trailing closing parenthesis if it is a wrapper', () {
        final match = singleCalendarMatch('meet (11.06.2026)');

        expect(match.text, '11.06.2026');
      });

      test('detects date in square brackets', () {
        final match = singleCalendarMatch('meet [11.06.2026]');

        expect(match.text, '11.06.2026');
      });

      test('does not include quote wrappers', () {
        final match = singleCalendarMatch('meet "11.06.2026"');

        expect(match.text, '11.06.2026');
      });

      test('does not detect date embedded in letters before', () {
        final matches = detector().matches('abc2026-06-11');

        expect(
          matches.where((match) => match.type == DataMatchType.calendarEvent),
          isEmpty,
        );
      });

      test('does not detect date embedded in letters after', () {
        final matches = detector().matches('2026-06-11abc');

        expect(
          matches.where((match) => match.type == DataMatchType.calendarEvent),
          isEmpty,
        );
      });

      test('does not detect time embedded in digits before', () {
        final matches = detector().matches('118:00');

        expect(
          matches.where((match) => match.type == DataMatchType.calendarEvent),
          isEmpty,
        );
      });

      test('does not detect time embedded in digits after', () {
        final matches = detector().matches('18:001');

        expect(
          matches.where((match) => match.type == DataMatchType.calendarEvent),
          isEmpty,
        );
      });
    });

    group('false positives', () {
      test('does not detect semantic version', () {
        final matches = detector().matches('Flutter 3.32.1 is installed');

        expect(
          matches.where((match) => match.type == DataMatchType.calendarEvent),
          isEmpty,
        );
      });

      test('does not detect price as time', () {
        final matches = detector().matches('price is 12.50');

        expect(
          matches.where((match) => match.type == DataMatchType.calendarEvent),
          isEmpty,
        );
      });

      test('does not detect compact id as date', () {
        final matches = detector().matches('id 20260611');

        expect(
          matches.where((match) => match.type == DataMatchType.calendarEvent),
          isEmpty,
        );
      });

      test('does not detect short number as date', () {
        final matches = detector().matches('number 123456');

        expect(
          matches.where((match) => match.type == DataMatchType.calendarEvent),
          isEmpty,
        );
      });

      test('does not detect file extension as date', () {
        final matches = detector().matches('file report.2026');

        expect(
          matches.where((match) => match.type == DataMatchType.calendarEvent),
          isEmpty,
        );
      });

      test('does not detect IP address as date', () {
        final matches = detector().matches('server 192.168.0.1');

        expect(
          matches.where((match) => match.type == DataMatchType.calendarEvent),
          isEmpty,
        );
      });

      test('does not detect decimal range as time range', () {
        final matches = detector().matches('value 18.00-19.00');

        expect(
          matches.where((match) => match.type == DataMatchType.calendarEvent),
          isEmpty,
        );
      });

      test('does not detect malformed date with mixed separators', () {
        final matches = detector().matches('date 11/06-2026');

        expect(
          matches.where((match) => match.type == DataMatchType.calendarEvent),
          isEmpty,
        );
      });
    });

    group('overlap with phone detector', () {
      test('dash-separated numeric date is not a calendar event by default',
          () {
        final matches = detector(
          includeBuiltIns: true,
          options: CalendarEventDetectorOptions(
            referenceDate: referenceDate,
            numericDateOrder: NumericDateOrder.dayMonthYear,
          ),
        ).matches('meet 11-06-2026');

        final calendarMatches = matches
            .where((match) => match.type == DataMatchType.calendarEvent)
            .toList();

        final phoneMatches = matches
            .where((match) => match.type == DataMatchType.phoneNumber)
            .toList();

        expect(calendarMatches, isEmpty);
        expect(phoneMatches, isEmpty);
      });

      test('ISO-like date is not a calendar event or phone number', () {
        final matches = detector(
          includeBuiltIns: true,
        ).matches('meet 2026-06-11');

        final calendarMatches = matches
            .where((match) => match.type == DataMatchType.calendarEvent)
            .toList();

        final phoneMatches = matches
            .where((match) => match.type == DataMatchType.phoneNumber)
            .toList();

        expect(calendarMatches, isEmpty);
        expect(phoneMatches, isEmpty);
      });

      test('calendar event wins over phone for slash-separated numeric date',
          () {
        final matches = detector(
          includeBuiltIns: true,
          options: CalendarEventDetectorOptions(
            referenceDate: referenceDate,
            numericDateOrder: NumericDateOrder.dayMonthYear,
          ),
        ).matches('meet 11/06/2026');

        final calendarMatches = matches
            .where((match) => match.type == DataMatchType.calendarEvent)
            .toList();

        final phoneMatches = matches
            .where((match) => match.type == DataMatchType.phoneNumber)
            .toList();

        expect(calendarMatches, hasLength(1));
        expect(phoneMatches, isEmpty);
      });

      test('calendar event wins over phone for dot-separated numeric date', () {
        final matches = detector(
          includeBuiltIns: true,
          options: CalendarEventDetectorOptions(
            referenceDate: referenceDate,
            numericDateOrder: NumericDateOrder.dayMonthYear,
          ),
        ).matches('meet 11.06.2026');

        final calendarMatches = matches
            .where((match) => match.type == DataMatchType.calendarEvent)
            .toList();

        final phoneMatches = matches
            .where((match) => match.type == DataMatchType.phoneNumber)
            .toList();

        expect(calendarMatches, hasLength(1));
        expect(phoneMatches, isEmpty);
      });

      test('leading plus is not treated as a calendar event', () {
        final matches =
            detector(includeBuiltIns: true).matches('call +11-06-2026');

        final calendarMatches = matches
            .where((match) => match.type == DataMatchType.calendarEvent)
            .toList();

        final phoneMatches = matches
            .where((match) => match.type == DataMatchType.phoneNumber)
            .toList();

        expect(calendarMatches, isEmpty);
        expect(phoneMatches, isEmpty);
      });
    });

    group('overlap with links and emails', () {
      test('does not detect date-like text inside URL path as calendar event',
          () {
        final matches = detector(
          includeBuiltIns: true,
        ).matches('open example.com/2026-06-11');

        final linkMatches =
            matches.where((match) => match.type == DataMatchType.link).toList();

        final calendarMatches = matches
            .where((match) => match.type == DataMatchType.calendarEvent)
            .toList();

        expect(linkMatches, hasLength(1));
        expect(calendarMatches, isEmpty);
      });

      test('does not detect time-like text inside URL query as calendar event',
          () {
        final matches = detector(
          includeBuiltIns: true,
        ).matches('open example.com/?time=18:00');

        final linkMatches =
            matches.where((match) => match.type == DataMatchType.link).toList();

        final calendarMatches = matches
            .where((match) => match.type == DataMatchType.calendarEvent)
            .toList();

        expect(linkMatches, hasLength(1));
        expect(calendarMatches, isEmpty);
      });

      test('does not detect date-like text inside email local part', () {
        final matches = detector(
          includeBuiltIns: true,
        ).matches('mail 2026-06-11@example.com');

        final emailMatches = matches
            .where((match) => match.type == DataMatchType.emailAddress)
            .toList();

        final calendarMatches = matches
            .where((match) => match.type == DataMatchType.calendarEvent)
            .toList();

        expect(emailMatches, hasLength(1));
        expect(calendarMatches, isEmpty);
      });
    });

    group('custom pattern modes', () {
      test('custom constructor uses only custom patterns', () {
        final calendarDetector = CalendarEventDetector.custom(
          patterns: const [],
          options: CalendarEventDetectorOptions(
            referenceDate: referenceDate,
          ),
        );

        final dataDetector = DataDetector(
          additionalRules: [
            calendarDetector,
          ],
        );

        final matches = dataDetector.matches('meet 11.06.2026');

        expect(
          matches.where((match) => match.type == DataMatchType.calendarEvent),
          isEmpty,
        );
      });

      test('extended constructor keeps defaults and additional patterns', () {
        final calendarDetector = CalendarEventDetector.extended(
          additionalPatterns: const [],
          options: CalendarEventDetectorOptions(
            referenceDate: referenceDate,
          ),
        );

        final dataDetector = DataDetector(
          additionalRules: [
            calendarDetector,
          ],
        );

        final matches = dataDetector.matches('meet 11.06.2026');

        expect(
          matches.where((match) => match.type == DataMatchType.calendarEvent),
          hasLength(1),
        );
      });
    });

    group('async API', () {
      test('streams calendar event matches through DataDetector async API',
          () async {
        final dataDetector = detector();

        final matches = await dataDetector
            .matchesAsync('meet tomorrow at 18:00')
            .where((match) => match.type == DataMatchType.calendarEvent)
            .toList();

        expect(matches, hasLength(1));
        expect(matches.single.text, 'tomorrow at 18:00');

        final value = calendarValue(matches.single);
        expect(value.start, DateTime(2026, 6, 12, 18, 0));
      });
    });

    group('string extension', () {
      test('detects calendar events through string extension if supported', () {
        final matches = 'meet tomorrow at 18:00'.dataDetectorMatches(
          additionalRules: [
            CalendarEventDetector(
              options: CalendarEventDetectorOptions(
                referenceDate: referenceDate,
              ),
            ),
          ],
        );

        final calendarMatches = matches
            .where((match) => match.type == DataMatchType.calendarEvent)
            .toList();

        expect(calendarMatches, hasLength(1));
        expect(calendarMatches.single.text, 'tomorrow at 18:00');
      });
    });
  });
}
