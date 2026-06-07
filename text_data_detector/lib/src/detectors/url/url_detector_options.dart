/// Link detector configuration.
final class LinkDetectorOptions {
  const LinkDetectorOptions({
    this.allowCustomSchemes = false,
    this.allowedSchemes = const {'http', 'https', 'ftp', 'ftps', 'ws', 'wss'},
  });

  /// Allows any syntactically valid `scheme://...` deep link.
  ///
  /// Keep this false for web-like URL detection with fewer false positives.
  final bool allowCustomSchemes;

  /// Schemes accepted even when [allowCustomSchemes] is false.
  final Set<String> allowedSchemes;

  /// Returns whether [scheme] is allowed for explicit `scheme://...` links.
  bool allowsScheme(String scheme) {
    return allowedSchemes.contains(scheme) || allowCustomSchemes;
  }
}
