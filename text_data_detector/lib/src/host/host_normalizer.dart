/// Converts user-visible host text to ASCII form for validation.
abstract interface class HostNormalizer {
  /// Returns an ASCII host, usually by lowercasing and Punycode-encoding labels.
  String normalizeHostToAscii(String host);
}

/// IDNA-like host normalizer for detector use.
final class IdnaHostNormalizer implements HostNormalizer {
  const IdnaHostNormalizer();

  @override
  String normalizeHostToAscii(String host) {
    final normalizedHost = _normalizeDots(host.toLowerCase());
    final withoutTrailingDot = normalizedHost.endsWith('.')
        ? normalizedHost.substring(0, normalizedHost.length - 1)
        : normalizedHost;

    final labels = withoutTrailingDot.split('.');
    final asciiLabels = <String>[];
    for (final label in labels) {
      if (label.isEmpty) {
        asciiLabels.add(label);
        continue;
      }
      asciiLabels.add(
        _isAscii(label) ? label : 'xn--${_Punycode.encode(label)}',
      );
    }
    return asciiLabels.join('.');
  }

  static bool _isAscii(String value) {
    for (final codeUnit in value.codeUnits) {
      if (codeUnit > 0x7f) {
        return false;
      }
    }
    return true;
  }

  static String _normalizeDots(String value) {
    return value
        .replaceAll('\u3002', '.')
        .replaceAll('\uff0e', '.')
        .replaceAll('\uff61', '.');
  }
}

final class _Punycode {
  const _Punycode._();

  static const _base = 36;
  static const _tMin = 1;
  static const _tMax = 26;
  static const _skew = 38;
  static const _damp = 700;
  static const _initialBias = 72;
  static const _initialN = 128;
  static const _delimiter = 0x2d;

  static String encode(String input) {
    final codePoints = input.runes.toList();
    final output = StringBuffer();

    var handled = 0;
    for (final codePoint in codePoints) {
      if (_isBasic(codePoint)) {
        output.writeCharCode(codePoint);
        handled++;
      }
    }

    final basicLength = handled;
    if (basicLength > 0 && basicLength < codePoints.length) {
      output.writeCharCode(_delimiter);
    }

    var n = _initialN;
    var delta = 0;
    var bias = _initialBias;

    while (handled < codePoints.length) {
      var m = 0x10ffff;
      for (final codePoint in codePoints) {
        if (codePoint >= n && codePoint < m) {
          m = codePoint;
        }
      }

      delta += (m - n) * (handled + 1);
      n = m;

      for (final codePoint in codePoints) {
        if (codePoint < n) {
          delta++;
          continue;
        }
        if (codePoint != n) {
          continue;
        }

        var q = delta;
        for (var k = _base;; k += _base) {
          final t = _threshold(k, bias);
          if (q < t) {
            break;
          }

          output.writeCharCode(_encodeDigit(t + ((q - t) % (_base - t))));
          q = (q - t) ~/ (_base - t);
        }

        output.writeCharCode(_encodeDigit(q));
        bias = _adapt(delta, handled + 1, handled == basicLength);
        delta = 0;
        handled++;
      }

      delta++;
      n++;
    }

    return output.toString();
  }

  static bool _isBasic(int codePoint) => codePoint < 0x80;

  static int _threshold(int k, int bias) {
    if (k <= bias + _tMin) {
      return _tMin;
    }
    if (k >= bias + _tMax) {
      return _tMax;
    }
    return k - bias;
  }

  static int _adapt(int delta, int numberOfPoints, bool firstTime) {
    var adjustedDelta = firstTime ? delta ~/ _damp : delta ~/ 2;
    adjustedDelta += adjustedDelta ~/ numberOfPoints;

    var k = 0;
    while (adjustedDelta > ((_base - _tMin) * _tMax) ~/ 2) {
      adjustedDelta ~/= _base - _tMin;
      k += _base;
    }

    return k +
        (((_base - _tMin + 1) * adjustedDelta) ~/ (adjustedDelta + _skew));
  }

  static int _encodeDigit(int digit) {
    if (digit < 26) {
      return 0x61 + digit;
    }
    return 0x30 + digit - 26;
  }
}
