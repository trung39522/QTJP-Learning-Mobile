import 'package:flutter/material.dart';

import '../../../core/network/api_client.dart';
import '../../../core/theme/qtjp_colors.dart';
import 'exam_skill_chart.dart';

const examSkillLabels = {
  'KANJI': 'Hán tự',
  'VOCAB': 'Từ vựng',
  'GRAMMAR': 'Ngữ pháp',
  'READING': 'Đọc hiểu',
  'LISTENING': 'Nghe hiểu',
};
double _number(dynamic value) =>
    (value is num ? value.toDouble() : double.tryParse('$value')) ?? 0;
double _percent(dynamic value) => _number(value).clamp(0, 100);

class ExamResultDashboard extends StatefulWidget {
  const ExamResultDashboard({
    required this.result,
    required this.answerBuilder,
    super.key,
  });
  final Map<String, dynamic> result;
  final Widget Function(Map<String, dynamic>) answerBuilder;
  @override
  State<ExamResultDashboard> createState() => _ExamResultDashboardState();
}

class _ExamResultDashboardState extends State<ExamResultDashboard> {
  String _filter = 'ALL';
  int _visible = 15;
  final _review = GlobalKey();
  @override
  void didUpdateWidget(covariant ExamResultDashboard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.result['attemptId'] != widget.result['attemptId']) {
      _filter = 'ALL';
      _visible = 15;
    }
  }

  void _choose(String value) => setState(() {
    _filter = value;
    _visible = 15;
  });
  @override
  Widget build(BuildContext context) {
    final result = widget.result;
    final answers = jsonObjects(result['answers'] ?? []);
    final categories = jsonObjects(result['categories'] ?? [])
        .where((c) => _number(c['totalQuestions']) > 0)
        .toList();
    final weak = [
      ...categories,
    ]..sort((a, b) => _percent(a['percent']).compareTo(_percent(b['percent'])));
    final wrong = answers
        .where((a) => a['selectedOption'] != null && a['correct'] != true)
        .length;
    final skipped = answers.where((a) => a['selectedOption'] == null).length;
    final filtered = answers
        .where(
          (a) => switch (_filter) {
            'ALL' => true,
            'WRONG' => a['selectedOption'] != null && a['correct'] != true,
            'SKIPPED' => a['selectedOption'] == null,
            _ => a['category'] == _filter,
          },
        )
        .toList();
    final score = _percent(result['scorePercent']);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            color: QTJPColors.navy,
            borderRadius: BorderRadius.circular(24),
          ),
          child: Column(
            children: [
              const Text(
                'BẢNG KẾT QUẢ · 学習記録',
                style: TextStyle(
                  color: Color(0xFFABCDED),
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                jsonText(result, 'title'),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 23,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 24),
              Semantics(
                label: 'Đúng ${score.toStringAsFixed(1)} phần trăm',
                child: SizedBox(
                  width: 160,
                  height: 160,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      SizedBox.expand(
                        child: CircularProgressIndicator(
                          value: score / 100,
                          strokeWidth: 11,
                          backgroundColor: const Color(0xFF234778),
                          color: const Color(0xFF4CC3AD),
                          strokeCap: StrokeCap.round,
                        ),
                      ),
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '${result['practiceScore'] ?? '—'}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 40,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const Text(
                            '/ 180 điểm',
                            style: TextStyle(color: Color(0xFFBACFE9)),
                          ),
                          Text(
                            '${score.toStringAsFixed(1)}% chính xác',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              height: 2,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 22),
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 8,
                runSpacing: 8,
                children: [
                  _stat(
                    '${result['correctCount'] ?? '—'}/${result['totalQuestions'] ?? '—'} đúng',
                    const Color(0xFFB6F3D6),
                  ),
                  _stat('$wrong sai', const Color(0xFFFFC6C9)),
                  _stat('$skipped bỏ trống', const Color(0xFFFFE29B)),
                ],
              ),
              const SizedBox(height: 16),
              const Text(
                'Điểm luyện tập tham khảo, không phải điểm JLPT chính thức.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Color(0xFFBACFE9),
                  height: 1.6,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        if (categories.isNotEmpty)
          _panel(context, 'Phân tích kỹ năng', [
            if (categories.length >= 3) ...[
              ExamSkillChart(categories: categories, labels: examSkillLabels),
              const SizedBox(height: 24),
            ],
            for (final c in categories) ...[
              Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    margin: const EdgeInsets.only(right: 8),
                    decoration: BoxDecoration(
                      color: examSkillColor(
                        '${c['category']}',
                        dark: Theme.of(context).brightness == Brightness.dark,
                      ),
                      shape: BoxShape.circle,
                    ),
                  ),
                  Expanded(
                    child: Text(
                      examSkillLabels[c['category']] ?? '${c['category']}',
                      style: TextStyle(
                        color: context.qtjp.heading,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  Text(
                    '${_percent(c['percent']).toStringAsFixed(1)}%',
                    style: TextStyle(
                      color: examSkillColor(
                        '${c['category']}',
                        dark: Theme.of(context).brightness == Brightness.dark,
                      ),
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              LinearProgressIndicator(
                value: _percent(c['percent']) / 100,
                minHeight: 8,
                borderRadius: BorderRadius.circular(8),
                color: examSkillColor(
                  '${c['category']}',
                  dark: Theme.of(context).brightness == Brightness.dark,
                ),
                backgroundColor: context.qtjp.soft,
              ),
              const SizedBox(height: 6),
              Text(
                '${c['correctCount']}/${c['totalQuestions']} câu đúng',
                style: TextStyle(color: context.qtjp.muted, fontSize: 12),
              ),
              const SizedBox(height: 16),
            ],
          ]),
        _panel(context, 'Gợi ý ôn tập', [
          Text(
            jsonText(result, 'teacherComment').isEmpty
                ? 'Xem lại các câu sai và luyện tập đều đặn để củng cố kiến thức.'
                : jsonText(result, 'teacherComment'),
            style: const TextStyle(height: 1.7),
          ),
          if (weak.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              'Ưu tiên củng cố: ${examSkillLabels[weak.first['category']] ?? weak.first['category']} (${_percent(weak.first['percent']).toStringAsFixed(1)}% đúng)',
              style: TextStyle(
                color: context.qtjp.blue,
                fontWeight: FontWeight.w800,
                height: 1.6,
              ),
            ),
          ],
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: () {
              _choose('WRONG');
              WidgetsBinding.instance.addPostFrameCallback((_) {
                final target = _review.currentContext;
                if (target != null) {
                  Scrollable.ensureVisible(
                    target,
                    duration: const Duration(milliseconds: 200),
                  );
                }
              });
            },
            icon: const Icon(Icons.manage_search_rounded),
            label: Text('Ôn lại câu sai ($wrong)'),
          ),
        ]),
        const SizedBox(height: 6),
        Text(
          'Đối chiếu đáp án',
          key: _review,
          style: TextStyle(
            color: context.qtjp.heading,
            fontSize: 23,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 12),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              for (final entry in {
                'ALL': 'Tất cả',
                'WRONG': 'Sai ($wrong)',
                'SKIPPED': 'Bỏ trống ($skipped)',
                for (final c in categories)
                  '${c['category']}':
                      examSkillLabels[c['category']] ?? '${c['category']}',
              }.entries)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(entry.value),
                    selected: _filter == entry.key,
                    onSelected: (_) => _choose(entry.key),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Text(
          '${filtered.length} câu',
          style: TextStyle(color: context.qtjp.muted),
        ),
        if (filtered.isEmpty)
          const Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              'Không có câu hỏi trong bộ lọc này.',
              textAlign: TextAlign.center,
            ),
          ),
        for (final answer in filtered.take(_visible))
          widget.answerBuilder(answer),
        if (filtered.length > _visible)
          TextButton(
            onPressed: () => setState(() => _visible += 15),
            child: const Text('Xem thêm câu hỏi'),
          ),
      ],
    );
  }

  Widget _stat(String text, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
    decoration: BoxDecoration(
      color: Colors.white.withValues(alpha: .08),
      borderRadius: BorderRadius.circular(10),
    ),
    child: Text(
      text,
      style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 12),
    ),
  );
  Widget _panel(BuildContext context, String title, List<Widget> children) =>
      Card(
        margin: const EdgeInsets.only(bottom: 16),
        color: context.qtjp.surface,
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                title,
                style: TextStyle(
                  color: context.qtjp.heading,
                  fontSize: 21,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 16),
              ...children,
            ],
          ),
        ),
      );
}
