import 'package:flutter/material.dart';

import '../../core/widgets/kyuto_scaffold.dart';

import '../../app/app_controller.dart';

import 'dart:async';

import '../alphabet/services/kana_speech.dart';
import 'widgets/grammar_point_card.dart';
import '../../core/network/api_client.dart';
import '../../core/theme/qtjp_colors.dart';
import '../../core/widgets/api_error_view.dart';
import '../../core/widgets/qtjp_feature_intro.dart';
import '../home/widgets/jlpt_level_selector.dart';
import 'grammar_repository.dart';
import 'conjugation_screen.dart';
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
  Widget build(BuildContext context) => KyutoScaffold(
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
          child: NestedScrollView(
            headerSliverBuilder: (context, innerBoxIsScrolled) => [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const QTJPFeatureIntro(QTJPFeature.grammar),
                      OutlinedButton.icon(
                        key: const ValueKey('grammar-conjugation'),
                        onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute<void>(
                            builder: (_) => const ConjugationScreen(),
                          ),
                        ),
                        icon: const Icon(Icons.table_chart_outlined),
                        label: const Text('Bảng chia 12 thể động từ'),
                      ),
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
              ),
            ],
            body: FutureBuilder<List<Map<String, dynamic>>>(
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
                  return Center(child: Text('Chưa có bài học cho $_level.'));
                }
                return ListView.builder(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                  itemCount: lessons.length,
                  itemBuilder: (context, index) {
                    final lesson = lessons[index];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                        side: BorderSide(color: context.qtjp.border),
                      ),
                      child: ListTile(
                        contentPadding: const EdgeInsets.all(16),
                        leading: CircleAvatar(
                          backgroundColor: context.qtjp.soft,
                          child: Text(
                            jsonText(lesson, 'lessonNumber'),
                            style: TextStyle(
                              color: context.qtjp.heading,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        title: Text(
                          jsonText(lesson, 'title'),
                          style: TextStyle(
                            color: context.qtjp.heading,
                            fontSize: 17,
                            height: 1.5,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
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
  final _speech = DeviceKanaSpeech();
  final _anchors = <int, GlobalKey>{};

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

  Future<void> _speak(String text) async {
    if (text.isEmpty) return;
    try {
      await _speech.speak(text);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              error is KanaSpeechFailure
                  ? error.message
                  : 'Chưa thể phát âm. Hãy thử lại.',
            ),
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    unawaited(_speech.stop());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => KyutoScaffold(
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
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
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
                          Text(
                            '${jsonText(lesson, 'level')} · Bài ${jsonText(lesson, 'lessonNumber')}',
                            style: const TextStyle(
                              color: Color(0xFFA9CFF0),
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            jsonText(lesson, 'title'),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 25,
                              fontWeight: FontWeight.w900,
                              height: 1.4,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            '${points.length} mẫu ngữ pháp',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (points.isEmpty)
                      const Padding(
                        padding: EdgeInsets.all(24),
                        child: Text(
                          'Bài học chưa có nội dung.',
                          textAlign: TextAlign.center,
                        ),
                      ),
                    if (points.isNotEmpty) ...[
                      const SizedBox(height: 22),
                      Text(
                        'Trong bài học này',
                        style: TextStyle(
                          color: context.qtjp.heading,
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final (index, point) in points.indexed)
                            ConstrainedBox(
                              constraints: BoxConstraints(
                                maxWidth: MediaQuery.sizeOf(context).width - 64,
                              ),
                              child: ActionChip(
                                label: Text(
                                  '${index + 1}. ${jsonText(point, 'pattern')}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                onPressed: () {
                                  final anchor =
                                      _anchors[index]?.currentContext;
                                  if (anchor != null) {
                                    unawaited(
                                      Scrollable.ensureVisible(
                                        anchor,
                                        duration: const Duration(
                                          milliseconds: 220,
                                        ),
                                        alignment: .02,
                                      ),
                                    );
                                  }
                                },
                              ),
                            ),
                        ],
                      ),
                    ],
                    for (final (index, point) in points.indexed)
                      GrammarPointCard(
                        key: _anchors.putIfAbsent(index, GlobalKey.new),
                        point: point,
                        number: index + 1,
                        onSpeak: _speak,
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
