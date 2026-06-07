/// Email detector configuration.
final class EmailDetectorOptions {
  const EmailDetectorOptions({this.allowUnicodeLocalPart = true});

  /// Allows EAI/SMTPUTF8-style Unicode text before the `@`.
  final bool allowUnicodeLocalPart;
}
