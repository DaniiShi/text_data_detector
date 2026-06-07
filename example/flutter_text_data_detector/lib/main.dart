import 'package:flutter/material.dart';
import 'package:text_data_detector/text_data_detector.dart';
import 'package:url_launcher/url_launcher.dart';

const mentionType = DataMatchType('mention');
const hashtagType = DataMatchType('hashtag');

void main() {
  runApp(const DataDetectorExampleApp());
}

final class DataDetectorExampleApp extends StatelessWidget {
  const DataDetectorExampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Text Data Detector',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF1F7A5C),
          brightness: Brightness.light,
        ),
        scaffoldBackgroundColor: const Color(0xFFF6F7F4),
        useMaterial3: true,
      ),
      home: const DetectorScreen(),
    );
  }
}

final class DetectorScreen extends StatefulWidget {
  const DetectorScreen({super.key});

  @override
  State<DetectorScreen> createState() => _DetectorScreenState();
}

final class _DetectorScreenState extends State<DetectorScreen> {
  final _controller = TextEditingController(
    text: 'Visit example.com or https://flutter.dev',
  );
  final _detector = DataDetector(
    additionalRules: const [MentionDetector(), HashtagDetector()],
    options: DataDetectorOptions(
      linkOptions: const LinkDetectorOptions(allowCustomSchemes: true),
      phoneOptions: const PhoneDetectorOptions(mode: PhoneDetectionMode.loose),
      matchWeights: {mentionType: 200, hashtagType: 90},
    ),
  );
  final _messages = <ClassifiedMessage>[];

  static const _examples = <String>[
    'Visit example.com or https://flutter.dev',
    'Email john@example.com or 用户@例子.中国',
    'International address: 例子.中国',
    'Docs are on dart.dev and api.flutter.dev.',
    'Try example.co.uk, example.github.io, and github.io',
    'Dotted hosts: gov.uk, github.io, service.gov.uk, example.github.io',
    'Release notes: https://example.com:8443/releases?q=stable',
    'Deep links: tg://resolve?domain=test and myapp://profile/123',
    'Ping @alice about #dart and #flutter',
  ];

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final text = _controller.text.trim();
    if (text.isEmpty) {
      return;
    }

    final entities = _detector.matches(text);
    setState(() {
      _messages.insert(0, ClassifiedMessage(text: text, entities: entities));
      _controller.clear();
    });
  }

  void _useExample(String text) {
    _controller.text = text;
    _controller.selection = TextSelection.collapsed(offset: text.length);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Text Data Detector')),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final wide = constraints.maxWidth >= 840;
          final composer = MessageComposer(
            controller: _controller,

            onSubmit: _submit,
          );
          final examples = ExampleRail(
            examples: _examples,
            onSelected: _useExample,
          );
          final messages = MessageList(messages: _messages);

          if (wide) {
            return Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: ConversationPane(
                    composer: composer,
                    messages: messages,
                  ),
                ),
                SizedBox(width: 340, child: examples),
              ],
            );
          }

          return Column(
            children: [
              Expanded(
                child: ConversationPane(composer: composer, messages: messages),
              ),
              SizedBox(height: 260, child: examples),
            ],
          );
        },
      ),
    );
  }
}

final class ConversationPane extends StatelessWidget {
  const ConversationPane({
    required this.composer,
    required this.messages,
    super.key,
  });

  final Widget composer;
  final Widget messages;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: Column(
          children: [
            Expanded(child: messages),
            const SizedBox(height: 12),
            composer,
          ],
        ),
      ),
    );
  }
}

final class MessageComposer extends StatelessWidget {
  const MessageComposer({
    required this.controller,
    required this.onSubmit,
    super.key,
  });

  final TextEditingController controller;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: TextField(
            controller: controller,

            minLines: 1,
            maxLines: 4,
            textInputAction: TextInputAction.send,
            onSubmitted: (_) => onSubmit(),
            decoration: InputDecoration(
              filled: true,
              fillColor: Colors.white,
              hintText: 'Message',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        FilledButton.icon(
          onPressed: onSubmit,
          icon: const Icon(Icons.send_rounded),
          label: const Text('Submit'),
          style: FilledButton.styleFrom(
            minimumSize: const Size(112, 56),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
      ],
    );
  }
}

final class MessageList extends StatelessWidget {
  const MessageList({required this.messages, super.key});

  final List<ClassifiedMessage> messages;

