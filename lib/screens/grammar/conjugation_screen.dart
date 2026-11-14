import 'package:flutter/material.dart';

import '../../core/widgets/kyuto_scaffold.dart';

import '../../core/theme/qtjp_colors.dart';
import '../../core/widgets/qtjp_reference_table.dart';
import 'verb_conjugation.dart';
import 'verb_form_tables.dart';

class ConjugationScreen extends StatefulWidget {
  const ConjugationScreen({super.key});
  @override
  State<ConjugationScreen> createState() => _ConjugationScreenState();
}

class _ConjugationScreenState extends State<ConjugationScreen> {
  final _word = TextEditingController(text: '書く');
  String _group = 'godan';
  List<String> _forms = conjugateVerb('書く', 'godan');
  String? _error;
  final _anchors = List.generate(12, (_) => GlobalKey());
  final _practice = GlobalKey();
  static const _groups = {
    'godan': 'Nhóm I · 五段',
    'ichidan': 'Nhóm II · 一段',
    'suru': 'Nhóm III · する',
    'kuru': 'Nhóm III · 来る',
  };
  @override
  void dispose() {
    _word.dispose();
    super.dispose();
  }

  void _run() {
    FocusScope.of(context).unfocus();
    setState(() {
      try {
        _forms = conjugateVerb(_word.text, _group);
        _error = null;
      } on FormatException catch (error) {
        _error = error.message;
        _forms = [];
      }
    });
  }

  void _scroll(GlobalKey key) {
    final target = key.currentContext;
    if (target != null) {
      Scrollable.ensureVisible(
        target,
        duration: const Duration(milliseconds: 220),
        alignment: .02,
      );
    }
  }

  @override
  Widget build(BuildContext context) => KyutoScaffold(
    appBar: AppBar(title: const Text('Bảng chia thể')),
    body: SafeArea(
      top: false,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  padding: const EdgeInsets.all(22),
                  decoration: BoxDecoration(
                    color: QTJPColors.navy,
                    borderRadius: BorderRadius.circular(22),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '活用表 · NGỮ PHÁP',
                        style: TextStyle(
                          color: Color(0xFFABCDED),
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        '12 thể động từ tiếng Nhật',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 25,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        'Đối chiếu quy tắc, ví dụ theo từng nhóm và thử chia động từ.',
                        style: TextStyle(color: Color(0xFFD9E5F5), height: 1.6),
                      ),
                      const SizedBox(height: 12),
                      FilledButton.tonal(
                        onPressed: () => _scroll(_practice),
                        child: const Text('Thử chia động từ ↓'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    for (var i = 0; i < 12; i++)
                      ActionChip(
                        label: Text('${i + 1}. ${verbFormTables[i]['label']}'),
                        onPressed: () => _scroll(_anchors[i]),
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                for (var i = 0; i < 12; i++)
                  Card(
                    key: _anchors[i],
                    color: context.qtjp.surface,
                    margin: const EdgeInsets.only(bottom: 16),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            '${i + 1}. ${verbFormTables[i]['label']}',
                            style: TextStyle(
                              color: context.qtjp.heading,
                              fontSize: 20,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          Text(
                            '${verbFormTables[i]['japanese']}',
                            style: TextStyle(
                              color: context.qtjp.blue,
                              height: 1.7,
                            ),
                          ),
                          if (verbFormTables[i]['note'] != null)
                            Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: Text(
                                '${verbFormTables[i]['note']}',
                                style: TextStyle(
                                  color: context.qtjp.muted,
                                  height: 1.5,
                                ),
                              ),
                            ),
                          const SizedBox(height: 16),
                          QTJPReferenceTable(
                            headers: const ['Nhóm', 'Quy tắc', 'Ví dụ'],
                            rows: [
                              for (final group
                                  in verbFormTables[i]['groups'] as List)
                                [
                                  '${group['name']}',
                                  _lines(group['rule']),
                                  _lines(group['example']),
                                ],
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                Card(
                  key: _practice,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          'Thử chia động từ',
                          style: TextStyle(
                            color: context.qtjp.heading,
                            fontSize: 23,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Chọn đúng nhóm của động từ. Công cụ áp dụng quy tắc theo nhóm bạn chọn.',
                          style: TextStyle(height: 1.6),
                        ),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 8,
                          children: [
                            for (final entry in _groups.entries)
                              ChoiceChip(
                                label: Text(entry.value),
                                selected: entry.key == _group,
                                onSelected: (_) {
                                  setState(() {
                                    _group = entry.key;
                                    _word.text = {
                                      'godan': '書く',
                                      'ichidan': '食べる',
                                      'suru': '勉強する',
                                      'kuru': '来る',
                                    }[_group]!;
                                  });
                                  _run();
                                },
                              ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          key: const ValueKey('conjugation-input'),
                          controller: _word,
                          decoration: const InputDecoration(
                            labelText: 'Động từ dạng từ điển',
                          ),
                          onSubmitted: (_) => _run(),
                        ),
                        const SizedBox(height: 12),
                        FilledButton.icon(
                          key: const ValueKey('conjugation-run'),
                          onPressed: _run,
                          icon: const Icon(Icons.auto_fix_high_rounded),
                          label: const Text('Chia 12 thể'),
                        ),
                        if (_error != null)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            child: Text(
                              _error!,
                              style: const TextStyle(color: QTJPColors.red),
                            ),
                          ),
                        if (_forms.isNotEmpty) ...[
                          const SizedBox(height: 16),
                          QTJPReferenceTable(
                            minWidth: 440,
                            headers: const ['Thể động từ', 'Kết quả'],
                            rows: [
                              for (var i = 0; i < 12; i++)
                                [
                                  '${i + 1}. ${verbFormTables[i]['label']}',
                                  _forms[i],
                                ],
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
  String _lines(dynamic value) => value is List ? value.join('\n') : '$value';
}
