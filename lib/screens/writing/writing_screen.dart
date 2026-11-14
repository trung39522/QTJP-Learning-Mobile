import 'package:flutter/material.dart';

import '../../core/widgets/kyuto_scaffold.dart';

import '../../app/app_controller.dart';
import '../../core/theme/qtjp_colors.dart';
import '../../core/widgets/api_error_view.dart';
import '../../core/widgets/qtjp_feature_intro.dart';
import '../home/widgets/jlpt_level_selector.dart';
import 'writing_editor_screen.dart';
import 'writing_history_screen.dart';
import 'writing_repository.dart';

class WritingScreen extends StatefulWidget {
  const WritingScreen({required this.initialLevel, super.key});
  final String initialLevel;
  @override
  State<WritingScreen> createState() => _WritingScreenState();
}

class _WritingScreenState extends State<WritingScreen> {
  static const categories = [
    'Đời sống',
    'Sở thích',
    'Du lịch',
    'Ẩm thực',
    'Học tập',
    'Công việc',
    'Công nghệ',
    'Văn hóa',
    'Môi trường',
  ];
  late String _level = widget.initialLevel;
  String _category = categories.first;
  late AppController _app;
  late WritingRepository _repository;
  Future<List<WritingTopic>>? _topics;
  int? _sessionVersion;
  int _generation = 0;
  bool _generating = false;
  Object? _error;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _app = AppScope.of(context);
    _repository = WritingRepository(_app.api);
    if (_topics == null || _sessionVersion != _app.api.sessionVersion) {
      _generation++;
      _sessionVersion = _app.api.sessionVersion;
      _generating = false;
      _error = null;
      _topics = _repository.topics(_level);
    }
  }

  void _reload() => setState(() {
    _error = null;
    _topics = _repository.topics(_level);
  });

  Future<void> _generate() async {
    if (_generating) return;
    final generation = _generation;
    setState(() {
      _generating = true;
      _error = null;
    });
    try {
      final topic = await _repository.generate(_level, _category);
      if (!mounted || generation != _generation) return;
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => WritingEditorScreen(topic: topic),
        ),
      );
      if (mounted && generation == _generation) _reload();
    } catch (error) {
      if (mounted && generation == _generation) setState(() => _error = error);
    } finally {
      if (mounted && generation == _generation) {
        setState(() => _generating = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) => KyutoScaffold(
    appBar: AppBar(
      title: const Text('Luyện viết với AI'),
      actions: [
        IconButton(
          onPressed: _generating ? null : _reload,
          icon: const Icon(Icons.refresh),
          tooltip: 'Tải lại chủ đề',
        ),
        IconButton(
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => const WritingHistoryScreen(),
            ),
          ),
          icon: const Icon(Icons.history),
          tooltip: 'Lịch sử & thống kê',
        ),
      ],
    ),
    body: SafeArea(
      top: false,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const QTJPFeatureIntro(QTJPFeature.writing),
                const Text(
                  'BƯỚC 01 / CHUẨN BỊ',
                  style: TextStyle(
                    color: QTJPColors.red,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Chọn bài luyện viết',
                  style: TextStyle(
                    color: context.qtjp.heading,
                    fontSize: 21,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 12),
                JlptLevelSelector(
                  selectedLevel: _level,
                  onSelected: (level) {
                    if (_generating || _level == level) return;
                    _level = level;
                    _reload();
                  },
                ),
                const SizedBox(height: 20),
                FutureBuilder<List<WritingTopic>>(
                  future: _topics,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState != ConnectionState.done) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (snapshot.hasError) {
                      return ApiErrorView(
                        error: snapshot.error!,
                        onRetry: _reload,
                      );
                    }
                    final topics = snapshot.data ?? [];
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (topics.isEmpty)
                          Text('Máy chủ chưa có chủ đề $_level.'),
                        for (final topic in topics)
                          Card(
                            margin: const EdgeInsets.only(bottom: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(18),
                              side: BorderSide(color: context.qtjp.border),
                            ),
                            child: ListTile(
                              contentPadding: const EdgeInsets.all(16),
                              leading: Icon(
                                Icons.edit_note_rounded,
                                color: context.qtjp.heading,
                              ),
                              key: ValueKey('writing-topic-${topic.id}'),
                              title: Text(topic.title),
                              subtitle: Text(
                                '${topic.level} · ${topic.category}',
                              ),
                              trailing: const Icon(Icons.chevron_right),
                              onTap: _generating
                                  ? null
                                  : () => Navigator.of(context).push(
                                      MaterialPageRoute<void>(
                                        builder: (_) =>
                                            WritingEditorScreen(topic: topic),
                                      ),
                                    ),
                            ),
                          ),
                        const SizedBox(height: 20),
                        const Text(
                          'AI tạo đề mới',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Chỉ gửi yêu cầu khi bạn bấm tạo đề. Giới hạn lượt theo tài khoản được kiểm tra bởi máy chủ.',
                          style: TextStyle(
                            color: context.qtjp.muted,
                            height: 1.6,
                          ),
                        ),
                        const SizedBox(height: 12),
                        DropdownButtonFormField<String>(
                          initialValue: _category,
                          isExpanded: true,
                          decoration: const InputDecoration(
                            labelText: 'Chủ đề',
                            border: OutlineInputBorder(),
                          ),
                          items: [
                            for (final category in categories)
                              DropdownMenuItem(
                                value: category,
                                child: Text(category),
                              ),
                          ],
                          onChanged: _generating
                              ? null
                              : (value) => setState(() => _category = value!),
                        ),
                        const SizedBox(height: 12),
                        FilledButton.icon(
                          key: const ValueKey('writing-generate'),
                          onPressed: _generating ? null : _generate,
                          icon: const Icon(Icons.auto_awesome),
                          label: Text(
                            _generating ? 'Đang tạo đề…' : 'Tạo đề AI',
                          ),
                        ),
                        if (_generating) const LinearProgressIndicator(),
                        if (_error != null)
                          ApiErrorView(error: _error!, onRetry: _reload),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
