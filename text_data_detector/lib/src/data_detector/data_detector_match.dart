/// Stable match type identifier.
///
/// Built-in types are exposed as static constants. Custom detectors can define
/// their own `DataMatchType(...)` values and reuse the same name in emitted
/// matches, `DataDetectorOptions.matchWeights`, and UI code.
final class DataMatchType {
  const DataMatchType(this.name);

  /// Link match, including web URLs and allowed deep links.
  static const link = DataMatchType('link');

  /// Email address match.
  static const emailAddress = DataMatchType('emailAddress');

  /// Phone number match.
  static const phoneNumber = DataMatchType('phoneNumber');

  /// All built-in match types.
  static final Set<DataMatchType> all = Set.unmodifiable({
    link,
    emailAddress,
    phoneNumber,
  });

  /// Human-readable type name, useful for logging and UI fallbacks.
  final String name;

  @override
  bool operator ==(Object other) {
    return other is DataMatchType && other.name == name;
  }

  @override
  int get hashCode => name.hashCode;

  @override
  String toString() => name;
}

/// A detected data match with original string range and normalized value.
final class DataDetectorMatch {
  const DataDetectorMatch({
    required this.type,
    required this.start,
    required this.end,
    required this.text,
    required this.normalizedText,
    this.value,
  });

  /// Match type, either built-in or custom.
  final DataMatchType type;

  /// Inclusive start offset in the original Dart string.
  final int start;

  /// Exclusive end offset in the original Dart string.
  final int end;

  /// Original text slice that was detected.
  final String text;

  /// Normalized value suitable for opening, comparing, or storing.
  final String normalizedText;

  /// Optional typed value for consumers that prefer structured data.
  ///
  /// Built-in link matches use [Uri]. Built-in email and phone matches use
  /// normalized strings. Custom detectors may provide any application value.
  final Object? value;

  /// Parsed URI for link matches, or `null` for non-link matches.
  Uri? get uri {
    if (type != DataMatchType.link) {
      return null;
    }
    final typedValue = value;
    if (typedValue is Uri) {
      return typedValue;
    }
    return Uri.tryParse(normalizedText);
  }

  /// Normalized email address for email matches, or `null` otherwise.
  String? get emailAddress {
    return type == DataMatchType.emailAddress ? normalizedText : null;
  }

  /// Normalized phone number for phone matches, or `null` otherwise.
  String? get phoneNumber {
    return type == DataMatchType.phoneNumber ? normalizedText : null;
  }

  @override
  bool operator ==(Object other) {
    return other is DataDetectorMatch &&
        other.type == type &&
        other.start == start &&
        other.end == end &&
        other.text == text &&
        other.normalizedText == normalizedText;
  }

  @override
  int get hashCode => Object.hash(type, start, end, text, normalizedText);

  @override
  String toString() {
    return 'DataDetectorMatch('
        'type: $type, '
        'start: $start, '
        'end: $end, '
        'text: $text, '
        'normalizedText: $normalizedText, '
        'value: $value'
        ')';
  }
}
