import 'package:flutter/material.dart';

import '../../../core/theme/qtjp_colors.dart';
import '../../../core/widgets/japanese_sentence.dart';
import '../models/flashcard_deck.dart';

class FlashcardVocabularyList extends StatefulWidget {
  const FlashcardVocabularyList({
    required this.deck,
    required this.onSpeak,
    this.results = const {},
    this.onPractice,
    this.onSelect,
    super.key,
  });
  final FlashcardDeck deck;
  final Future<void> Function(String) onSpeak;
  final Map<int, bool> results;
  final VoidCallback? onPractice;
  final ValueChanged<FlashcardWord>? onSelect;

  @override
  State<FlashcardVocabularyList> createState() =>
      _FlashcardVocabularyListState();
}

class _FlashcardVocabularyListState extends State<FlashcardVocabularyList> {
  String _query = '';
  String _filter = 'ALL';
  FlashcardDeck get deck => widget.deck;
  Future<void> Function(String) get onSpeak => widget.onSpeak;

  @override
  Widget build(BuildContext context) {
    final query = _query.trim().toLowerCase();
    final words = deck.words
        .where(
          (w) =>
              [
                w.word,
                w.hiragana,
                w.romaji,
                w.meaning,
                w.hanViet,
              ].any((text) => text.toLowerCase().contains(query)) &&
              switch (_filter) {
                'KNOWN' => widget.results[w.id] == true,
                'FORGOT' => widget.results[w.id] == false,
                'NEW' => !widget.results.containsKey(w.id),
                _ => true,
              },
        )
        .toList();
    return ListView.builder(
      key: const ValueKey('study-vocabulary-list'),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
      itemCount: words.length + 1,
      itemBuilder: (context, index) {
        if (index == 0) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  '${deck.level} · ${deck.words.length} từ vựng',
                  style: TextStyle(
                    color: context.qtjp.heading,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 14),
                if (widget.onPractice != null)
                  OutlinedButton.icon(
                    onPressed: widget.onPractice,
                    icon: const Icon(Icons.school_outlined),
                    label: const Text('Luyện tập từ vựng'),
                  ),
                const SizedBox(height: 8),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      for (final entry in {
                        'ALL': 'Tất cả',
                        'KNOWN': 'Đã nhớ',
                        'FORGOT': 'Chưa nhớ',
                        'NEW': 'Chưa đánh giá',
                      }.entries)
                        Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ChoiceChip(
                            key: ValueKey('vocabulary-filter-${entry.key}'),
                            label: Text(entry.value),
                            selected: _filter == entry.key,
                            onSelected: (_) =>
                                setState(() => _filter = entry.key),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  key: const ValueKey('vocabulary-search'),
                  decoration: const InputDecoration(
                    hintText: 'Tìm từ, cách đọc hoặc nghĩa',
                    prefixIcon: Icon(Icons.search),
                  ),
                  onChanged: (value) => setState(() => _query = value),
                ),
                if (words.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(24),
                    child: Text(
                      'Không tìm thấy từ phù hợp.',
                      textAlign: TextAlign.center,
                    ),
                  ),
              ],
            ),
          );
        }
        final word = words[index - 1];
        return Card(
          color: context.qtjp.surface,
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
            side: BorderSide(color: context.qtjp.border),
          ),
          key: ObjectKey(word),
          margin: const EdgeInsets.only(bottom: 12),
          child: ExpansionTile(
            tilePadding: const EdgeInsets.fromLTRB(14, 4, 8, 4),
            childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
            expandedCrossAxisAlignment: CrossAxisAlignment.stretch,
            title: Row(
              children: [
                Expanded(
                  child: Text(
                    word.word,
                    style: TextStyle(
                      color: context.qtjp.heading,
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Phát âm tiếng Nhật',
                  onPressed: () => onSpeak(
                    word.hiragana.isEmpty ? word.word : word.hiragana,
                  ),
                  icon: const Icon(Icons.volume_up_outlined),
                ),
              ],
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  [
                    word.hiragana,
                    word.romaji,
                  ].where((s) => s.isNotEmpty).join(' · '),
                  style: TextStyle(color: context.qtjp.blue, fontSize: 13),
                ),
                const SizedBox(height: 6),
                Text(
                  word.meaning,
                  style: const TextStyle(fontSize: 14, height: 1.5),
                ),
              ],
            ),
            children: [
              if (widget.results.containsKey(word.id))
                Text(
                  widget.results[word.id] == true ? '✓ Đã nhớ' : '↺ Chưa nhớ',
                  style: TextStyle(
                    color: widget.results[word.id] == true
                        ? const Color(0xFF21845B)
                        : QTJPColors.red,
                    fontWeight: FontWeight.w800,
                    height: 2,
                  ),
                ),
              if (widget.onSelect != null)
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: () => widget.onSelect!(word),
                    icon: const Icon(Icons.style_outlined),
                    label: const Text('Học từ này'),
                  ),
                ),
              if (word.hanViet.isNotEmpty) Text('Hán Việt: ${word.hanViet}'),
              if (word.partOfSpeech.isNotEmpty)
                Text(
                  word.partOfSpeech,
                  style: TextStyle(color: context.qtjp.muted),
                ),
              if (word.example.isNotEmpty) ...[
                const Divider(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: JapaneseSentence(
                        text: word.example,
                        segments: word.exampleFurigana,
                        fontSize: 15,
                      ),
                    ),
                    IconButton(
                      tooltip: 'Phát âm câu ví dụ',
                      onPressed: () => onSpeak(word.example),
                      icon: const Icon(Icons.volume_up_outlined, size: 22),
                    ),
                  ],
                ),
                if (word.exampleVi.isNotEmpty)
                  Text(
                    word.exampleVi,
                    style: TextStyle(
                      color: context.qtjp.muted,
                      fontSize: 13,
                      height: 1.6,
                    ),
                  ),
              ],
            ],
          ),
        );
      },
    );
  }
}
