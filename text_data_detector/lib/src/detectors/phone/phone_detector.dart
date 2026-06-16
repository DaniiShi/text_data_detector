import '../../data_detector/data_detector_match.dart';
import '../../data_detector/data_detector_rule.dart';
import 'phone_detector_options.dart';

/// Detects phone-number-like text ranges.
final class PhoneDetector implements DataDetectorRule {
  const PhoneDetector({this.options = const PhoneDetectorOptions()});

  /// Phone-specific detection options.
  final PhoneDetectorOptions options;

  static final RegExp _strictCandidatePattern = RegExp(
    r'''(?:^|[^0-9A-Za-z_+()-]|(?=\+))(\+\d{1,3} \d{3} \d{3}-\d{2}-\d{2}|\+\d{1,3} \d{3} \d{3} \d{4}|\+\d{10,15}|\d ?\(\d{2,5}\) ?\d{3}-\d{2}-\d{2}|\d ?\(\d{2,5}\) ?\d{3}[- ]\d{4}|\(\d{2,5}\) ?\d{3}-\d{4}|\d{3}-\d{3}-\d{4}|\d{3} \d{3} \d{4})''',
  );

  /// Dispatches to strict or loose parsing according to [options].
  @override
  List<DataDetectorMatch> detect(String text) {
    return switch (options.mode) {
      PhoneDetectionMode.strict => _detectStrict(text),
      PhoneDetectionMode.loose => _detectLoose(text),
    };
  }

  /// Strict mode requires an explicit phone signal such as `+`, `()`, or `-`.
  List<DataDetectorMatch> _detectStrict(String text) {
    final matches = <DataDetectorMatch>[];

    for (final match in _strictCandidatePattern.allMatches(text)) {
      final rawCandidate = match.group(1);
      if (rawCandidate == null || rawCandidate.isEmpty) {
        continue;
      }

      final range = _trimCandidateRange(
        rawCandidate,
        match.end - rawCandidate.length,
      );
      if (range == null) {
        continue;
      }

      final candidate = text.substring(range.start, range.end);
      final start = range.start;
      final end = range.end;
      if (!_hasCleanBoundaries(text, start, end)) {
        continue;
      }

      final normalized = _parse(candidate, options);
      if (normalized == null) {
        continue;
      }

      matches.add(
        DataDetectorMatch(
          type: DataMatchType.phoneNumber,
          start: start,
          end: end,
          text: text.substring(start, end),
          normalizedText: normalized,
          value: normalized,
        ),
      );
    }

    return matches;
  }

  /// Loose mode scans digit runs with allowed separators and fewer checks.
  List<DataDetectorMatch> _detectLoose(String text) {
    final matches = <DataDetectorMatch>[];
    var cursor = 0;

    while (cursor < text.length) {
      final codeUnit = text.codeUnitAt(cursor);
      if (!_isLooseStart(text, cursor, codeUnit)) {
        cursor++;
        continue;
      }

      final end = _looseCandidateEnd(text, cursor);
      if (end <= cursor) {
        cursor++;
        continue;
      }

      final candidate = text.substring(cursor, end);
      final normalized = _parse(candidate, options);
      if (normalized != null && _hasCleanBoundaries(text, cursor, end)) {
        matches.add(
          DataDetectorMatch(
            type: DataMatchType.phoneNumber,
            start: cursor,
            end: end,
            text: candidate,
            normalizedText: normalized,
            value: normalized,
          ),
        );
      }
      cursor = end;
    }

    return matches;
  }

  /// Returns true when [index] can begin a loose phone candidate.
  static bool _isLooseStart(String text, int index, int codeUnit) {
    if (!_isCandidateEdge(codeUnit)) {
      return false;
    }
    if (index > 0 && _isTokenCodeUnit(text.codeUnitAt(index - 1))) {
      return false;
    }
    if (codeUnit == 0x2b || codeUnit == 0x28) {
      return index + 1 < text.length &&
          _isAsciiDigit(text.codeUnitAt(index + 1));
    }
    return true;
  }

