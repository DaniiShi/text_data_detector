import '../../data_detector/data_detector_match.dart';
import '../../data_detector/data_detector_rule.dart';
import '../../host/host_processor.dart';
import 'email_address.dart';
import 'email_detector_options.dart';

/// Detects email addresses and normalizes IDN domains to Punycode.
final class EmailDetector implements DataDetectorRule {
  EmailDetector({
    HostProcessor? hostProcessor,
    this.options = const EmailDetectorOptions(),
  }) : hostProcessor = hostProcessor ?? HostProcessor();

  /// Host validation pipeline used for the email domain.
  final HostProcessor hostProcessor;

  /// Email-specific detection options.
  final EmailDetectorOptions options;

  static final RegExp _candidatePattern = RegExp(
    r'''[^\s<>"'(),;:@]+@[^\s<>"'(),;:@]+\.[^\s<>"'(),;:@]+''',
    caseSensitive: false,
    unicode: true,
  );

  /// Finds email candidates and validates local part plus registrable domain.
  @override
  List<DataDetectorMatch> detect(String text) {
    final matches = <DataDetectorMatch>[];

    for (final match in _candidatePattern.allMatches(text)) {
      final raw = match.group(0);
      if (raw == null) {
        continue;
      }

      final candidate = _trimCandidate(raw);
      if (candidate.isEmpty) {
        continue;
      }
      if (candidate.startsWith('/')) {
        continue;
      }

      if (_isInsideExplicitUrl(text, match.start)) {
        continue;
      }

      final parsed = _parse(candidate);
      if (parsed == null) {
        continue;
      }

      final start = match.start;
      final end = start + candidate.length;
      matches.add(
        DataDetectorMatch(
          type: DataMatchType.emailAddress,
          start: start,
          end: end,
          text: text.substring(start, end),
          normalizedText: parsed.normalized,
          value: parsed.normalized,
        ),
      );
    }

    return matches;
  }

  /// Avoids extracting `//user@example.com` from explicit URL user-info.
  static bool _isInsideExplicitUrl(String text, int start) {
    var tokenStart = start - 1;
    while (tokenStart >= 0 && !_isTokenBoundary(text.codeUnitAt(tokenStart))) {
      tokenStart--;
    }
    return text.substring(tokenStart + 1, start).contains('://');
  }

  /// Token boundary used when scanning backward before an email candidate.
  static bool _isTokenBoundary(int codeUnit) {
    return codeUnit <= 0x20 ||
        codeUnit == 0x22 ||
        codeUnit == 0x27 ||
        codeUnit == 0x28 ||
        codeUnit == 0x3c ||
        codeUnit == 0x5b ||
        codeUnit == 0x7b;
  }

  /// Parses and normalizes one email candidate.
  EmailAddress? _parse(String candidate) {
    final at = candidate.lastIndexOf('@');
    if (at <= 0 || at == candidate.length - 1) {
      return null;
    }

    final localPart = candidate.substring(0, at);
    final originalDomain = _normalizeOriginalDomain(
      candidate.substring(at + 1),
    );
    if (!_isValidLocalPart(localPart)) {
      return null;
    }

    final host = hostProcessor.validate(originalDomain);
    if (!host.isValid || !host.hasRegistrableDomain) {
      return null;
    }

    return EmailAddress(
      localPart: localPart,
      originalDomain: originalDomain,
      asciiDomain: host.asciiHost,
    );
  }

  /// Applies pragmatic local-part validation for detector output.
  bool _isValidLocalPart(String localPart) {
    if (localPart.isEmpty || localPart.length > 64) {
      return false;
    }
    if (localPart.startsWith('.') ||
        localPart.endsWith('.') ||
        localPart.contains('..')) {
      return false;
    }

    for (final rune in localPart.runes) {
      if (!_isAllowedLocalPartRune(rune)) {
        return false;
      }
      if (!options.allowUnicodeLocalPart && rune > 0x7f) {
        return false;
      }
    }
    return true;
  }

  /// Returns whether a rune is allowed in an unquoted local part.
  static bool _isAllowedLocalPartRune(int rune) {
    if (rune <= 0x20 || rune == 0x7f) {
      return false;
    }
    return rune != 0x22 &&
        rune != 0x28 &&
        rune != 0x29 &&
        rune != 0x2c &&
        rune != 0x3a &&
        rune != 0x3b &&
        rune != 0x3c &&
        rune != 0x3e &&
        rune != 0x40 &&
        rune != 0x5b &&
        rune != 0x5c &&
        rune != 0x5d;
  }

  /// Removes sentence punctuation that regex candidates often include.
  static String _trimCandidate(String candidate) {
    var end = candidate.length;
    while (end > 0 && _isTrailingPunctuation(candidate.codeUnitAt(end - 1))) {
      end--;
    }
    return candidate.substring(0, end);
  }

  /// Characters that should not be part of the detected email range.
  static bool _isTrailingPunctuation(int codeUnit) {
    return codeUnit == 0x21 ||
        codeUnit == 0x2c ||
        codeUnit == 0x2e ||
        codeUnit == 0x3a ||
        codeUnit == 0x3b ||
        codeUnit == 0x3f;
  }

  /// Lowercases the domain and removes an optional trailing root dot.
  static String _normalizeOriginalDomain(String domain) {
    final normalized = domain.toLowerCase();
    if (normalized.endsWith('.')) {
      return normalized.substring(0, normalized.length - 1);
    }
    return normalized;
  }
}
