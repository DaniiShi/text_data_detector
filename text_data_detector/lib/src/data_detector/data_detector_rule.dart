import 'data_detector_match.dart';

/// Detects one family of data matches.
///
/// Implement this interface to add custom rules. Return ranges in offsets
/// of the original Dart string; overlapping matches are resolved later by
/// `DataDetector` using match weights and range length.
abstract interface class DataDetectorRule {
  /// Returns all matches detected in [text].
  List<DataDetectorMatch> detect(String text);
}
