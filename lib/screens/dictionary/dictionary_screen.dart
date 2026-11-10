import 'package:flutter/material.dart';

import '../../app/app_controller.dart';
import '../../core/network/api_client.dart';
import '../../core/theme/qtjp_colors.dart';
import '../../core/widgets/api_error_view.dart';
import 'dictionary_repository.dart';
import '../ai/learning_ai_repository.dart';
import '../ai/learning_ai_screen.dart';

class DictionaryScreen extends StatefulWidget {
  const DictionaryScreen({super.key});
  @override
  State<DictionaryScreen> createState() => _DictionaryScreenState();
}

class _DictionaryScreenState extends State<DictionaryScreen> {
  final _input = TextEditingController(text: '学校');
  Future<List<DictionaryEntry>>? _results;
  late DictionaryRepository _repository;
  String _keyword = '学校';

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _repository = DictionaryRepository(AppScope.of(context).api);
    _results ??= _repository.search(_keyword);
  }

  void _search([String? keyword]) {
    FocusScope.of(context).unfocus();
    if (keyword != null) _input.text = keyword;
    setState(() {
      _keyword = _input.text.trim();
      _results = _repository.search(_keyword);
    });
  }

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Từ điển Nhật – Việt')),
    body: SafeArea(
      top: false,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'Tra cứu dữ liệu từ website QTJP',
                      style: TextStyle(color: QTJPColors.muted),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      key: const ValueKey('dictionary-query'),
                      controller: _input,
                      textInputAction: TextInputAction.search,
                      onSubmitted: (_) => _search(),
                      decoration: InputDecoration(
                        labelText: 'Tiếng Nhật, romaji hoặc nghĩa tiếng Việt',
                        border: const OutlineInputBorder(),
                        suffixIcon: IconButton(
                          tooltip: 'Tra cứu',
                          onPressed: _search,
                          icon: const Icon(Icons.search),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextButton.icon(
                      key: const ValueKey('dictionary-ai'),
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute<void>(
                          builder: (_) => LearningAiScreen(
                            tool: LearningAiTool.dictionary,
                            initialText: _input.text.trim(),
                          ),
                        ),
                      ),
                      icon: const Icon(Icons.auto_awesome),
                      label: const Text('Tra từ / giải thích với AI'),
                    ),
                    Wrap(
                      spacing: 8,
                      children: [
                        for (final word in ['学校', '猫', '勉強'])
                          ActionChip(
                            label: Text(word),
                            onPressed: () => _search(word),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              Expanded(
                child: FutureBuilder<List<DictionaryEntry>>(
                  future: _results,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState != ConnectionState.done) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (snapshot.hasError) {
                      return SingleChildScrollView(
                        padding: const EdgeInsets.all(20),
                        child: ApiErrorView(
                          error: snapshot.error!,
                          onRetry: _search,
                        ),
                      );
                    }
                    final results = snapshot.data ?? [];
                    if (results.isEmpty) {
                      return Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Text(
                            _keyword.isEmpty
                                ? 'Nhập từ cần tra cứu.'
                                : 'Không tìm thấy “$_keyword”. Hãy thử cách viết khác.',
                            textAlign: TextAlign.center,
                          ),
                        ),
                      );
                    }
                    return ListView.builder(
                      key: ValueKey(_keyword),
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                      itemCount: results.length + 1,
                      itemBuilder: (context, index) {
                        if (index == 0) {
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: Text(
                              '${results.length} kết quả · $_keyword',
                              style: const TextStyle(color: QTJPColors.blue),
                            ),
                          );
                        }
                        final word = results[index - 1];
                        return Card(
                          child: ExpansionTile(
                            key: ValueKey('dictionary-result-${index - 1}'),
                            title: Text(
                              word.word,
                              style: const TextStyle(
                                color: QTJPColors.navy,
                                fontSize: 24,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  [
                                    word.reading,
                                    word.romaji,
                                    word.level,
                                  ].where((s) => s.isNotEmpty).join(' · '),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  word.meaning,
                                  style: const TextStyle(height: 1.6),
                                ),
                              ],
                            ),
                            expandedCrossAxisAlignment:
                                CrossAxisAlignment.stretch,
                            childrenPadding: const EdgeInsets.all(16),
                            children: [
                              if (word.hanViet.isNotEmpty)
                                Text('Hán Việt: ${word.hanViet}'),
                              if (word.partOfSpeech.isNotEmpty)
                                Text('Từ loại: ${word.partOfSpeech}'),
                              for (final example in word.examples)
                                Padding(
                                  padding: const EdgeInsets.only(top: 16),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        jsonText(example, 'japanese'),
                                        style: const TextStyle(
                                          fontSize: 18,
                                          height: 1.6,
                                        ),
                                      ),
                                      Text(
                                        jsonText(example, 'vietnamese'),
                                        style: const TextStyle(
                                          color: QTJPColors.muted,
                                          height: 1.6,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              for (final relation in word.relations)
                                Padding(
                                  padding: const EdgeInsets.only(top: 12),
                                  child: Text(
                                    '${jsonText(relation, 'relationType')}: ${jsonText(relation, 'relatedWord')} (${jsonText(relation, 'relatedReading')}) — ${jsonText(relation, 'relatedMeaning')}',
                                  ),
                                ),
                            ],
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
