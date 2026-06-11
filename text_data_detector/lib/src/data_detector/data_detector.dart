import '../detectors/calendar/calendar_event_detector.dart';
import '../detectors/email/email_detector.dart';
import '../detectors/phone/phone_detector.dart';
import '../detectors/url/url_candidate.dart';
import '../detectors/url/url_detector.dart';
import '../host/host_processor.dart';
import 'data_detector_match.dart';
import 'data_detector_options.dart';
import 'data_detector_rule.dart';

/// Scans text for links, email addresses, phone numbers, and custom data.
final class DataDetector {
  /// Creates a data detector.
  ///
  /// If [baseRules] is omitted, link, email, and phone rules are used.
  /// Calendar event detection is available through `CalendarEventDetector`,
  /// but is opt-in because dates and times are more prone to false positives.
  /// Pass an empty list to disable built-ins, or pass a custom base list to
  /// replace them. [additionalRules] are appended after the base list.
  factory DataDetector({
    DataDetectorOptions options = const DataDetectorOptions(),
    List<DataDetectorRule>? baseRules,
    List<DataDetectorRule> additionalRules = const [],
  }) {
    final effectiveBaseRules = List<DataDetectorRule>.unmodifiable(
      baseRules ?? _createDefaultBaseRules(options),
    );
    final effectiveAdditionalRules = List<DataDetectorRule>.unmodifiable(
      additionalRules,
    );
    return DataDetector._(
      options: options,
      baseRules: effectiveBaseRules,
      additionalRules: effectiveAdditionalRules,
    );
  }

  DataDetector._({
    required this.options,
    required this.baseRules,
    required this.additionalRules,
  })  : _rules = List<DataDetectorRule>.unmodifiable([
          ...baseRules,
          ...additionalRules,
        ]),
        _matchWeights = _createMatchWeights(
          options,
          baseRules,
          additionalRules,
        );

  /// Detection options used by this detector.
  final DataDetectorOptions options;

  /// Base rule pipeline.
  ///
  /// Built-in rule types in this list receive default overlap weights
  /// unless overridden through [DataDetectorOptions.matchWeights].
  final List<DataDetectorRule> baseRules;

  /// Rules appended after [baseRules].
  ///
  /// Match types emitted only by additional rules default to weight 0
  /// unless a weight is provided in [DataDetectorOptions.matchWeights].
  final List<DataDetectorRule> additionalRules;

  final List<DataDetectorRule> _rules;
  final Map<DataMatchType, int> _matchWeights;

  /// Finds matches in [text] and returns non-overlapping results.
  List<DataDetectorMatch> matches(String text) {
    final matches = <DataDetectorMatch>[];
    for (final rule in _rules) {
      matches.addAll(rule.detect(text));
    }

    matches.sort((a, b) {
      final byStart = a.start.compareTo(b.start);
      return byStart == 0 ? b.end.compareTo(a.end) : byStart;
    });

    return _resolveOverlaps(matches);
  }

  /// Finds matches in [text] and emits them through a stream.
  ///
  /// This keeps the sync detector path available for Flutter text rendering
  /// while offering an async-shaped API for callers that prefer streams.
  Stream<DataDetectorMatch> matchesAsync(String text) async* {
    for (final match in matches(text)) {
      yield match;
    }
  }

  /// Builds the default built-in rule pipeline from options.
  static List<DataDetectorRule> _createDefaultBaseRules(
    DataDetectorOptions options,
  ) {
    final hostProcessor = HostProcessor();
    return [
      LinkDetector(
        defaultScheme: options.defaultLinkScheme,
        options: options.linkOptions,
        hostProcessor: hostProcessor,
      ),
      EmailDetector(
          hostProcessor: hostProcessor, options: options.emailOptions),
      PhoneDetector(options: options.phoneOptions),
    ];
  }

  /// Builds the overlap weights used by this detector.
  ///
  /// Built-in defaults are included only for built-in rule classes present
  /// in [baseRules]. Calendar gets a default weight when explicitly added,
  /// because it is opt-in but still needs to resolve phone-like overlaps.
  /// User-provided weights then override those defaults and may also define
  /// custom match weights.
  static Map<DataMatchType, int> _createMatchWeights(
    DataDetectorOptions options,
    List<DataDetectorRule> baseRules,
    List<DataDetectorRule> additionalRules,
  ) {
    final allRules = [...baseRules, ...additionalRules];
    return {
      if (baseRules.any((rule) => rule is EmailDetector))
        DataMatchType.emailAddress: 100,
      if (baseRules.any((rule) => rule is LinkDetector)) DataMatchType.link: 90,
      if (allRules.any((rule) => rule is CalendarEventDetector))
        DataMatchType.calendarEvent: 85,
      if (baseRules.any((rule) => rule is PhoneDetector))
        DataMatchType.phoneNumber: 80,
      ...options.matchWeights,
    };
  }

  /// Keeps only the best match for each overlapping range.
  List<DataDetectorMatch> _resolveOverlaps(List<DataDetectorMatch> matches) {
    if (matches.length < 2) {
      return matches;
    }

    final result = <DataDetectorMatch>[];
    for (final match in matches) {
      if (result.isEmpty || match.start >= result.last.end) {
        result.add(match);
        continue;
      }

      final previous = result.last;
      if (_isBetterOverlap(match, previous)) {
        final trimmedPrevious = _trimPreviousForBetterMatch(previous, match);
        if (trimmedPrevious == null) {
          result[result.length - 1] = match;
        } else {
          result[result.length - 1] = trimmedPrevious;
          result.add(match);
        }
      }
    }
    return result;
  }

  /// Trims a lower-priority link so a stronger embedded match can remain.
  ///
  /// This lets `example.com/#tag` become `example.com/` plus `#tag` when the
  /// custom hashtag type has a higher weight than links. Non-link matches are
  /// not split, so generic custom overlap behavior stays simple and predictable.
  DataDetectorMatch? _trimPreviousForBetterMatch(
    DataDetectorMatch previous,
    DataDetectorMatch betterMatch,
  ) {
    if (previous.type != DataMatchType.link ||
        betterMatch.start <= previous.start ||
        betterMatch.start >= previous.end) {
      return null;
    }

    final text = previous.text.substring(0, betterMatch.start - previous.start);
    final parsed = UrlCandidate.parse(
      text,
      defaultScheme: options.defaultLinkScheme,
      options: options.linkOptions,
      hostProcessor: HostProcessor(),
    );
    if (parsed == null) {
      return null;
    }

    return DataDetectorMatch(
      type: previous.type,
      start: previous.start,
      end: betterMatch.start,
      text: text,
      normalizedText: parsed.normalizedUrl,
      value: Uri.parse(parsed.normalizedUrl),
    );
  }

  /// Compares overlapping matches by configured weight, then by range length.
  bool _isBetterOverlap(
    DataDetectorMatch candidate,
    DataDetectorMatch current,
  ) {
    final candidatePriority = _priority(candidate.type);
    final currentPriority = _priority(current.type);
    if (candidatePriority != currentPriority) {
      return candidatePriority > currentPriority;
    }

    final candidateLength = candidate.end - candidate.start;
    final currentLength = current.end - current.start;
    if (candidateLength != currentLength) {
      return candidateLength > currentLength;
    }
    return false;
  }

  /// Returns the effective overlap weight for [type].
  int _priority(DataMatchType type) {
    return _matchWeights[type] ?? 0;
  }
}