  /// Advances until a loose candidate stops or reaches [options.maxDigits].
  int _looseCandidateEnd(String text, int start) {
    var index = start;
    var digits = 0;
    var lastDigitEnd = start;

    while (index < text.length) {
      final codeUnit = text.codeUnitAt(index);
      if (index == start && codeUnit == 0x2b) {
        index++;
        continue;
      }
      if (_isAsciiDigit(codeUnit)) {
        if (digits == options.maxDigits) {
          break;
        }
        digits++;
        lastDigitEnd = index + 1;
        index++;
        continue;
      }

      if (!_isLooseSeparator(codeUnit)) {
        break;
      }
      if (codeUnit == 0x20 && digits >= options.minDigits) {
        break;
      }
      if (index + 1 >= text.length ||
          !_canFollowLooseSeparator(text, index + 1)) {
        break;
      }

      index++;
    }

    return lastDigitEnd;
  }

  /// Returns true for characters that may follow a loose separator.
  static bool _canFollowLooseSeparator(String text, int index) {
    final codeUnit = text.codeUnitAt(index);
    return _isAsciiDigit(codeUnit) || codeUnit == 0x28 || codeUnit == 0x29;
  }

  /// Separators allowed in loose mode.
  static bool _isLooseSeparator(int codeUnit) {
    return codeUnit == 0x20 ||
        codeUnit == 0x28 ||
        codeUnit == 0x29 ||
        codeUnit == 0x2d;
  }

  /// Validates one candidate and returns the normalized phone string.
  ///
  /// Normalization keeps a leading `+` and removes all other separators.
  static String? _parse(String candidate, PhoneDetectorOptions options) {
    if (!_hasAllowedCharacters(candidate)) {
      return null;
    }
    if (options.mode == PhoneDetectionMode.strict &&
        !_hasExplicitSignal(candidate)) {
      return null;
    }
    if (options.mode == PhoneDetectionMode.strict &&
        !_hasValidParentheses(candidate)) {
      return null;
    }
    if (options.mode == PhoneDetectionMode.strict &&
        !_hasValidSeparators(candidate)) {
      return null;
    }

    final digits = _digitsOnly(candidate);
    if (digits.length < options.minDigits ||
        digits.length > options.maxDigits) {
      return null;
    }

    return candidate.startsWith('+') ? '+$digits' : digits;
  }

  /// Ensures a candidate contains only phone characters supported by parser.
  static bool _hasAllowedCharacters(String candidate) {
    for (var i = 0; i < candidate.length; i++) {
      final codeUnit = candidate.codeUnitAt(i);
      if (_isAsciiDigit(codeUnit) ||
          codeUnit == 0x20 ||
          codeUnit == 0x28 ||
          codeUnit == 0x29 ||
          codeUnit == 0x2b ||
          codeUnit == 0x2d) {
        continue;
      }
      return false;
    }
    return candidate.indexOf('+') <= 0;
  }

  /// Strict-mode signal check: `+`, parentheses, hyphens, or phone grouping.
  static bool _hasExplicitSignal(String candidate) {
    if (candidate.startsWith('+')) {
      return true;
    }
    if (candidate.contains('(') || candidate.contains(')')) {
      return true;
    }
    if (candidate.contains('-')) {
      return true;
    }
    return _hasWhitespacePhoneGrouping(candidate);
  }

  /// Ensures parentheses are balanced and wrap only an area/operator code.
  static bool _hasValidParentheses(String candidate) {
    final open = candidate.indexOf('(');
    final close = candidate.indexOf(')');
    if (open == -1 && close == -1) {
      return true;
    }
    if (open == -1 ||
        close == -1 ||
        open > close ||
        candidate.indexOf('(', open + 1) != -1 ||
        candidate.indexOf(')', close + 1) != -1) {
      return false;
    }

    final areaCode = candidate.substring(open + 1, close);
    if (areaCode.length < 2 || areaCode.length > 5) {
      return false;
    }
    for (final codeUnit in areaCode.codeUnits) {
      if (!_isAsciiDigit(codeUnit)) {
        return false;
      }
    }
    return true;
  }

  /// Trims separators captured before or after the actual phone candidate.
  static _CandidateRange? _trimCandidateRange(String candidate, int offset) {
    var start = 0;
    var end = candidate.length;
    while (start < end && !_isCandidateEdge(candidate.codeUnitAt(start))) {
      start++;
    }
    while (end > start && !_isCandidateEdge(candidate.codeUnitAt(end - 1))) {
      end--;
    }
    if (start == end) {
      return null;
    }
    return _CandidateRange(start: offset + start, end: offset + end);
  }

