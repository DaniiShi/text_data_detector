/// Phone parsing strictness.
enum PhoneDetectionMode { strict, loose }

/// Phone detector configuration.
final class PhoneDetectorOptions {
  const PhoneDetectorOptions({
    this.mode = PhoneDetectionMode.strict,
    this.minDigits = 7,
    this.maxDigits = 15,
  });

  /// Detection mode.
  final PhoneDetectionMode mode;

  /// Minimum digit count accepted by the detector.
  final int minDigits;

  /// Maximum digit count accepted by the detector.
  final int maxDigits;
}
