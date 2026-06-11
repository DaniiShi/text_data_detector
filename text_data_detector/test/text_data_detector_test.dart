import 'package:text_data_detector/text_data_detector.dart';
import 'package:test/test.dart';

void main() {
  group('DataDetector', () {
    late DataDetector detector;

    setUp(() {
      detector = DataDetector();
    });

    test('detects and normalizes URLs', () {
      expect(detector.matches('Visit example.com or https://flutter.dev'), [
        const DataDetectorMatch(
          type: DataMatchType.link,
          start: 6,
          end: 17,
          text: 'example.com',
          normalizedText: 'https://example.com',
        ),
        const DataDetectorMatch(
          type: DataMatchType.link,
          start: 21,
          end: 40,
          text: 'https://flutter.dev',
          normalizedText: 'https://flutter.dev',
        ),
      ]);
    });

    test('supports string extension scans', () {
      expect('Visit example.com'.dataDetectorMatches(), [
        const DataDetectorMatch(
          type: DataMatchType.link,
          start: 6,
          end: 17,
          text: 'example.com',
          normalizedText: 'https://example.com',
        ),
      ]);
    });

    test('streams matches through async API', () async {
      final result = await detector.matchesAsync('Visit example.com').toList();

      expect(result, [
        const DataDetectorMatch(
          type: DataMatchType.link,
          start: 6,
          end: 17,
          text: 'example.com',
          normalizedText: 'https://example.com',
        ),
      ]);
    });

    test('compares match types by name', () {
      final first = DataMatchType('custom');
      final second = DataMatchType('custom');

      expect(first, second);
      expect({first: 10}[second], 10);
    });

    test('exposes typed values for built-in matches', () {
      final link = detector.matches('Visit example.com').single;
      final email = detector.matches('Email john@example.com').single;
      final phone = detector.matches('Call +19995551122').single;

      expect(link.uri, Uri.parse('https://example.com'));
      expect(email.emailAddress, 'john@example.com');
      expect(phone.phoneNumber, '+19995551122');
    });

    test('matches dotted hosts even when they are public suffixes', () {
      expect(detector.matches('Open gov.uk github.io example.co.uk'), [
        const DataDetectorMatch(
          type: DataMatchType.link,
          start: 5,
          end: 11,
          text: 'gov.uk',
          normalizedText: 'https://gov.uk',
        ),
        const DataDetectorMatch(
          type: DataMatchType.link,
          start: 12,
          end: 21,
          text: 'github.io',
          normalizedText: 'https://github.io',
        ),
        const DataDetectorMatch(
          type: DataMatchType.link,
          start: 22,
          end: 35,
          text: 'example.co.uk',
          normalizedText: 'https://example.co.uk',
        ),
      ]);
    });

    test('matches registrable hosts above public suffixes', () {
      expect(detector.matches('Open example.co.uk and example.github.io'), [
        const DataDetectorMatch(
          type: DataMatchType.link,
          start: 5,
          end: 18,
          text: 'example.co.uk',
          normalizedText: 'https://example.co.uk',
        ),
        const DataDetectorMatch(
          type: DataMatchType.link,
          start: 23,
          end: 40,
          text: 'example.github.io',
          normalizedText: 'https://example.github.io',
        ),
      ]);
    });

    test('rejects single-label tlds', () {
      expect(detector.matches('Ignore com uk io au'), isEmpty);
    });

    test('rejects dotted hosts with unknown suffixes', () {
      expect(detector.matches('Ignore ф.ф and example.notatld'), isEmpty);
    });

    test('matches deeply dotted domains with known public suffixes', () {
      expect(detector.matches('a.a.a.a.au'), [
        const DataDetectorMatch(
          type: DataMatchType.link,
          start: 0,
          end: 10,
          text: 'a.a.a.a.au',
          normalizedText: 'https://a.a.a.a.au',
        ),
      ]);
    });

    test('trims punctuation from link ranges', () {
      expect(detector.matches('Docs: https://flutter.dev.'), [
        const DataDetectorMatch(
          type: DataMatchType.link,
          start: 6,
          end: 25,
          text: 'https://flutter.dev',
          normalizedText: 'https://flutter.dev',
        ),
      ]);
    });

    test('keeps URL ports and paths', () {
      expect(detector.matches('Local docs https://example.com:8443/path?q=1'), [
        const DataDetectorMatch(
          type: DataMatchType.link,
          start: 11,
          end: 44,
          text: 'https://example.com:8443/path?q=1',
          normalizedText: 'https://example.com:8443/path?q=1',
        ),
      ]);
    });

    test('detects standard explicit scheme URLs', () {
      final result = detector.matches(
        'Open http://example.com https://example.com ftp://example.com/file',
      );

      expect(result.map((entity) => entity.text).toList(), [
        'http://example.com',
        'https://example.com',
        'ftp://example.com/file',
      ]);
    });

    test('detects deep links only when custom schemes are allowed', () async {
      final deepLinkDetector = DataDetector(
        options: const DataDetectorOptions(
          linkOptions: LinkDetectorOptions(allowCustomSchemes: true),
        ),
      );

      const text = 'Open myapp://profile/123 and tg://resolve?domain=dasa';

      expect(detector.matches(text), isEmpty);
      expect(deepLinkDetector.matches(text).map((entity) => entity.text), [
        'myapp://profile/123',
        'tg://resolve?domain=dasa',
      ]);
      expect(
        deepLinkDetector.matches(text).map((entity) => entity.normalizedText),
        ['myapp://profile/123', 'tg://resolve?domain=dasa'],
      );
    });

    test('rejects invalid explicit URL schemes', () {
      expect(
        detector.matches('Ignore bad_scheme://example.com 1bad://profile'),
        isEmpty,
      );
    });

    test('trims zero width URL terminators', () {
      expect(detector.matches('Go example.com\u200B example.com\uFEFF'), [
        const DataDetectorMatch(
          type: DataMatchType.link,
          start: 3,
          end: 14,
          text: 'example.com',
          normalizedText: 'https://example.com',
        ),
        const DataDetectorMatch(
          type: DataMatchType.link,
          start: 16,
          end: 27,
          text: 'example.com',
          normalizedText: 'https://example.com',
        ),
      ]);
    });

    test('detects percent encoded paths', () {
      expect(
        detector
            .matches(
              'Paths example.com/a%20b example.com/%D0%BF%D1%83%D1%82%D1%8C',
            )
            .map((entity) => entity.text),
        ['example.com/a%20b', 'example.com/%D0%BF%D1%83%D1%82%D1%8C'],
      );
    });

    test('accepts hyphenated host labels except edge hyphens', () {
      expect(
        detector
            .matches('Sites my-site.com and a-b.example.com')
            .map((entity) => entity.text),
        ['my-site.com', 'a-b.example.com'],
      );
      expect(detector.matches('-example.com example-.com'), isEmpty);
    });

    test('uses URL boundaries around punctuation and symbols', () {
      expect(
        detector.matches('look👉example.com').single.text,
        'example.com',
      );
      expect(detector.matches('@example.com'), isEmpty);
      expect(detector.matches('https:// http:// example.'), isEmpty);
      expect(detector.matches('://example.com').single.text, 'example.com');
      expect(detector.matches('.example.com').single.text, 'example.com');
    });

    test('detects adjacent URLs separated by punctuation or whitespace', () {
      expect(
        detector
            .matches(
              'example.com,google.com example.com google.com;example.com;google.com',
            )
            .map((entity) => entity.text),
        [
          'example.com',
          'google.com',
          'example.com',
          'google.com',
          'example.com',
          'google.com',
        ],
      );
    });

    test('accepts unicode paths and trims bare unicode queries', () {
      expect(
        detector
            .matches('example.com/путь example.com/搜索 example.com/😀')
            .map((entity) => entity.text),
        ['example.com/путь', 'example.com/搜索', 'example.com/😀'],
      );
      expect(detector.matches('example.com?q=тест'), [
        const DataDetectorMatch(
          type: DataMatchType.link,
          start: 0,
          end: 11,
          text: 'example.com',
          normalizedText: 'https://example.com',
        ),
      ]);
    });

    test('accepts idn links with unicode path and fragment question mark', () {
      expect(detector.matches('öffne ä.de/pfad#teil?frage'), [
        const DataDetectorMatch(
          type: DataMatchType.link,
          start: 6,
          end: 26,
          text: 'ä.de/pfad#teil?frage',
          normalizedText: 'https://xn--4ca.de/pfad#teil?frage',
        ),
      ]);
    });

    test('accepts idn path with unicode query and fragment', () {
      expect(detector.matches('öffne ä.de/pfad?größe#teil'), [
        const DataDetectorMatch(
          type: DataMatchType.link,
          start: 6,
          end: 26,
          text: 'ä.de/pfad?größe#teil',
          normalizedText: 'https://xn--4ca.de/pfad?größe#teil',
        ),
      ]);
    });

    test('keeps empty idn path query and fragment tails', () {
      expect(detector.matches('ä.de/?# ä.de/# ä.de/? ä.de?#'), [
        const DataDetectorMatch(
          type: DataMatchType.link,
          start: 0,
          end: 7,
          text: 'ä.de/?#',
          normalizedText: 'https://xn--4ca.de/?#',
        ),
        const DataDetectorMatch(
          type: DataMatchType.link,
          start: 8,
          end: 14,
          text: 'ä.de/#',
          normalizedText: 'https://xn--4ca.de/#',
        ),
        const DataDetectorMatch(
          type: DataMatchType.link,
          start: 15,
          end: 21,
          text: 'ä.de/?',
          normalizedText: 'https://xn--4ca.de/?',
        ),
        const DataDetectorMatch(
          type: DataMatchType.link,
          start: 22,
          end: 26,
          text: 'ä.de',
          normalizedText: 'https://xn--4ca.de',
        ),
      ]);
    });

    test('keeps explicit scheme URLs with user info over email matches', () {
      expect(
        detector
            .matches('https://user@example.com https://user:pass@example.com')
            .map((entity) => entity.text),
        ['https://user@example.com', 'https://user:pass@example.com'],
      );
    });

    test('rejects local hostnames but accepts URL ports', () {
      expect(
        detector.matches(
          'localhost localhost:3000 http://localhost http://localhost:3000 '
          'dev.local test.internal',
        ),
        isEmpty,
      );
      expect(
        detector
            .matches('example.com:443 example.com:8080/path')
            .map((entity) => entity.text),
        ['example.com:443', 'example.com:8080/path'],
      );
    });

    test('detects explicit scheme IPv4 URLs', () {
      expect(
        detector
            .matches(
              'http://127.0.0.1 http://192.168.0.1:8080 http://8.8.8.8/path',
            )
            .map((entity) => entity.text),
        ['http://127.0.0.1', 'http://192.168.0.1:8080', 'http://8.8.8.8/path'],
      );
    });

    test('trims common wrappers around URLs', () {
      expect(
        detector
            .matches(
              '(example.com) [example.com] {example.com} <example.com> '
              '"example.com" \'example.com\' «example.com» “example.com”',
            )
            .map((entity) => entity.text),
        [
          'example.com',
          'example.com',
          'example.com',
          'example.com',
          'example.com',
          'example.com',
          'example.com',
          'example.com',
        ],
      );
    });

    test('trims bare fragments and keeps path fragments', () {
      expect(
        detector
            .matches(
              'example.com#section example.com/path#comments '
              'example.com/path?x=1#top example.com/path '
              'example.com/path/to/page example.com/path-with-dash '
              'example.com/path_with_underscore example.com/path.with.dots '
              'example.com/~user example.com/@user example.com/a,b;c '
              'example.com/a+b example.com/a=b',
            )
            .map((entity) => entity.text),
        [
          'example.com',
          'example.com/path#comments',
          'example.com/path?x=1#top',
          'example.com/path',
          'example.com/path/to/page',
          'example.com/path-with-dash',
          'example.com/path_with_underscore',
          'example.com/path.with.dots',
          'example.com/~user',
          'example.com/@user',
          'example.com/a,b;c',
          'example.com/a+b',
          'example.com/a=b',
        ],
      );
    });

    test('detects URLs inside simple HTML snippets', () {
      expect(
        detector
            .matches(
              '<a href="https://example.com">link</a> https://example.com<br>',
            )
            .map((entity) => entity.text),
        ['https://example.com', 'https://example.com'],
      );
    });

    test('keeps explicit schemes lower-cased in normalized URL', () {
      final result = detector.matches('Open FTP://example.com/file');

      expect(result.single.text, 'FTP://example.com/file');
      expect(result.single.normalizedText, 'ftp://example.com/file');
    });

    test('detects punycode url', () {
      final result = detector.matches('open ds.xn--vermgensberater-ctb');

      expect(result.single.text, 'ds.xn--vermgensberater-ctb');
      expect(
        result.single.normalizedText,
        'https://ds.xn--vermgensberater-ctb',
      );
    });

    test('detects unicode idn url', () {
      final result = detector.matches('open ds.vermögensberater');

      expect(result.single.text, 'ds.vermögensberater');
      expect(
        result.single.normalizedText,
        'https://ds.xn--vermgensberater-ctb',
      );
    });

    test('keeps original range for unicode idn', () {
      const text = 'open ds.vermögensberater now';
      final result = detector.matches(text).single;

      expect(text.substring(result.start, result.end), 'ds.vermögensberater');
    });

    test('normalizes unicode idn with existing scheme', () {
      final result = detector.matches('open http://ds.vermögensberater/');

      expect(result.single.text, 'http://ds.vermögensberater/');
      expect(
        result.single.normalizedText,
        'http://ds.xn--vermgensberater-ctb/',
      );
    });

    test(
      'supports unicode and punycode idn inputs with and without scheme',
      () {
        final result = detector.matches(
          'ds.vermögensberater ds.xn--vermgensberater-ctb '
          'http://ds.vermögensberater/ http://ds.xn--vermgensberater-ctb/',
        );

        expect(result.map((entity) => entity.normalizedText), [
          'https://ds.xn--vermgensberater-ctb',
          'https://ds.xn--vermgensberater-ctb',
          'http://ds.xn--vermgensberater-ctb/',
          'http://ds.xn--vermgensberater-ctb/',
        ]);
      },
    );

    test('encodes punycode per host label', () {
      const normalizer = IdnaHostNormalizer();

      expect(
        normalizer.normalizeHostToAscii('münchen.de'),
        'xn--mnchen-3ya.de',
      );
      expect(
        normalizer.normalizeHostToAscii('bücher.münchen.de'),
        'xn--bcher-kva.xn--mnchen-3ya.de',
      );
    });

    test('detects ascii email', () {
      final result = detector.matches('write john@example.com now');

      expect(result.single.type, DataMatchType.emailAddress);
      expect(result.single.text, 'john@example.com');
      expect(result.single.normalizedText, 'john@example.com');
    });

    test('detects email with unicode domain', () {
      final result = detector.matches('write anton@münchen.de');

      expect(result.single.type, DataMatchType.emailAddress);
      expect(result.single.text, 'anton@münchen.de');
      expect(result.single.normalizedText, 'anton@xn--mnchen-3ya.de');
    });

    test('detects email with punycode domain', () {
      final result = detector.matches('write anton@xn--mnchen-3ya.de');

      expect(result.single.type, DataMatchType.emailAddress);
      expect(result.single.text, 'anton@xn--mnchen-3ya.de');
      expect(result.single.normalizedText, 'anton@xn--mnchen-3ya.de');
    });

    test('detects email with unicode local part', () {
      final result = detector.matches('write büro@münchen.de');

      expect(result.single.type, DataMatchType.emailAddress);
      expect(result.single.text, 'büro@münchen.de');
      expect(result.single.normalizedText, 'büro@xn--mnchen-3ya.de');
    });

    test('can disable unicode email local parts through options', () {
      final asciiLocalPartDetector = DataDetector(
        options: const DataDetectorOptions(
          emailOptions: EmailDetectorOptions(allowUnicodeLocalPart: false),
        ),
      );

      expect(asciiLocalPartDetector.matches('write büro@münchen.de'), isEmpty);
      expect(
        asciiLocalPartDetector.matches('write anton@münchen.de').single.text,
        'anton@münchen.de',
      );
    });

    test('detects email with chinese local part and domain', () {
      final result = detector.matches('mail 用户@例子.中国');

      expect(result.single.type, DataMatchType.emailAddress);
      expect(result.single.text, '用户@例子.中国');
      expect(result.single.normalizedText, '用户@xn--fsqu00a.xn--fiqs8s');
    });

    test('keeps original email range', () {
      const text = 'hello anton@münchen.de today';
      final result = detector.matches(text).single;

      expect(text.substring(result.start, result.end), 'anton@münchen.de');
    });

    test('email wins over URL inside email domain', () {
      final result = detector.matches('mail john@example.com');

      expect(result, hasLength(1));
      expect(result.single.type, DataMatchType.emailAddress);
      expect(result.single.text, 'john@example.com');
    });

    test('trims trailing punctuation from email ranges', () {
      final result = detector.matches('mail john@example.com.');

      expect(result.single.text, 'john@example.com');
      expect(result.single.normalizedText, 'john@example.com');
    });

    test('rejects invalid email without registrable domain', () {
      expect(detector.matches('mail john@com'), isEmpty);
    });

    test('rejects invalid email local part', () {
      expect(detector.matches('mail john..doe@example.com'), isEmpty);
    });

    test('detects phones by explicit signal', () {
      const text = '+1 999 555-11-22 +19995551122 8 (999) 555-11-22 '
          '(800) 555-1234 999-555-1122 999 555 1122';

      expect(detector.matches(text), [
        const DataDetectorMatch(
          type: DataMatchType.phoneNumber,
          start: 0,
          end: 16,
          text: '+1 999 555-11-22',
          normalizedText: '+19995551122',
        ),
        const DataDetectorMatch(
          type: DataMatchType.phoneNumber,
          start: 17,
          end: 29,
          text: '+19995551122',
          normalizedText: '+19995551122',
        ),
        const DataDetectorMatch(
          type: DataMatchType.phoneNumber,
          start: 30,
          end: 47,
          text: '8 (999) 555-11-22',
          normalizedText: '89995551122',
        ),
        const DataDetectorMatch(
          type: DataMatchType.phoneNumber,
          start: 48,
          end: 62,
          text: '(800) 555-1234',
          normalizedText: '8005551234',
        ),
        const DataDetectorMatch(
          type: DataMatchType.phoneNumber,
          start: 63,
          end: 75,
          text: '999-555-1122',
          normalizedText: '9995551122',
        ),
        const DataDetectorMatch(
          type: DataMatchType.phoneNumber,
          start: 76,
          end: 88,
          text: '999 555 1122',
          normalizedText: '9995551122',
        ),
      ]);
    });

    test('rejects digit runs without explicit phone signal', () {
      expect(detector.matches('ignore 79995551122 and 9995551122'), isEmpty);
    });

    test('rejects dot-separated numbers as phones', () {
      expect(detector.matches('date 11.06.2026'), isEmpty);
    });

    test('detects loose phones by digit count', () async {
      final looseDetector = DataDetector(
        options: const DataDetectorOptions(
          phoneOptions: PhoneDetectorOptions(mode: PhoneDetectionMode.loose),
        ),
      );

      const text = 'loose 9994885764358 9995551 +1 999 555-11-22 '
          '123456 1234567890123456';

      expect(looseDetector.matches(text), [
        const DataDetectorMatch(
          type: DataMatchType.phoneNumber,
          start: 6,
          end: 19,
          text: '9994885764358',
          normalizedText: '9994885764358',
        ),
        const DataDetectorMatch(
          type: DataMatchType.phoneNumber,
          start: 20,
          end: 27,
          text: '9995551',
          normalizedText: '9995551',
        ),
        const DataDetectorMatch(
          type: DataMatchType.phoneNumber,
          start: 28,
          end: 44,
          text: '+1 999 555-11-22',
          normalizedText: '+19995551122',
        ),
      ]);
    });

    test('rejects dot-separated numbers as loose phones', () async {
      final looseDetector = DataDetector(
        options: const DataDetectorOptions(
          phoneOptions: PhoneDetectorOptions(mode: PhoneDetectionMode.loose),
        ),
      );

      expect(looseDetector.matches('date 11.06.2026'), isEmpty);
    });

    test('uses custom loose phone digit limits', () async {
      final looseDetector = DataDetector(
        options: const DataDetectorOptions(
          phoneOptions: PhoneDetectorOptions(
            mode: PhoneDetectionMode.loose,
            minDigits: 8,
            maxDigits: 8,
          ),
        ),
      );

      expect(looseDetector.matches('skip 9995551 keep 99955512'), [
        const DataDetectorMatch(
          type: DataMatchType.phoneNumber,
          start: 18,
          end: 26,
          text: '99955512',
          normalizedText: '99955512',
        ),
      ]);
    });

    test('detects custom entities', () async {
      const mentionType = DataMatchType('mention');
      const hashtagType = DataMatchType('hashtag');
      final customDetector = DataDetector(
        baseRules: const [],
        additionalRules: [
          _MentionDetector(mentionType),
          _HashtagDetector(hashtagType),
        ],
        options: DataDetectorOptions(
          matchWeights: {mentionType: 70, hashtagType: 60},
        ),
      );

      expect(customDetector.matches('Ping @Alice about #Dart'), [
        const DataDetectorMatch(
          type: mentionType,
          start: 5,
          end: 11,
          text: '@Alice',
          normalizedText: '@alice',
        ),
        const DataDetectorMatch(
          type: hashtagType,
          start: 18,
          end: 23,
          text: '#Dart',
          normalizedText: '#dart',
        ),
      ]);
    });

    test('detects adjacent mentions and hashtags', () {
      const mentionType = DataMatchType('mention');
      const hashtagType = DataMatchType('hashtag');
      final customDetector = DataDetector(
        baseRules: const [],
        additionalRules: [
          _MentionDetector(mentionType),
          _HashtagDetector(hashtagType),
        ],
        options: DataDetectorOptions(
          matchWeights: {mentionType: 70, hashtagType: 60},
        ),
      );

      expect(customDetector.matches('@alice#dart#flutter'), [
        const DataDetectorMatch(
          type: mentionType,
          start: 0,
          end: 6,
          text: '@alice',
          normalizedText: '@alice',
        ),
        const DataDetectorMatch(
          type: hashtagType,
          start: 6,
          end: 11,
          text: '#dart',
          normalizedText: '#dart',
        ),
        const DataDetectorMatch(
          type: hashtagType,
          start: 11,
          end: 19,
          text: '#flutter',
          normalizedText: '#flutter',
        ),
      ]);
    });

    test('splits link fragment when hashtag weight is higher than link', () {
      const hashtagType = DataMatchType('hashtag');
      final customDetector = DataDetector(
        additionalRules: const [_HashtagDetector(hashtagType)],
        options: DataDetectorOptions(matchWeights: {hashtagType: 120}),
      );

      expect(customDetector.matches('fluter.dev/#dv'), [
        const DataDetectorMatch(
          type: DataMatchType.link,
          start: 0,
          end: 11,
          text: 'fluter.dev/',
          normalizedText: 'https://fluter.dev/',
        ),
        const DataDetectorMatch(
          type: hashtagType,
          start: 11,
          end: 14,
          text: '#dv',
          normalizedText: '#dv',
        ),
      ]);
    });

    test(
      'keeps whole link fragment when link weight is higher than hashtag',
      () {
        const hashtagType = DataMatchType('hashtag');
        final customDetector = DataDetector(
          additionalRules: const [_HashtagDetector(hashtagType)],
          options: DataDetectorOptions(matchWeights: {hashtagType: 60}),
        );

        expect(customDetector.matches('fluter.dev/#dv'), [
          const DataDetectorMatch(
            type: DataMatchType.link,
            start: 0,
            end: 14,
            text: 'fluter.dev/#dv',
            normalizedText: 'https://fluter.dev/#dv',
          ),
        ]);
      },
    );

    test('uses custom entity weights to resolve overlaps', () async {
      const mentionType = DataMatchType('mention');
      const phraseType = DataMatchType('phrase');
      final customDetector = DataDetector(
        baseRules: const [],
        additionalRules: [
          _PhraseDetector(phraseType),
          _MentionDetector(mentionType),
        ],
        options: DataDetectorOptions(
          matchWeights: {mentionType: 200, phraseType: 10},
        ),
      );

      expect(customDetector.matches('Ping @Alice now'), [
        const DataDetectorMatch(
          type: mentionType,
          start: 5,
          end: 11,
          text: '@Alice',
          normalizedText: '@alice',
        ),
      ]);
    });

    test('uses zero weight for custom entities without explicit weights', () {
      const mentionType = DataMatchType('mention');
      const phraseType = DataMatchType('phrase');
      final customDetector = DataDetector(
        baseRules: const [],
        additionalRules: const [
          _MentionDetector(mentionType),
          _PhraseDetector(phraseType),
        ],
      );

      expect(customDetector.matches('Ping @Alice now'), [
        const DataDetectorMatch(
          type: phraseType,
          start: 0,
          end: 15,
          text: 'Ping @Alice now',
          normalizedText: 'ping @alice now',
        ),
      ]);
    });

    test('keeps default weights for enabled built-in detectors', () {
      const phraseType = DataMatchType('phrase');
      final customDetector = DataDetector(
        additionalRules: const [
          _FixedDetector(
            DataDetectorMatch(
              type: phraseType,
              start: 0,
              end: 16,
              text: 'john@example.com',
              normalizedText: 'custom',
            ),
          ),
        ],
        options: DataDetectorOptions(matchWeights: {phraseType: 10}),
      );

      expect(customDetector.matches('john@example.com'), [
        const DataDetectorMatch(
          type: DataMatchType.emailAddress,
          start: 0,
          end: 16,
          text: 'john@example.com',
          normalizedText: 'john@example.com',
        ),
      ]);
    });

    test('does not apply default weight for disabled built-in types', () {
      const phraseType = DataMatchType('phrase');
      final customDetector = DataDetector(
        baseRules: const [],
        additionalRules: const [
          _FixedDetector(
            DataDetectorMatch(
              type: DataMatchType.link,
              start: 0,
              end: 15,
              text: 'Ping @Alice now',
              normalizedText: 'url-like',
            ),
          ),
          _PhraseDetector(phraseType),
        ],
        options: DataDetectorOptions(matchWeights: {phraseType: 1}),
      );

      expect(customDetector.matches('Ping @Alice now'), [
        const DataDetectorMatch(
          type: phraseType,
          start: 0,
          end: 15,
          text: 'Ping @Alice now',
          normalizedText: 'ping @alice now',
        ),
      ]);
    });

    test('rejects short numeric patterns and embedded phones', () {
      expect(
        detector.matches('date 2026-06-06, ssn 123-45-6789, id x+19995551122'),
        isEmpty,
      );
    });

    group('CalendarEventDetector', () {
      final referenceDate = DateTime(2026, 6, 11);

      late DataDetector calendarDetector;

      setUp(() {
        calendarDetector = DataDetector(
          baseRules: const [],
          additionalRules: [
            CalendarEventDetector(
              options: CalendarEventDetectorOptions(
                referenceDate: referenceDate,
              ),
            ),
          ],
        );
      });

      test('is opt-in and not enabled by default', () {
        expect(detector.matches('Meet tomorrow at 18:00'), isEmpty);
      });

      test('does not detect dash-separated dates by default', () {
        expect(calendarDetector.matches('Meet on 2026-06-11.'), isEmpty);
        expect(calendarDetector.matches('Meet on 11-06-2026.'), isEmpty);
      });

      test('can detect ISO dates when the ISO pattern is explicitly enabled',
          () {
        final isoDetector = DataDetector(
          baseRules: const [],
          additionalRules: [
            CalendarEventDetector.custom(
              options: CalendarEventDetectorOptions(
                referenceDate: referenceDate,
              ),
              patterns: const [IsoDatePattern()],
            ),
          ],
        );

        final match = isoDetector.matches('Meet on 2026-06-11.').single;

        expect(match.type, DataMatchType.calendarEvent);
        expect(match.text, '2026-06-11');
        expect(match.normalizedText, '2026-06-11');
        expect(
          match.calendarEvent,
          CalendarEventValue(
            start: DateTime(2026, 6, 11),
            hasDate: true,
            isAllDay: true,
          ),
        );
      });

      test('detects numeric dates using configured date order', () {
        final dayFirst = calendarDetector.matches('Meet 01/02/2026').single;
        final monthFirst = DataDetector(
          baseRules: const [],
          additionalRules: [
            CalendarEventDetector(
              options: CalendarEventDetectorOptions(
                referenceDate: referenceDate,
                numericDateOrder: NumericDateOrder.monthDayYear,
              ),
            ),
          ],
        ).matches('Meet 01/02/2026').single;

        expect(dayFirst.normalizedText, '2026-02-01');
        expect(monthFirst.normalizedText, '2026-01-02');
      });

      test('detects English month-name dates', () {
        final matches = calendarDetector.matches(
          'Meet June 11, 2026 and 12 Jun 2026.',
        );

        expect(matches.map((match) => match.normalizedText), [
          '2026-06-11',
          '2026-06-12',
        ]);
      });

      test('resolves relative date plus time into one event', () {
        final match = calendarDetector.matches('Meet tomorrow at 18:00').single;

        expect(match.text, 'tomorrow at 18:00');
        expect(match.normalizedText, '2026-06-12T18:00:00');
        expect(
          match.calendarEvent,
          CalendarEventValue(
            start: DateTime(2026, 6, 12, 18),
            hasDate: true,
            hasTime: true,
          ),
        );
      });

      test('detects time-only with reference date', () {
        final match = calendarDetector.matches('Meet at 6:30pm').single;

        expect(match.text, '6:30pm');
        expect(match.normalizedText, '2026-06-11T18:30:00');
        expect(
          match.calendarEvent,
          CalendarEventValue(
            start: DateTime(2026, 6, 11, 18, 30),
            hasTime: true,
          ),
        );
      });

      test('does not treat bare numbers as time', () {
        expect(calendarDetector.matches('Meet at 6'), isEmpty);
      });

      test('detects simple time ranges', () {
        final match = calendarDetector.matches('Slot 18:00 - 19:00').single;

        expect(match.text, '18:00 - 19:00');
        expect(
          match.normalizedText,
          '2026-06-11T18:00:00/2026-06-11T19:00:00',
        );
        expect(
          match.calendarEvent,
          CalendarEventValue(
            start: DateTime(2026, 6, 11, 18),
            end: DateTime(2026, 6, 11, 19),
            duration: const Duration(hours: 1),
            hasTime: true,
          ),
        );
      });

      test('merges dates with following time ranges', () {
        final match =
            calendarDetector.matches('Meet 11.06.2026 18:00-19:00').single;

        expect(match.text, '11.06.2026 18:00-19:00');
        expect(
          match.normalizedText,
          '2026-06-11T18:00:00/2026-06-11T19:00:00',
        );
        expect(match.calendarEvent?.hasDate, isTrue);
        expect(match.calendarEvent?.hasTime, isTrue);
      });

      test('avoids common numeric false positives', () {
        expect(
          calendarDetector.matches(
            'version 1.2.3 Flutter 3.32.1 price 12.50 '
            'id 20260611 number 123456',
          ),
          isEmpty,
        );
      });
    });
  });
}

