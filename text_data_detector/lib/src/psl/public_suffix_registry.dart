import 'generated/public_suffix_data.g.dart';

final class PublicSuffixRegistry {
  PublicSuffixRegistry();

  /// Returns true when [host] has a registrable label before its public suffix.
  bool isRegistrableDomain(String host) {
    return registrableDomain(host) != null;
  }

  /// Returns true when [host] ends with a known public suffix rule.
  ///
  /// Unlike [isRegistrableDomain], this also returns true for the public suffix
  /// itself, such as `gov.uk` or `github.io`.
  bool hasPublicSuffix(String host) {
    final labels = _normalizeHost(host).split('.');
    if (labels.isEmpty) {
      return false;
    }
    return _publicSuffixLength(labels) != null;
  }

  /// Returns the registrable domain for [host], or null for public suffixes.
  String? registrableDomain(String host) {
    final labels = _normalizeHost(host).split('.');
    if (labels.length < 2) {
      return null;
    }

    final suffixLength = _publicSuffixLength(labels);
    if (suffixLength == null || labels.length <= suffixLength) {
      return null;
    }

    return labels.sublist(labels.length - suffixLength - 1).join('.');
  }

  /// Returns the length of the best matching public suffix rule.
  int? _publicSuffixLength(List<String> labels) {
    final bucket = publicSuffixBuckets[labels.last];
    if (bucket == null) {
      return null;
    }

    final exception = _longestMatchingRule(labels, bucket.exception);
    if (exception != null) {
      return exception - 1;
    }

    final exact = _longestMatchingRule(labels, bucket.exact);
    final wildcard = _longestMatchingWildcard(labels, bucket.wildcard);
    final exactLength = exact ?? 0;
    final wildcardLength = wildcard ?? 0;
    final prevailingLength =
        exactLength > wildcardLength ? exactLength : wildcardLength;

    if (prevailingLength == 0) {
      return null;
    }
    return prevailingLength;
  }

  /// Finds the longest exact or exception rule matching the host labels.
  int? _longestMatchingRule(List<String> labels, List<String> rules) {
    int? longest;
    for (final rule in rules) {
      final ruleLabels = rule.split('.');
      if (ruleLabels.length > labels.length) {
        continue;
      }
      if (_endsWithLabels(labels, ruleLabels)) {
        final length = ruleLabels.length;
        if (longest == null || length > longest) {
          longest = length;
        }
      }
    }
    return longest;
  }

  /// Finds the longest wildcard rule matching the host labels.
  int? _longestMatchingWildcard(List<String> labels, List<String> rules) {
    int? longest;
    for (final rule in rules) {
      final ruleLabels = rule.split('.');
      if (ruleLabels.length > labels.length) {
        continue;
      }
      if (ruleLabels.first != '*') {
        continue;
      }

      final suffix = ruleLabels.sublist(1);
      if (_endsWithLabels(labels, suffix)) {
        final length = ruleLabels.length;
        if (longest == null || length > longest) {
          longest = length;
        }
      }
    }
    return longest;
  }

  /// Returns true when [labels] ends with [suffix].
  bool _endsWithLabels(List<String> labels, List<String> suffix) {
    if (suffix.length > labels.length) {
      return false;
    }

    final offset = labels.length - suffix.length;
    for (var i = 0; i < suffix.length; i++) {
      if (labels[offset + i] != suffix[i]) {
        return false;
      }
    }
    return true;
  }

  /// Lowercases [host] and removes a trailing root dot.
  String _normalizeHost(String host) {
    final normalized = host.toLowerCase();
    if (normalized.endsWith('.')) {
      return normalized.substring(0, normalized.length - 1);
    }
    return normalized;
  }
}
