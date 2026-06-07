import '../../data_detector/data_detector_match.dart';
import '../../data_detector/data_detector_rule.dart';
import '../../host/host_processor.dart';
import 'url_candidate.dart';
import 'url_detector_options.dart';

/// Detects web URLs and optionally custom `scheme://` deep links.
final class LinkDetector implements DataDetectorRule {
  LinkDetector({
    this.defaultScheme = 'https',
    this.options = const LinkDetectorOptions(),
    HostProcessor? hostProcessor,
  }) : hostProcessor = hostProcessor ?? HostProcessor();

  /// Scheme used when a detected link has no explicit scheme.
  final String defaultScheme;

  /// Link-specific detection options.
  final LinkDetectorOptions options;

  /// Host validation pipeline used for URL authorities.
  final HostProcessor hostProcessor;

  static final RegExp _candidatePattern = RegExp(
    r'''(?:^|[^A-Za-z0-9@_-])([A-Za-z][A-Za-z0-9+.-]*:\/\/[^\s<>"']+|\.?(?:[^\s<>"'@,;:\/?#\(\)\[\]\{\}]+\.)+[^\s<>"'@,;:\/?#\(\)\[\]\{\}]+(?::\d{1,5})?(?:[/?#][^\s<>"']*)?)''',
    caseSensitive: false,
    unicode: true,
  );

  /// Finds broad URL-like spans, trims text punctuation, then validates them.
  @override
  List<DataDetectorMatch> detect(String text) {
    final matches = <DataDetectorMatch>[];

    for (final match in _candidatePattern.allMatches(text)) {
      final raw = match.group(1);
      if (raw == null) {
        continue;
      }

      final range = _trimCandidateRange(raw, match.end - raw.length);
      if (range == null) {
        continue;
      }
      final candidate = text.substring(range.start, range.end);

      final parsed = UrlCandidate.parse(
        candidate,
        defaultScheme: defaultScheme,
        options: options,
        hostProcessor: hostProcessor,
      );
      if (parsed == null) {
        continue;
      }

      final start = range.start;
      if (_startsAfterInvalidSchemeSeparator(text, start)) {
        continue;
      }
      if (_startsInsideHostLikeToken(text, start)) {
        continue;
      }
      final end = range.end;
      matches.add(
        DataDetectorMatch(
          type: DataMatchType.link,
          start: start,
          end: end,
          text: text.substring(start, end),
          normalizedText: parsed.normalizedUrl,
          value: Uri.parse(parsed.normalizedUrl),
        ),
      );
    }

    return matches;
  }

  static _CandidateRange? _trimCandidateRange(String candidate, int offset) {
    var start = _leadingTrimStart(candidate);
    var end = candidate.length;
    end = _trimBareQuery(candidate, start, end);
    end = _trimBareFragment(candidate, start, end);
    end = _trimBareEmptyQueryFragment(candidate, start, end);
    while (end > start && _shouldTrimTrailing(candidate, start, end)) {
      end--;
    }
    if (start == end || candidate.codeUnitAt(start) == 0x2f) {
      return null;
    }
    return _CandidateRange(start: offset + start, end: offset + end);
  }

  /// Trims `host?query` to `host` unless the query belongs to a path.
  static int _trimBareQuery(String candidate, int start, int end) {
    if (candidate.contains('://')) {
      return end;
    }
    final authorityStart = _authorityStart(candidate, start, end);
    final question = candidate.indexOf('?', authorityStart);
    if (question == -1 || question >= end) {
      return end;
    }

    final fragment = candidate.indexOf('#', authorityStart);
    if (fragment != -1 && fragment < question) {
      return end;
    }

    final slash = candidate.indexOf('/', authorityStart);
    if (slash != -1 && slash < question) {
      return end;
    }
    return question;
  }

  /// Trims `host#fragment` to `host` unless the fragment belongs to a path.
  static int _trimBareFragment(String candidate, int start, int end) {
    if (candidate.contains('://')) {
      return end;
    }
    final authorityStart = _authorityStart(candidate, start, end);
    final fragment = candidate.indexOf('#', authorityStart);
    if (fragment == -1 || fragment >= end) {
      return end;
    }

    final slash = candidate.indexOf('/', authorityStart);
    if (slash != -1 && slash < fragment) {
      return end;
    }
    return fragment;
  }

  /// Trims `host?#` to `host` while preserving path-based forms like `host/?#`.
  static int _trimBareEmptyQueryFragment(String candidate, int start, int end) {
    if (candidate.contains('://')) {
      return end;
    }
    final authorityStart = _authorityStart(candidate, start, end);
    final question = candidate.indexOf('?', authorityStart);
    if (question == -1 ||
        question + 1 >= end ||
        candidate.codeUnitAt(question + 1) != 0x23 ||
        question + 2 != end) {
      return end;
    }

    final slash = candidate.indexOf('/', authorityStart);
    if (slash != -1 && slash < question) {
      return end;
    }
    return question;
  }

  /// Finds where the authority starts for scheme-less and explicit URLs.
  static int _authorityStart(String candidate, int start, int end) {
    final schemeSeparator = candidate.indexOf('://', start);
    if (schemeSeparator == -1 || schemeSeparator + 3 >= end) {
      return start;
    }
    return schemeSeparator + 3;
  }

