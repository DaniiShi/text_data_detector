# text_data_detector

[![Dart CI](https://github.com/DaniiShi/text_data_detector/actions/workflows/dart.yml/badge.svg)](https://github.com/DaniiShi/text_data_detector/actions/workflows/dart.yml)

A pure Dart detector for extracting links, email addresses, phone numbers, calendar events, and custom patterns from plain text.

It is useful when you need to build chat messages, rich text, previews, clickable links, or any feature that needs stable text ranges without relying on platform-specific APIs.

Inspired by system data detector APIs such as iOS NSDataDetector, but implemented in pure Dart and available on every Dart platform.

## Features
Detects links, email addresses, and phone numbers.
Detects calendar events such as numeric dates, times, and time ranges.
Returns stable start / end ranges for the original text.
Provides normalized values such as https://example.com or Punycode-normalized IDN domains.
Supports Unicode and IDN domains.
Supports custom detectors for mentions, hashtags, order numbers, or app-specific patterns.
Works without Flutter plugins, native code, or platform channels.

## Usage

```dart
import 'package:text_data_detector/text_data_detector.dart';

void main() {
  final detector = DataDetector();

  final matches = detector.matches(
    'Visit example.com or email büro@münchen.de',
  );

  print(matches);
}
```

Result:

```dart
[
  DataDetectorMatch(
    type: DataMatchType.link,
    start: 6,
    end: 17,
    text: 'example.com',
    normalizedText: 'https://example.com',
  ),
  DataDetectorMatch(
    type: DataMatchType.emailAddress,
    start: 27,
    end: 42,
    text: büro@münchen.de,
    normalizedText: büro@xn--mnchen-3ya.de,
  ),
]
```
## Screenshot

![Text data detector example](screenshots/flutter_example.png)

## Configuration

```dart
final detector = DataDetector(
  options: DataDetectorOptions(
    linkOptions: const LinkDetectorOptions(allowCustomSchemes: true),
    emailOptions: const EmailDetectorOptions(allowUnicodeLocalPart: true),
    phoneOptions: const PhoneDetectorOptions(mode: PhoneDetectionMode.loose),
    calendarOptions: CalendarEventDetectorOptions(
      referenceDate: DateTime(2026, 6, 11),
    ),
    matchWeights: {
      DataMatchType.emailAddress: 100,
      DataMatchType.link: 90,
      DataMatchType.calendarEvent: 85,
      DataMatchType.phoneNumber: 80,
    },
  ),
);

final matches = detector.matches(text);

await for (final match in detector.matchesAsync(text)) {
  print(match);
}
```

There is also a string extension for one-off scans:

```dart
final matches = 'Open example.com'.dataDetectorMatches();

final calendarMatches = 'Meet February 29, 2024'.dataDetectorMatches(
  additionalRules: [
    CalendarEventDetector.extended(
      options: CalendarEventDetectorOptions(
        referenceDate: DateTime(2026, 6, 11),
      ),
    ),
  ],
);
```

`DataDetectorMatch` includes the original string range, original text,
normalized text, and an optional typed value:

```dart
match.type;
match.start;
match.end;
match.text;
match.normalizedText;
match.value;
match.uri;
match.emailAddress;
match.phoneNumber;
match.calendarEvent;
```

`start` and `end` are offsets into the original Dart string. `end` is exclusive,
matching `String.substring(start, end)`.

## Calendar Events

Calendar event detection is part of the default detector pipeline:

```dart
final detector = DataDetector(
  options: DataDetectorOptions(
    calendarOptions: CalendarEventDetectorOptions(
      referenceDate: DateTime(2026, 6, 11),
      numericDateOrder: NumericDateOrder.dayMonthYear,
    ),
  ),
);

final matches = detector.matches('Meet 29.02.2024 at 18:00');
```

This returns one `DataMatchType.calendarEvent` match with:

```dart
match.text; // 29.02.2024 at 18:00
match.normalizedText; // 2024-02-29T18:00:00
match.calendarEvent?.start; // DateTime(2024, 2, 29, 18)
```

The default detector supports dot- and slash-separated numeric dates using
configurable DMY, MDY, or YMD order; date ranges such as
`11.06.2026 - 12.06.2026`; plus time-only values and time ranges.
`CalendarEventDetector.extended()` adds English full and abbreviated month
names, and relative dates such as `today`, `tomorrow`, `yesterday`,
`3 days ago`, and `2 weeks ago` when `additionalPatterns` is omitted or
explicitly set to `null`. Passing `additionalPatterns: const []` disables
these built-in English extras; a non-empty list uses only the supplied extra
patterns alongside the default numeric-date and time patterns.
Relative dates are resolved using `referenceDate`.

For English month names, relative dates, or custom calendar syntax, replace or
extend the pattern pipeline:

```dart
final customOnly = CalendarEventDetector.custom(
  patterns: [MyCalendarPattern()],
);

final extended = CalendarEventDetector.extended(
  additionalPatterns: [MyRussianRelativeDatePattern()],
);

final extendedWithBuiltInExtras = CalendarEventDetector.extended();

final extendedWithoutExtras = CalendarEventDetector.extended(
  additionalPatterns: const [],
);

final detectorWithEnglishDates = DataDetector(
  additionalRules: [
    CalendarEventDetector.extended(),
  ],
);
```

## Custom Detection

`DataMatchType` is a small value object, so applications can define their own
types and rules next to the built-in link, email, phone, and calendar event
rules.

`DataDetector` has two rule lists:

- `baseRules` replaces the built-in base rule pipeline. If omitted, link, email,
  phone, and calendar event rules are used. Pass `baseRules: const []` to
  disable all built-ins.
- `additionalRules` appends application-specific rules after the base rule
  pipeline.

`DataDetectorOptions.matchWeights` controls which match wins when detectors
return overlapping ranges. Higher weight wins; if weights are equal, the longer
range wins. Built-in rules in `baseRules` get default weights unless
overridden: email 100, link 90, phone 80. Custom match types default to 0 unless
a weight is provided.

```dart
const mentionType = DataMatchType('mention');
const hashtagType = DataMatchType('hashtag');

final detector = DataDetector(
  additionalRules: const [MentionDetector(), HashtagDetector()],
  options: DataDetectorOptions(
    matchWeights: {
      mentionType: 70,
      hashtagType: 60,
    },
  ),
);
```

Example detector:

```dart
final class MentionDetector implements DataDetectorRule {
  const MentionDetector();

  static final RegExp _pattern = RegExp(
    r'(?<![\w@])@[A-Za-z][A-Za-z0-9_]{1,31}',
  );

  @override
  List<DataDetectorMatch> detect(String text) {
    return [
      for (final match in _pattern.allMatches(text))
        DataDetectorMatch(
          type: mentionType,
          start: match.start,
          end: match.end,
          text: match.group(0)!,
          normalizedText: match.group(0)!.toLowerCase(),
          value: match.group(0)!.substring(1).toLowerCase(),
        ),
    ];
  }
}
```

To run only custom detectors:

```dart
final detector = DataDetector(
  baseRules: const [],
  additionalRules: const [MentionDetector(), HashtagDetector()],
  options: DataDetectorOptions(
    matchWeights: {mentionType: 70, hashtagType: 60},
  ),
);
```

## Link Detection

The detector supports URLs with and without explicit schemes, ports, paths,
standard URI schemes, IDN domains, and optional custom schemes.

Bare hosts must end with a known public suffix. Unicode host labels are
normalized to Punycode in `normalizedText`, while `text`, `start`, and `end`
continue to reference the original input.

## Email Detection

The email detector reuses the same host pipeline as link detection. Only the
domain is converted to Punycode. Unicode local-parts are preserved for
EAI/SMTPUTF8-style addresses:

```text
john@example.com    -> john@example.com
anton@münchen.de    -> anton@xn--mnchen-3ya.de
büro@münchen.de     -> büro@xn--mnchen-3ya.de
用户@例子.中国        -> 用户@xn--fsqu00a.xn--fiqs8s
```

Set `EmailDetectorOptions(allowUnicodeLocalPart: false)` when you only want
ASCII text before the `@`.

## Phone Detection

Phone detection defaults to `PhoneDetectionMode.strict`. In strict mode, a phone
candidate needs an explicit signal: a leading `+`, parentheses around an
area/operator code, hyphenated groups, or phone-like whitespace grouping. Plain
digit runs without such a signal are rejected.

```text
+1 999 555-11-22  -> +19995551122
+19995551122      -> +19995551122
8 (999) 555-11-22 -> 89995551122
(800) 555-1234    -> 8005551234
999-555-1122      -> 9995551122
999 555 1122      -> 9995551122
```

For behavior closer to system detectors on iOS and Android, use loose mode. It
accepts any candidate with 7-15 digits, with fewer format checks, and allows
spaces, hyphens, dots, and parentheses:

```dart
final detector = DataDetector(
  options: const DataDetectorOptions(
    phoneOptions: PhoneDetectorOptions(mode: PhoneDetectionMode.loose),
  ),
);
```

```text
9994885764358     -> 9994885764358
9995551           -> 9995551
+1 999 555-11-22  -> +19995551122
123456            -> rejected, too short
1234567890123456  -> rejected, too long
```

The digit limits can be adjusted with `PhoneDetectorOptions.minDigits` and
`PhoneDetectorOptions.maxDigits`.

## Public Suffix List

The runtime does not read or parse a PSL text file during detection. The current
implementation uses generated Dart data bucketed by TLD, which keeps the lookup
path simple and allocation-light.
