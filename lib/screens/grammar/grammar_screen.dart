import 'package:flutter/material.dart';

import '../../app/app_controller.dart';
import '../../core/network/api_client.dart';
import '../../core/theme/qtjp_colors.dart';
import '../../core/widgets/api_error_view.dart';
import '../home/widgets/jlpt_level_selector.dart';
import 'grammar_repository.dart';
import '../ai/learning_ai_repository.dart';
import '../ai/learning_ai_screen.dart';

class GrammarScreen extends StatefulWidget {
  const GrammarScreen({required this.initialLevel, super.key});
  final String initialLevel;
  @override
  State<GrammarScreen> createState() => _GrammarScreenState();
}

class _GrammarScreenState extends State<GrammarScreen> {
  late String _level = widget.initialLevel;
  Future<List<Map<String, dynamic>>>? _lessons;
  late GrammarRepository _repository;
  int? _sessionVersion;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final app = AppScope.of(context);
    _repository = GrammarRepository(app.api);
    if (_lessons == null || _sessionVersion != app.api.sessionVersion) {
      _sessionVersion = app.api.sessionVersion;
      _lessons = _repository.lessons(_level);
    }
  }

  void _reload() => setState(() => _lessons = _repository.lessons(_level));

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Ngữ pháp tiếng Nhật'),
      actions: [
        IconButton(
          onPressed: _reload,
          icon: const Icon(Icons.refresh),
          tooltip: 'Tải lại bài học',
        ),
      ],
    ),
    body: SafeArea(
      top: false,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'Học theo giáo trình QTJP',
                      style: TextStyle(
                        color: QTJPColors.navy,
                        fontSize: 25,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 16),
                    OutlinedButton.icon(
                      key: const ValueKey('grammar-ai'),
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute<void>(
                          builder: (_) => const LearningAiScreen(
                            tool: LearningAiTool.grammar,
                          ),
                        ),
                      ),
                      icon: const Icon(Icons.auto_awesome),
                      label: const Text('Tra mẫu / phân tích câu bằng AI'),
                    ),
                    JlptLevelSelector(
                      selectedLevel: _level,
                      onSelected: (level) {
                        _level = level;
                        _reload();
                      },
                    ),
                    const SizedBox(height: 12),
                    Text('Cấp độ đang chọn: $_level'),
                  ],
                ),
              ),
              Expanded(
                child: FutureBuilder<List<Map<String, dynamic>>>(
                  future: _lessons,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState != ConnectionState.done) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (snapshot.hasError) {
                      return SingleChildScrollView(
                        padding: const EdgeInsets.all(20),
                        child: ApiErrorView(
                          error: snapshot.error!,
                          onRetry: _reload,
                        ),
                      );
                    }
                    final lessons = snapshot.data ?? [];
                    if (lessons.isEmpty) {
                      return Center(
                        child: Text('Máy chủ chưa có bài học $_level.'),
                      );
                    }
                    return ListView.builder(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                      itemCount: lessons.length,
                      itemBuilder: (context, index) {
                        final lesson = lessons[index];
                        return Card(
                          child: ListTile(
                            contentPadding: const EdgeInsets.all(16),
                            leading: CircleAvatar(
                              child: Text(jsonText(lesson, 'lessonNumber')),
                            ),
                            title: Text(
                              jsonText(lesson, 'title'),
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            subtitle: Text(jsonText(lesson, 'description')),
                            trailing: const Icon(Icons.chevron_right),
                            onTap: () => Navigator.of(context).push(
                              MaterialPageRoute<void>(
                                builder: (_) => GrammarLessonScreen(
                                  id: jsonText(lesson, 'id'),
                                  repository: _repository,
                                ),
                              ),
                            ),
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

class GrammarLessonScreen extends StatefulWidget {
  const GrammarLessonScreen({
    required this.id,
    required this.repository,
    super.key,
  });
  final String id;
  final GrammarRepository repository;
  @override
  State<GrammarLessonScreen> createState() => _GrammarLessonScreenState();
}

class _GrammarLessonScreenState extends State<GrammarLessonScreen> {
  Future<Map<String, dynamic>>? _lesson;
  int? _sessionVersion;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final api = AppScope.of(context).api;
    if (_lesson == null || _sessionVersion != api.sessionVersion) {
      _sessionVersion = api.sessionVersion;
      _lesson = widget.repository.lesson(widget.id);
    }
  }

  void _reload() =>
      setState(() => _lesson = widget.repository.lesson(widget.id));

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Chi tiết ngữ pháp')),
    body: SafeArea(
      top: false,
      child: FutureBuilder<Map<String, dynamic>>(
        future: _lesson,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ApiErrorView(error: snapshot.error!, onRetry: _reload),
            );
          }
          final lesson = snapshot.data!;
          final points = jsonObjects(lesson['grammarPoints'] ?? []);
          return SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 760),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      '${jsonText(lesson, 'level')} · Bài ${jsonText(lesson, 'lessonNumber')}',
                      style: const TextStyle(
                        color: QTJPColors.red,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      jsonText(lesson, 'title'),
                      style: const TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w900,
                        color: QTJPColors.navy,
                      ),
                    ),
                    if (points.isEmpty)
                      const Padding(
                        padding: EdgeInsets.all(20),
                        child: Text('Bài học chưa có nội dung trên máy chủ.'),
                      ),
                    for (final point in points)
                      Card(
                        margin: const EdgeInsets.only(top: 20),
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Text(
                                jsonText(point, 'pattern'),
                                style: const TextStyle(
                                  fontSize: 25,
                                  color: QTJPColors.navy,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              _paragraph(jsonText(point, 'meaning')),
                              for (final structure
                                  in (point['structure'] as List? ?? []))
                                _paragraph(structure.toString()),
                              _paragraph(jsonText(point, 'usage')),
                              ..._examples(point['examples']),
                              for (final usageCase in jsonObjects(
                                point['usageCases'] ?? [],
                              )) ...[
                                _paragraph(
                                  jsonText(usageCase, 'title'),
                                  emphasized: true,
                                ),
                                _paragraph(jsonText(usageCase, 'usage')),
                                ..._examples(usageCase['examples']),
                                for (final note
                                    in (usageCase['notes'] as List? ?? []))
                                  _paragraph('Lưu ý: $note'),
                              ],
                              for (final note
                                  in (point['notes'] as List? ?? []))
                                _paragraph('Lưu ý: $note'),
                              if ((point['relatedPatterns'] as List? ?? [])
                                  .isNotEmpty)
                                _paragraph(
                                  'Liên quan: ${(point['relatedPatterns'] as List).join(' · ')}',
                                ),
                            ],
                          ),
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

  Widget _paragraph(String text, {bool emphasized = false}) => text.isEmpty
      ? const SizedBox.shrink()
      : Padding(
          padding: const EdgeInsets.only(top: 12),
          child: SelectableText(
            text,
            style: TextStyle(
              height: 1.7,
              fontWeight: emphasized ? FontWeight.w800 : FontWeight.normal,
            ),
          ),
        );

  List<Widget> _examples(Object? data) => [
    for (final example in jsonObjects(data ?? [])) ...[
      _paragraph(
        jsonObjects(example['segments'] ?? [])
            .map((s) => jsonText(s, 'text'))
            .join(),
      ),
      _paragraph(jsonText(example, 'translation')),
    ],
  ];
}
