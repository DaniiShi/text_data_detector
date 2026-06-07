final class EmailAddress {
  const EmailAddress({
    required this.localPart,
    required this.originalDomain,
    required this.asciiDomain,
  });

  final String localPart;
  final String originalDomain;
  final String asciiDomain;

  String get normalized => '$localPart@$asciiDomain';
}