  /// Returns whether the final character should be treated as outside text.
  static bool _shouldTrimTrailing(String candidate, int start, int end) {
    final codeUnit = candidate.codeUnitAt(end - 1);
    if (codeUnit == 0x3f &&
        _isStructuralTrailingQuestion(candidate, start, end)) {
      return false;
    }
    return _isTrailingPunctuation(codeUnit);
  }

  /// Keeps empty query markers when a path is present, e.g. `example.com/?`.
  static bool _isStructuralTrailingQuestion(
    String candidate,
    int start,
    int end,
  ) {
    final authorityStart = _authorityStart(candidate, start, end);
    final slash = candidate.indexOf('/', authorityStart);
    return slash != -1 && slash < end - 1;
  }

  /// Removes opening punctuation or symbols captured before a scheme-less host.
  ///
  /// This is what lets `👉example.com`, `(example.com)`, and `.example.com`
  /// report the original range for `example.com` only.
  static int _leadingTrimStart(String candidate) {
    if (candidate.contains('://')) {
      return 0;
    }

    var start = 0;
    while (start < candidate.length &&
        _isLeadingPunctuation(candidate.codeUnitAt(start))) {
      start++;
    }

    final firstDot = candidate.indexOf('.');
    if (firstDot == -1) {
      return start;
    }

    for (var i = 0; i < firstDot; i++) {
      if (!_isHostLabelCodeUnit(candidate.codeUnitAt(i))) {
        start = i + 1;
      }
    }
    return start;
  }

  /// Returns true for wrapper characters that may appear before a URL.
  static bool _isLeadingPunctuation(int codeUnit) {
    return codeUnit == 0x2e ||
        codeUnit == 0xab ||
        codeUnit == 0x201c ||
        codeUnit == 0x22 ||
        codeUnit == 0x27 ||
        codeUnit == 0x28 ||
        codeUnit == 0x3c ||
        codeUnit == 0x5b ||
        codeUnit == 0x7b;
  }

  /// Returns true for characters that may appear inside an IDN host label.
  static bool _isHostLabelCodeUnit(int codeUnit) {
    final isDigit = codeUnit >= 0x30 && codeUnit <= 0x39;
    final isUpperAlpha = codeUnit >= 0x41 && codeUnit <= 0x5a;
    final isLowerAlpha = codeUnit >= 0x61 && codeUnit <= 0x7a;
    final isNonAsciiLetter = codeUnit > 0x7f &&
        (codeUnit < 0xd800 || codeUnit > 0xdfff) &&
        codeUnit != 0xab &&
        codeUnit != 0xbb &&
        codeUnit != 0x2018 &&
        codeUnit != 0x201c &&
        codeUnit != 0x201d &&
        codeUnit != 0x2030 &&
        codeUnit != 0x200b &&
        codeUnit != 0xfeff;
    return isDigit ||
        isUpperAlpha ||
        isLowerAlpha ||
        isNonAsciiLetter ||
        codeUnit == 0x2d;
  }

  /// Prevents recovering `example.com` from an invalid `bad://example.com`.
  static bool _startsAfterInvalidSchemeSeparator(String text, int start) {
    if (start < 3 ||
        text.codeUnitAt(start - 3) != 0x3a ||
        text.codeUnitAt(start - 2) != 0x2f ||
        text.codeUnitAt(start - 1) != 0x2f) {
      return false;
    }

    var schemeStart = start - 4;
    while (
        schemeStart >= 0 && !_isSchemeBoundary(text.codeUnitAt(schemeStart))) {
      schemeStart--;
    }
    return schemeStart < start - 4;
  }

  /// Prevents recovering a partial domain from inside a larger token.
  static bool _startsInsideHostLikeToken(String text, int start) {
    if (start == 0) {
      return false;
    }

    final previous = text.codeUnitAt(start - 1);
    return previous == 0x40 || _isHostLabelCodeUnit(previous);
  }

  /// Boundaries used while scanning backwards before a `://` separator.
  static bool _isSchemeBoundary(int codeUnit) {
    return codeUnit <= 0x20 ||
        codeUnit == 0x22 ||
        codeUnit == 0x27 ||
        codeUnit == 0x28 ||
        codeUnit == 0x3c ||
        codeUnit == 0x5b ||
        codeUnit == 0x7b;
  }

  /// Sentence/wrapper punctuation that should not be part of the final range.
  static bool _isTrailingPunctuation(int codeUnit) {
    return codeUnit == 0x21 ||
        codeUnit == 0x29 ||
        codeUnit == 0x2c ||
        codeUnit == 0x2e ||
        codeUnit == 0x3a ||
        codeUnit == 0x3b ||
        codeUnit == 0x3f ||
        codeUnit == 0x5d ||
        codeUnit == 0x7d ||
        codeUnit == 0xbb ||
        codeUnit == 0x201d ||
        codeUnit == 0xfeff ||
        codeUnit == 0x200b;
  }
}

final class _CandidateRange {
  const _CandidateRange({required this.start, required this.end});

  final int start;
  final int end;
}