  /// Characters that may appear at the start or end of a phone candidate.
  static bool _isCandidateEdge(int codeUnit) {
    return _isAsciiDigit(codeUnit) || codeUnit == 0x2b || codeUnit == 0x28;
  }

  /// Rejects separator combinations that are too noisy for strict mode.
  static bool _hasValidSeparators(String candidate) {
    if (candidate.contains('--') ||
        candidate.contains('  ') ||
        candidate.contains('- ') ||
        candidate.contains(' -')) {
      return false;
    }
    if (candidate.contains('-') &&
        !candidate.startsWith('+') &&
        !candidate.contains('(') &&
        !candidate.contains(' ') &&
        !candidate.contains(')')) {
      return _hasDigitGroups(candidate.split('-'), minGroups: 2);
    }
    if (candidate.contains(' ') &&
        !candidate.startsWith('+') &&
        !candidate.contains('-') &&
        !candidate.contains('(') &&
        !candidate.contains(')')) {
      return _hasWhitespacePhoneGrouping(candidate);
    }
    return true;
  }

  static bool _hasWhitespacePhoneGrouping(String candidate) {
    if (!candidate.contains(' ')) {
      return false;
    }
    return _hasDigitGroups(candidate.split(' '), minGroups: 3);
  }

  static bool _hasDigitGroups(List<String> groups, {required int minGroups}) {
    final compactGroups = groups.where((group) => group.isNotEmpty).toList();
    if (compactGroups.length < minGroups) {
      return false;
    }

    for (var i = 0; i < compactGroups.length; i++) {
      final digits = _digitsOnly(compactGroups[i]);
      if (digits.isEmpty || digits.length != _digitCount(compactGroups[i])) {
        return false;
      }
      if (i == 0) {
        if (digits.length > 4) {
          return false;
        }
      } else if (digits.length < 2 || digits.length > 4) {
        return false;
      }
    }
    return true;
  }

  static bool _hasCleanBoundaries(String text, int start, int end) {
    if (start > 0 &&
        _isTokenCodeUnit(text.codeUnitAt(start - 1)) &&
        !_canStartAfterToken(text, start)) {
      return false;
    }
    if (end < text.length && _isTokenCodeUnit(text.codeUnitAt(end))) {
      return false;
    }
    return true;
  }

  static bool _canStartAfterToken(String text, int start) {
    return text.codeUnitAt(start) == 0x2b &&
        _isAsciiLetter(text.codeUnitAt(start - 1));
  }

  static String _digitsOnly(String value) {
    final buffer = StringBuffer();
    for (final codeUnit in value.codeUnits) {
      if (_isAsciiDigit(codeUnit)) {
        buffer.writeCharCode(codeUnit);
      }
    }
    return buffer.toString();
  }

  static int _digitCount(String value) {
    var count = 0;
    for (final codeUnit in value.codeUnits) {
      if (_isAsciiDigit(codeUnit)) {
        count++;
      }
    }
    return count;
  }

  static bool _isAsciiDigit(int codeUnit) {
    return codeUnit >= 0x30 && codeUnit <= 0x39;
  }

  static bool _isAsciiLetter(int codeUnit) {
    return (codeUnit >= 0x41 && codeUnit <= 0x5a) ||
        (codeUnit >= 0x61 && codeUnit <= 0x7a);
  }

  static bool _isTokenCodeUnit(int codeUnit) {
    return _isAsciiDigit(codeUnit) ||
        (codeUnit >= 0x41 && codeUnit <= 0x5a) ||
        (codeUnit >= 0x61 && codeUnit <= 0x7a) ||
        codeUnit == 0x5f ||
        codeUnit == 0x2b ||
        codeUnit == 0x2d ||
        codeUnit == 0x28 ||
        codeUnit == 0x29 ||
        codeUnit == 0x2e;
  }
}

final class _CandidateRange {
  const _CandidateRange({required this.start, required this.end});

  final int start;
  final int end;
}
