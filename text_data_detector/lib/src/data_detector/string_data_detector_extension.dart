import 'data_detector.dart';
import 'data_detector_match.dart';
import 'data_detector_options.dart';
import 'data_detector_rule.dart';

/// Convenience methods for scanning a string with [DataDetector].
extension StringDataDetectorExtension on String {
  /// Returns non-overlapping data detector matches found in this string.
  ///
  /// Pass [baseRules] to replace built-in rules, or [additionalRules] to append
  /// custom detectors for this one-off scan.
  List<DataDetectorMatch> dataDetectorMatches({
    DataDetectorOptions options = const DataDetectorOptions(),
    List<DataDetectorRule>? baseRules,
    List<DataDetectorRule> additionalRules = const [],
  }) {
    return DataDetector(
      options: options,
      baseRules: baseRules,
      additionalRules: additionalRules,
    ).matches(this);
  }

  /// Streams data detector matches found in this string.
  ///
  /// This mirrors the async shape of system data detector APIs while still
  /// using the same synchronous detector implementation under the hood.
  Stream<DataDetectorMatch> dataDetectorMatchesAsync({
    DataDetectorOptions options = const DataDetectorOptions(),
    List<DataDetectorRule>? baseRules,
    List<DataDetectorRule> additionalRules = const [],
  }) {
    return DataDetector(
      options: options,
      baseRules: baseRules,
      additionalRules: additionalRules,
    ).matchesAsync(this);
  }
}
