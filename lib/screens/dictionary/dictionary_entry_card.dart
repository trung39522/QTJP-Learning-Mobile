import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/network/api_client.dart';
import '../../core/theme/qtjp_colors.dart';
import 'dictionary_repository.dart';

class DictionaryEntryCard extends StatelessWidget {
  const DictionaryEntryCard({
    required this.entry,
    required this.onSpeak,
    required this.onSearch,
    this.initiallyExpanded = false,
    super.key,
  });
  final DictionaryEntry entry;
  final Future<void> Function(String) onSpeak;
  final ValueChanged<String> onSearch;
  final bool initiallyExpanded;

  @override
  Widget build(BuildContext context) {
    final word = entry;
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: BorderSide(color: context.qtjp.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 8,
              children: [
                Text(
                  word.word,
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    color: context.qtjp.blue,
                  ),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      tooltip: 'Sao chép từ vựng',
                      icon: const Icon(Icons.copy_outlined, size: 20),
                      onPressed: () async {
                        await Clipboard.setData(ClipboardData(text: word.word));
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Đã sao chép từ vựng.'),
                            ),
                          );
                        }
                      },
                    ),
                    IconButton(
                      tooltip: 'Phát âm tiếng Nhật',
                      icon: const Icon(Icons.volume_up_outlined),
                      onPressed: () => onSpeak(
                        word.reading.isEmpty ? word.word : word.reading,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            if (word.hanViet.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                '「${word.hanViet}」',
                style: TextStyle(
                  color: context.qtjp.muted,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
            if (word.reading.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(
                word.reading,
                style: const TextStyle(fontSize: 16, height: 1.5),
              ),
            ],
            if (word.romaji.isNotEmpty)
              Text(
                word.romaji,
                style: TextStyle(color: context.qtjp.muted, fontSize: 12),
              ),
            const Divider(height: 28),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (word.level.isNotEmpty) _tag(context, word.level),
                if (word.partOfSpeech.isNotEmpty)
                  _tag(context, word.partOfSpeech),
              ],
            ),
            const SizedBox(height: 12),
            SelectableText(
              word.meaning,
              style: TextStyle(
                color: context.qtjp.blue,
                fontSize: 16,
                fontWeight: FontWeight.w700,
                height: 1.5,
              ),
            ),
            if (word.examples.isNotEmpty || word.relations.isNotEmpty) ...[
              const SizedBox(height: 12),
              for (final example in word.examples)
                Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  padding: const EdgeInsets.only(left: 12),
                  decoration: BoxDecoration(
                    border: Border(
                      left: BorderSide(color: context.qtjp.border, width: 2),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: SelectableText(
                              jsonText(example, 'japanese'),
                              style: const TextStyle(fontSize: 15, height: 1.6),
                            ),
                          ),
                          IconButton(
                            tooltip: 'Phát âm câu ví dụ',
                            icon: const Icon(
                              Icons.volume_up_outlined,
                              size: 22,
                            ),
                            onPressed: () =>
                                onSpeak(jsonText(example, 'japanese')),
                          ),
                        ],
                      ),
                      Text(
                        jsonText(example, 'vietnamese'),
                        style: TextStyle(
                          color: context.qtjp.muted,
                          fontSize: 13,
                          height: 1.6,
                        ),
                      ),
                    ],
                  ),
                ),
              if (word.relations.isNotEmpty)
                Text(
                  'Từ liên quan',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: context.qtjp.heading,
                  ),
                ),
              for (final relation in word.relations)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    '${jsonText(relation, 'relatedWord')} ${jsonText(relation, 'relatedReading')}',
                  ),
                  subtitle: Text(
                    [
                      jsonText(relation, 'relationType'),
                      jsonText(relation, 'relatedMeaning'),
                    ].where((s) => s.isNotEmpty).join(' · '),
                  ),
                  trailing: const Icon(Icons.north_west, size: 18),
                  onTap: jsonText(relation, 'relatedWord').isEmpty
                      ? null
                      : () => onSearch(jsonText(relation, 'relatedWord')),
                ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _tag(BuildContext context, String text) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
    decoration: BoxDecoration(
      color: context.qtjp.soft,
      borderRadius: BorderRadius.circular(8),
    ),
    child: Text(
      text,
      style: TextStyle(
        color: context.qtjp.heading,
        fontSize: 12,
        fontWeight: FontWeight.w700,
      ),
    ),
  );
}
