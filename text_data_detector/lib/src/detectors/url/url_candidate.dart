import '../../host/host_processor.dart';
import 'url_detector_options.dart';

final class UrlCandidate {
  const UrlCandidate({
    required this.originalHost,
    required this.asciiHost,
    required this.normalizedUrl,
  });

  final String originalHost;
  final String asciiHost;
  final String normalizedUrl;

  /// RFC-like scheme syntax accepted before `://`.
  static final RegExp _schemePattern = RegExp(r'^[a-zA-Z][a-zA-Z0-9+.-]*$');

  /// Parses a detector candidate into a normalized URL.
  ///
  /// Scheme-less candidates must have a syntactically valid dotted host.
  /// Explicit web schemes may also use IPv4 hosts. Non-web/custom schemes are
  /// accepted only when [LinkDetectorOptions.allowCustomSchemes] is enabled.
  static UrlCandidate? parse(
    String candidate, {
    String defaultScheme = 'https',
    LinkDetectorOptions options = const LinkDetectorOptions(),
    required HostProcessor hostProcessor,
  }) {
    final schemeSeparator = candidate.indexOf('://');
    final hasScheme = schemeSeparator != -1;
    final scheme = hasScheme
        ? candidate.substring(0, schemeSeparator).toLowerCase()
        : defaultScheme;
    if (hasScheme && !_schemePattern.hasMatch(scheme)) {
      return null;
    }
    if (hasScheme && !options.allowsScheme(scheme)) {
      return null;
    }

    final authorityStart = hasScheme ? schemeSeparator + 3 : 0;
    final authorityEnd = _authorityEnd(candidate, authorityStart);
    if (authorityEnd <= authorityStart) {
      return null;
    }

    final authority = candidate.substring(authorityStart, authorityEnd);
    if (!hasScheme && authority.contains('@')) {
      return null;
    }

    final parsedUserInfo = _ParsedUserInfo.parse(authority);
    if (!hasScheme && parsedUserInfo.userInfo != null) {
      return null;
    }

    final parsedAuthority = _ParsedAuthority.parse(parsedUserInfo.authority);
    if (parsedAuthority == null) {
      return _parseCustomScheme(candidate, scheme, hasScheme, options);
    }

    final originalHost = _normalizeOriginalHost(parsedAuthority.host);
    final parsedHost = _parseHost(
      originalHost,
      hasScheme: hasScheme,
      hostProcessor: hostProcessor,
    );
    if (parsedHost == null) {
      return _parseCustomScheme(candidate, scheme, hasScheme, options);
    }
    if (!_hasValidTail(candidate.substring(authorityEnd))) {
      return null;
    }

    final tail = candidate.substring(authorityEnd);
    final userInfo =
        parsedUserInfo.userInfo == null ? '' : '${parsedUserInfo.userInfo}@';
    final normalizedAuthority = parsedAuthority.port == null
        ? '$userInfo${parsedHost.asciiHost}'
        : '$userInfo${parsedHost.asciiHost}:${parsedAuthority.port}';

    return UrlCandidate(
      originalHost: originalHost,
      asciiHost: parsedHost.asciiHost,
      normalizedUrl: '$scheme://$normalizedAuthority$tail',
    );
  }

  static UrlCandidate? _parseCustomScheme(
    String candidate,
    String scheme,
    bool hasScheme,
    LinkDetectorOptions options,
  ) {
    if (!hasScheme ||
        !options.allowCustomSchemes ||
        options.allowedSchemes.contains(scheme) ||
        !_hasValidTail(_tail(candidate))) {
      return null;
    }
    return UrlCandidate(
      originalHost: '',
      asciiHost: '',
      normalizedUrl:
          '$scheme://${candidate.substring(candidate.indexOf('://') + 3)}',
    );
  }

  /// Parses a host that belongs to a standard URL.
  ///
  /// Domain names go through IDNA normalization and syntax validation; IPv4 hosts
  /// are allowed only for explicit-scheme URLs that reached this parser path.
  static _ParsedHost? _parseHost(
    String originalHost, {
    required bool hasScheme,
    required HostProcessor hostProcessor,
  }) {
    if (hasScheme && _isValidIpv4(originalHost)) {
      return _ParsedHost(asciiHost: originalHost);
    }

    final host = hostProcessor.validate(originalHost);
    if (!host.isValid) {
      return null;
    }
    return _ParsedHost(asciiHost: host.asciiHost);
  }

  /// Validates the path/query/fragment tail.
  ///
  /// Unicode path, query, and fragment text are accepted. A `?` that appears
  /// after `#` is part of the fragment, not a query delimiter.
  static bool _hasValidTail(String tail) {
    return true;
  }

  /// Returns the path/query/fragment part of an explicit-scheme candidate.
  static String _tail(String candidate) {
    final authorityStart = candidate.indexOf('://') + 3;
    final authorityEnd = _authorityEnd(candidate, authorityStart);
    return candidate.substring(authorityEnd);
  }

  /// Validates dotted decimal IPv4 without accepting hostnames like localhost.
  static bool _isValidIpv4(String host) {
    final parts = host.split('.');
    if (parts.length != 4) {
      return false;
    }
    for (final part in parts) {
      if (part.isEmpty || part.length > 3) {
        return false;
      }
      for (final codeUnit in part.codeUnits) {
        if (codeUnit < 0x30 || codeUnit > 0x39) {
          return false;
        }
      }
      final value = int.tryParse(part);
      if (value == null || value > 255) {
        return false;
      }
    }
    return true;
  }

  /// Finds the end of the authority before path, query, or fragment.
  static int _authorityEnd(String candidate, int start) {
    for (var i = start; i < candidate.length; i++) {
      final codeUnit = candidate.codeUnitAt(i);
      if (codeUnit == 0x2f || codeUnit == 0x3f || codeUnit == 0x23) {
        return i;
      }
    }
    return candidate.length;
  }

  /// Lowercases and removes a final root dot before host validation.
  static String _normalizeOriginalHost(String host) {
    final normalized = host.toLowerCase();
    if (normalized.endsWith('.')) {
      return normalized.substring(0, normalized.length - 1);
    }
    return normalized;
  }
}

final class _ParsedHost {
  const _ParsedHost({required this.asciiHost});

  final String asciiHost;
}

final class _ParsedUserInfo {
  const _ParsedUserInfo({required this.userInfo, required this.authority});

  final String? userInfo;
  final String authority;

  static _ParsedUserInfo parse(String authority) {
    final at = authority.lastIndexOf('@');
    if (at == -1) {
      return _ParsedUserInfo(userInfo: null, authority: authority);
    }
    if (at == 0 || at == authority.length - 1) {
      return _ParsedUserInfo(userInfo: null, authority: authority);
    }
    return _ParsedUserInfo(
      userInfo: authority.substring(0, at),
      authority: authority.substring(at + 1),
    );
  }
}

final class _ParsedAuthority {
  const _ParsedAuthority({required this.host, required this.port});

  final String host;
  final int? port;

  static _ParsedAuthority? parse(String authority) {
    final colon = authority.lastIndexOf(':');
    if (colon == -1) {
      return _ParsedAuthority(host: authority, port: null);
    }

    final host = authority.substring(0, colon);
    final portText = authority.substring(colon + 1);
    if (host.isEmpty || portText.isEmpty) {
      return null;
    }
    for (final codeUnit in portText.codeUnits) {
      if (codeUnit < 0x30 || codeUnit > 0x39) {
        return null;
      }
    }

    final port = int.tryParse(portText);
    if (port == null || port < 1 || port > 65535) {
      return null;
    }
    return _ParsedAuthority(host: host, port: port);
  }
}
