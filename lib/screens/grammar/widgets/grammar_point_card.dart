import 'package:flutter/material.dart';

import '../../../core/network/api_client.dart';
import '../../../core/theme/qtjp_colors.dart';
import '../../../core/widgets/japanese_sentence.dart';

class GrammarPointCard extends StatelessWidget {
  const GrammarPointCard({
    required this.point,
    required this.number,
    required this.onSpeak,
    super.key,
  });
  final Map<String, dynamic> point;
  final int number;
  final Future<void> Function(String) onSpeak;

  @override
  Widget build(BuildContext context) {
    final cases = jsonObjects(point['usageCases'] ?? []);
    final structure = (point['structure'] as List? ?? [])
        .whereType<String>()
        .where((s) => s.trim().isNotEmpty)
        .toList();
    final notes = (point['notes'] as List? ?? []).whereType<String>().toList();
    return Card(
      margin: const EdgeInsets.only(top: 20),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(22),
        side: BorderSide(color: context.qtjp.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'MẪU $number',
              style: TextStyle(
                color: context.qtjp.blue,
                fontWeight: FontWeight.w800,
                fontSize: 11,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 10),
            SelectableText(
              jsonText(point, 'pattern'),
              style: TextStyle(
                color: context.qtjp.heading,
                fontSize: 27,
                fontWeight: FontWeight.w900,
                height: 1.5,
              ),
            ),
            if (jsonText(point, 'meaning').isNotEmpty) ...[
              const SizedBox(height: 12),
              SelectableText(
                jsonText(point, 'meaning'),
                style: TextStyle(
                  color: context.qtjp.blue,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  height: 1.6,
                ),
              ),
            ],
            const Divider(height: 32),
            if (structure.isNotEmpty) ...[
              _heading(context, 'Cấu trúc', Icons.account_tree_outlined),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: context.qtjp.soft,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (final line in structure)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: SelectableText(
                          line,
                          style: TextStyle(
                            color: context.qtjp.heading,
                            fontSize: 16,
                            height: 1.7,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
            if (jsonText(point, 'usage').isNotEmpty) ...[
              _heading(context, 'Cách dùng', Icons.menu_book_outlined),
              _paragraph(jsonText(point, 'usage')),
            ],
            for (final (index, usage) in cases.indexed) ...[
              _heading(
                context,
                jsonText(usage, 'title').isEmpty
                    ? 'Cách dùng ${index + 1}'
                    : jsonText(usage, 'title'),
                Icons.bookmark_outline_rounded,
              ),
              if (jsonText(usage, 'usage').isNotEmpty)
                _paragraph(jsonText(usage, 'usage')),
              ..._examples(context, usage['examples']),
              ..._notes(
                context,
                (usage['notes'] as List? ?? []).whereType<String>().toList(),
              ),
            ],
            if (jsonObjects(point['examples'] ?? []).isNotEmpty) ...[
              _heading(context, 'Ví dụ', Icons.chat_bubble_outline_rounded),
              ..._examples(context, point['examples']),
            ],
            ..._notes(context, notes),
            if ((point['relatedPatterns'] as List? ?? []).isNotEmpty) ...[
              _heading(context, 'Mẫu liên quan', Icons.link_rounded),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final pattern in point['relatedPatterns'] as List)
                    Chip(
                      label: Text(
                        pattern.toString(),
                        style: TextStyle(color: context.qtjp.heading),
                      ),
                      backgroundColor: context.qtjp.soft,
                      side: BorderSide.none,
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _heading(BuildContext context, String title, IconData icon) => Padding(
    padding: const EdgeInsets.only(top: 18, bottom: 12),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: context.qtjp.blue, size: 19),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            title,
            style: TextStyle(
              color: context.qtjp.heading,
              fontWeight: FontWeight.w800,
              fontSize: 16,
              height: 1.4,
            ),
          ),
        ),
      ],
    ),
  );

  Widget _paragraph(String text) =>
      SelectableText(text, style: const TextStyle(fontSize: 16, height: 1.8));

  List<Widget> _examples(BuildContext context, Object? data) => [
    for (final example in jsonObjects(data ?? []))
      Container(
        margin: const EdgeInsets.only(top: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          border: Border(left: BorderSide(color: context.qtjp.blue, width: 3)),
          color: context.qtjp.soft,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: JapaneseSentence(
                    text: jsonObjects(example['segments'] ?? [])
                        .map((s) => jsonText(s, 'text'))
                        .join(),
                    segments: _normalize(
                      jsonObjects(example['segments'] ?? []),
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Nghe ví dụ',
                  onPressed: () => onSpeak(
                    jsonObjects(example['segments'] ?? [])
                        .map((s) => jsonText(s, 'text'))
                        .join(),
                  ),
                  icon: const Icon(Icons.volume_up_outlined, size: 21),
                ),
              ],
            ),
            if (jsonText(example, 'translation').isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(
                jsonText(example, 'translation'),
                style: TextStyle(
                  color: context.qtjp.muted,
                  height: 1.7,
                  fontSize: 15,
                ),
              ),
            ],
          ],
        ),
      ),
  ];

  List<Widget> _notes(BuildContext context, List<String> notes) => notes.isEmpty
      ? []
      : [
          Container(
            margin: const EdgeInsets.only(top: 18),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: context.qtjp.pink,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Lưu ý',
                  style: TextStyle(
                    color: context.qtjp.heading,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                for (final note in notes)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: _paragraph('• $note'),
                  ),
              ],
            ),
          ),
        ];

  // Match the website's treatment of older mixed kana/kanji segments.
  List<Map<String, dynamic>> _normalize(List<Map<String, dynamic>> segments) =>
      [for (final segment in segments) ..._split(segment)];
  List<Map<String, dynamic>> _split(Map<String, dynamic> segment) {
    final text = jsonText(segment, 'text');
    final reading = jsonText(segment, 'reading');
    final matches = RegExp(r'[\u3400-\u4dbf\u4e00-\u9fff々]+')
        .allMatches(text)
        .toList();
    if (reading.isEmpty || matches.length != 1) return [segment];
    final match = matches.single;
    return [
      if (match.start > 0)
        {'text': text.substring(0, match.start), 'reading': ''},
      {'text': match.group(0)!, 'reading': reading},
      if (match.end < text.length)
        {'text': text.substring(match.end), 'reading': ''},
    ];
  }
}
