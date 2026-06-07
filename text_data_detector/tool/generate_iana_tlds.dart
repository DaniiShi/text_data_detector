import 'dart:io';

const _generatedPath = 'lib/src/psl/generated/public_suffix_data.g.dart';

const _extraExactRules = <String>['ac.uk', 'co.uk', 'gov.uk', 'github.io'];

Future<void> main(List<String> args) async {
  if (args.length != 1) {
    stderr.writeln(
      'Usage: dart run tool/generate_iana_tlds.dart <tlds-alpha-by-domain.txt>',
    );
    exitCode = 64;
    return;
  }

  final source = File(args.single);
  if (!source.existsSync()) {
    stderr.writeln('TLD source file not found: ${source.path}');
    exitCode = 66;
    return;
  }

  final lines = await source.readAsLines();
  final versionLine = lines.firstWhere(
    (line) => line.startsWith('#'),
    orElse: () => '# Version unknown',
  );

  final exactByTld = <String, Set<String>>{};
  for (final line in lines) {
    if (line.isEmpty || line.startsWith('#')) {
      continue;
    }

    final tld = line.toLowerCase();
    exactByTld.putIfAbsent(tld, () => <String>{}).add(tld);
  }

  for (final rule in _extraExactRules) {
    final tld = rule.split('.').last;
    exactByTld.putIfAbsent(tld, () => <String>{}).add(rule);
  }

  final buffer = StringBuffer()
    ..writeln('// GENERATED CODE - DO NOT MODIFY BY HAND.')
    ..writeln('// Source: https://data.iana.org/TLD/tlds-alpha-by-domain.txt')
    ..writeln('// $versionLine')
    ..writeln('//')
    ..writeln(
      '// Multi-label additions are seed Public Suffix List rules used by tests',
    )
    ..writeln(
      '// until the full PSL generator replaces this IANA-only generator.',
    )
    ..writeln()
    ..writeln('const Map<String, PublicSuffixBucket> publicSuffixBuckets = {');

  final tlds = exactByTld.keys.toList()..sort();
  for (final tld in tlds) {
    final exact = exactByTld[tld]!.toList()
      ..sort((a, b) {
        final byLabels = a.split('.').length.compareTo(b.split('.').length);
        return byLabels == 0 ? a.compareTo(b) : byLabels;
      });
    buffer.writeln(
      "  '$tld': PublicSuffixBucket(exact: ${_dartStringList(exact)}),",
    );
  }

  buffer
    ..writeln('};')
    ..writeln()
    ..writeln('final class PublicSuffixBucket {')
    ..writeln('  const PublicSuffixBucket({')
    ..writeln('    this.exact = const [],')
    ..writeln('    this.wildcard = const [],')
    ..writeln('    this.exception = const [],')
    ..writeln('  });')
    ..writeln()
    ..writeln('  final List<String> exact;')
    ..writeln('  final List<String> wildcard;')
    ..writeln('  final List<String> exception;')
    ..writeln('}');

  await File(_generatedPath).writeAsString(buffer.toString());
}

String _dartStringList(List<String> values) {
  return '[${values.map((value) => "'$value'").join(', ')}]';
}
