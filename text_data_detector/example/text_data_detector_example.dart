import 'package:text_data_detector/text_data_detector.dart';

const mentionType = DataMatchType('mention');
const hashtagType = DataMatchType('hashtag');

Future<void> main() async {
  final detector = DataDetector(
    additionalRules: const [MentionDetector(), HashtagDetector()],
    options: DataDetectorOptions(
      matchWeights: {mentionType: 70, hashtagType: 60},
    ),
  );

  final entities = detector.matches(
    'Visit example.com, email john@example.com, ping @alice, and tag #dart',
  );

  for (final entity in entities) {
    print(entity);
  }
}

final class MentionDetector implements DataDetectorRule {
  const MentionDetector();

  static final RegExp _pattern = RegExp(
    r'(?<![\w@])@[A-Za-z][A-Za-z0-9_]{1,31}',
  );

  @override
  List<DataDetectorMatch> detect(String text) {
    return [
      for (final match in _pattern.allMatches(text))
        DataDetectorMatch(
          type: mentionType,
          start: match.start,
          end: match.end,
          text: match.group(0)!,
          normalizedText: match.group(0)!.toLowerCase(),
        ),
    ];
  }
}

final class HashtagDetector implements DataDetectorRule {
  const HashtagDetector();

  static final RegExp _pattern = RegExp(
    r'(?<![#@])#[A-Za-z][A-Za-z0-9_]{1,63}',
  );

  @override
  List<DataDetectorMatch> detect(String text) {
    return [
      for (final match in _pattern.allMatches(text))
        DataDetectorMatch(
          type: hashtagType,
          start: match.start,
          end: match.end,
          text: match.group(0)!,
          normalizedText: match.group(0)!.toLowerCase(),
        ),
    ];
  }
}