final class _MentionDetector implements DataDetectorRule {
  const _MentionDetector(this.type);

  final DataMatchType type;

  static final RegExp _pattern = RegExp(
    r'(?<![\w@])@[A-Za-z][A-Za-z0-9_]{1,31}',
  );

  @override
  List<DataDetectorMatch> detect(String text) {
    return [
      for (final match in _pattern.allMatches(text))
        DataDetectorMatch(
          type: type,
          start: match.start,
          end: match.end,
          text: match.group(0)!,
          normalizedText: match.group(0)!.toLowerCase(),
        ),
    ];
  }
}

final class _HashtagDetector implements DataDetectorRule {
  const _HashtagDetector(this.type);

  final DataMatchType type;

  static final RegExp _pattern = RegExp(
    r'(?<![#@])#[A-Za-z][A-Za-z0-9_]{1,63}',
  );

  @override
  List<DataDetectorMatch> detect(String text) {
    return [
      for (final match in _pattern.allMatches(text))
        DataDetectorMatch(
          type: type,
          start: match.start,
          end: match.end,
          text: match.group(0)!,
          normalizedText: match.group(0)!.toLowerCase(),
        ),
    ];
  }
}

final class _PhraseDetector implements DataDetectorRule {
  const _PhraseDetector(this.type);

  final DataMatchType type;

  @override
  List<DataDetectorMatch> detect(String text) {
    const phrase = 'Ping @Alice now';
    final start = text.indexOf(phrase);
    if (start == -1) {
      return const [];
    }
    return [
      DataDetectorMatch(
        type: type,
        start: start,
        end: start + phrase.length,
        text: phrase,
        normalizedText: phrase.toLowerCase(),
      ),
    ];
  }
}

final class _FixedDetector implements DataDetectorRule {
  const _FixedDetector(this.entity);

  final DataDetectorMatch entity;

  @override
  List<DataDetectorMatch> detect(String text) {
    return [entity];
  }
}
