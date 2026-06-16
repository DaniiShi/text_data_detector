import '../detectors/calendar/calendar_event_detector_options.dart';
import '../detectors/email/email_detector_options.dart';
import '../detectors/phone/phone_detector_options.dart';
import '../detectors/url/url_detector_options.dart';
import 'data_detector_match.dart';

/// Configuration for detector behavior and overlap resolution.
final class DataDetectorOptions {
  const DataDetectorOptions({
    this.defaultLinkScheme = 'https',
    this.linkOptions = const LinkDetectorOptions(),
    this.emailOptions = const EmailDetectorOptions(),
    this.phoneOptions = const PhoneDetectorOptions(),
    this.calendarOptions = const CalendarEventDetectorOptions(),
    this.matchWeights = const {},
  });

  /// Scheme used to normalize scheme-less link matches.
  final String defaultLinkScheme;

  /// Link detector behavior, including standard schemes and deep-link support.
  final LinkDetectorOptions linkOptions;

  /// Email detector behavior, including Unicode local-part support.
  final EmailDetectorOptions emailOptions;

  /// Phone detector behavior, including strict vs loose matching.
  final PhoneDetectorOptions phoneOptions;

  /// Calendar detector behavior, used by `CalendarEventDetector` rules that do
  /// not provide their own options.
  final CalendarEventDetectorOptions calendarOptions;

  /// Priority for resolving overlapping entities.
  ///
  /// Higher weight wins. If weights are equal, the longer range wins. Built-in
  /// rules in `DataDetector.baseRules` get default weights unless
  /// overridden here: email 100, link 90, calendar 85, phone 80. Custom match
  /// types default to 0 unless a weight is provided here.
  final Map<DataMatchType, int> matchWeights;
}
