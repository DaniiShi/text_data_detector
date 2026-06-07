import 'data_detector.dart';
import 'data_detector_match.dart';
import 'data_detector_options.dart';

/// Convenience methods for scanning a string with [DataDetector].
extension StringDataDetectorExtension on String {
  /// Returns non-overlapping data detector matches found in this string.
  ///
  /// Pass [detector] when you want to reuse a configured detector. Otherwise a
  /// temporary detector is created from [options].
  List<DataDetectorMatch> dataDetectorMatches({
    DataDetector? detector,
    DataDetectorOptions options = const DataDetectorOptions(),
  }) {
    return (detector ?? DataDetector(options: options)).matches(this);
  }

  /// Streams data detector matches found in this string.
  ///
  /// This mirrors the async shape of system data detector APIs while still
  /// using the same synchronous detector implementation under the hood.
  Stream<DataDetectorMatch> dataDetectorMatchesAsync({
    DataDetector? detector,
    DataDetectorOptions options = const DataDetectorOptions(),
  }) {
    return (detector ?? DataDetector(options: options)).matchesAsync(this);
  }
}
