/// Validates normalized ASCII host syntax.
abstract interface class HostSyntaxValidator {
  /// Returns whether [host] is a dotted ASCII host with valid labels.
  bool isValidAsciiHost(String host);
}

/// Syntax validator for ASCII domain names.
final class AsciiHostSyntaxValidator implements HostSyntaxValidator {
  const AsciiHostSyntaxValidator();

  @override
  bool isValidAsciiHost(String host) {
    if (host.length > 253 || !host.contains('.')) {
      return false;
    }

    final labels = host.split('.');
    for (final label in labels) {
      if (label.isEmpty || label.length > 63) {
        return false;
      }
      if (label.startsWith('-') || label.endsWith('-')) {
        return false;
      }
      for (final codeUnit in label.codeUnits) {
        final isDigit = codeUnit >= 0x30 && codeUnit <= 0x39;
        final isLowerAlpha = codeUnit >= 0x61 && codeUnit <= 0x7a;
        final isHyphen = codeUnit == 0x2d;
        if (!isDigit && !isLowerAlpha && !isHyphen) {
          return false;
        }
      }
    }
    return true;
  }
}