  @override
  Widget build(BuildContext context) {
    if (messages.isEmpty) {
      return Align(
        alignment: Alignment.bottomRight,
        child: MessageBubble(
          message: ClassifiedMessage(
            text: 'Visit example.com or https://flutter.dev',
            entities: const [
              DataDetectorMatch(
                type: DataMatchType.link,
                start: 6,
                end: 17,
                text: 'example.com',
                normalizedText: 'https://example.com',
              ),
              DataDetectorMatch(
                type: DataMatchType.link,
                start: 21,
                end: 40,
                text: 'https://flutter.dev',
                normalizedText: 'https://flutter.dev',
              ),
            ],
          ),
        ),
      );
    }

    return ListView.separated(
      reverse: true,
      itemCount: messages.length,
      separatorBuilder: (context, index) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        return Align(
          alignment: Alignment.centerRight,
          child: MessageBubble(message: messages[index]),
        );
      },
    );
  }
}

final class MessageBubble extends StatelessWidget {
  const MessageBubble({required this.message, super.key});

  final ClassifiedMessage message;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 560),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: colorScheme.primaryContainer,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(8),
            topRight: Radius.circular(8),
            bottomLeft: Radius.circular(8),
            bottomRight: Radius.circular(2),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Text.rich(
            TextSpan(children: _spansForMessage(context, message)),
            style: TextStyle(
              color: colorScheme.onPrimaryContainer,
              fontSize: 16,
              height: 1.35,
            ),
          ),
        ),
      ),
    );
  }

  List<InlineSpan> _spansForMessage(
    BuildContext context,
    ClassifiedMessage message,
  ) {
    final spans = <InlineSpan>[];
    final colorScheme = Theme.of(context).colorScheme;
    final linkStyle = TextStyle(
      color: colorScheme.primary,
      decoration: TextDecoration.underline,
      decorationColor: colorScheme.primary,
      fontWeight: FontWeight.w700,
    );
    final tagStyle = TextStyle(
      color: colorScheme.primary,
      fontWeight: FontWeight.w700,
    );
    var cursor = 0;

    for (final entity in message.entities) {
      if (entity.start > cursor) {
        spans.add(TextSpan(text: message.text.substring(cursor, entity.start)));
      }
      spans.add(
        WidgetSpan(
          alignment: PlaceholderAlignment.baseline,
          baseline: TextBaseline.alphabetic,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => _openEntity(context, entity),
            child: Text(
              message.text.substring(entity.start, entity.end),
              style: entity.type == hashtagType ? tagStyle : linkStyle,
            ),
          ),
        ),
      );
      cursor = entity.end;
    }

    if (cursor < message.text.length) {
      spans.add(TextSpan(text: message.text.substring(cursor)));
    }

    return spans;
  }

  Future<void> _openEntity(
    BuildContext context,
    DataDetectorMatch entity,
  ) async {
    final uri = _uriForEntity(entity);
    if (uri == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('${entity.type}: ${entity.text}')));
      return;
    }

    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (opened || !context.mounted) {
      return;
    }

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('Could not open ${entity.text}')));
  }

  Uri? _uriForEntity(DataDetectorMatch entity) {
    if (entity.type == DataMatchType.link) {
      return Uri.parse(entity.normalizedText);
    }
    if (entity.type == DataMatchType.emailAddress) {
      return Uri(scheme: 'mailto', path: entity.normalizedText);
    }
    if (entity.type == DataMatchType.phoneNumber) {
      return Uri(scheme: 'tel', path: entity.normalizedText);
    }
    return null;
  }
}

final class ExampleRail extends StatelessWidget {
  const ExampleRail({
    required this.examples,
    required this.onSelected,
    super.key,
  });

  final List<String> examples;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: DecoratedBox(
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(left: BorderSide(color: Color(0xFFE0E4DD))),
        ),
        child: ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: examples.length,
          separatorBuilder: (context, index) => const SizedBox(height: 10),
          itemBuilder: (context, index) {
            final text = examples[index];
            return InkWell(
              onTap: () => onSelected(text),
              borderRadius: BorderRadius.circular(8),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: const Color(0xFFF6F7F4),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFD9DED6)),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.chat_bubble_outline_rounded,
                        size: 20,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          text,
                          style: const TextStyle(fontSize: 14, height: 1.3),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

final class ClassifiedMessage {
  const ClassifiedMessage({required this.text, required this.entities});

  final String text;
  final List<DataDetectorMatch> entities;
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
