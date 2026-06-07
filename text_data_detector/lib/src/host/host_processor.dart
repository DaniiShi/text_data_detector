import '../psl/public_suffix_registry.dart';
import 'host_normalizer.dart';
import 'host_syntax_validator.dart';

final class HostProcessor {
  HostProcessor({
    this.normalizer = const IdnaHostNormalizer(),
    this.syntaxValidator = const AsciiHostSyntaxValidator(),
  });

  /// Converts Unicode host labels to ASCII before syntax and suffix checks.
  final HostNormalizer normalizer;

  /// Validates ASCII host label syntax.
  final HostSyntaxValidator syntaxValidator;

  final PublicSuffixRegistry _publicSuffixRegistry = PublicSuffixRegistry();

  /// Normalizes and validates [originalHost].
  ///
  /// Link detection accepts hosts that end in a known generated public suffix,
  /// including multi-label suffixes such as `gov.uk` and `github.io` when they
  /// appear by themselves. Single-label TLDs still fail syntax validation, and
  /// obvious local pseudo domains remain rejected.
  HostValidationResult validate(String originalHost) {
    final asciiHost = normalizer.normalizeHostToAscii(originalHost);
    final isValidSyntax = syntaxValidator.isValidAsciiHost(asciiHost);
    final isReservedLocalHost =
        isValidSyntax && _hasReservedLocalSuffix(asciiHost);
    final hasKnownPublicSuffix =
        isValidSyntax && _publicSuffixRegistry.hasPublicSuffix(asciiHost);
    final hasRegistrableDomain =
        isValidSyntax && _publicSuffixRegistry.isRegistrableDomain(asciiHost);

    return HostValidationResult(
      originalHost: originalHost,
      asciiHost: asciiHost,
      isValidSyntax: isValidSyntax,
      isReservedLocalHost: isReservedLocalHost,
      hasKnownPublicSuffix: hasKnownPublicSuffix,
      hasRegistrableDomain: hasRegistrableDomain,
    );
  }

  static bool _hasReservedLocalSuffix(String asciiHost) {
    final labels = asciiHost.split('.');
    if (labels.isEmpty) {
      return false;
    }

    final suffix = labels.last;
    return suffix == 'local' || suffix == 'internal' || suffix == 'localhost';
  }
}

final class HostValidationResult {
  const HostValidationResult({
    required this.originalHost,
    required this.asciiHost,
    required this.isValidSyntax,
    required this.isReservedLocalHost,
    required this.hasKnownPublicSuffix,
    required this.hasRegistrableDomain,
  });

  final String originalHost;
  final String asciiHost;
  final bool isValidSyntax;
  final bool isReservedLocalHost;
  final bool hasKnownPublicSuffix;
  final bool hasRegistrableDomain;

  bool get isValid =>
      isValidSyntax && hasKnownPublicSuffix && !isReservedLocalHost;
}
