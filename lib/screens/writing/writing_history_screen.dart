import 'package:flutter/material.dart';

import '../../app/app_controller.dart';
import '../../core/network/api_client.dart';
import '../../core/theme/qtjp_colors.dart';
import '../../core/widgets/api_error_view.dart';
import 'writing_editor_screen.dart';
import 'writing_repository.dart';

class WritingHistoryScreen extends StatefulWidget {
  const WritingHistoryScreen({super.key});
  @override
  State<WritingHistoryScreen> createState() => _WritingHistoryScreenState();
}

class _WritingHistoryScreenState extends State<WritingHistoryScreen> {
  late WritingRepository _repository;
  Future<WritingHistory>? _history;
  int? _sessionVersion;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final app = AppScope.of(context);
    _repository = WritingRepository(app.api);
    if (_history == null || _sessionVersion != app.api.sessionVersion) {
      _sessionVersion = app.api.sessionVersion;
      _history = _repository.history();
    }
  }

  void _reload() => setState(() => _history = _repository.history());
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Lịch sử & thống kê viết'),
      actions: [
        IconButton(
          onPressed: _reload,
          icon: const Icon(Icons.refresh),
          tooltip: 'Tải lại lịch sử',
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
            child: FutureBuilder<WritingHistory>(
              future: _history,
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return ApiErrorView(error: snapshot.error!, onRetry: _reload);
                }
                final history = snapshot.data!;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const Text(
                              'Thống kê tài khoản',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            Text(
                              'Bài viết: ${jsonText(history.stats, 'totalWritings')} · Lượt nộp: ${jsonText(history.stats, 'totalSubmissions')}',
                            ),
                            Text(
                              'Điểm trung bình: ${jsonText(history.stats, 'averageScore')} · Cao nhất: ${jsonText(history.stats, 'highestScore')}',
                            ),
                            Text(
                              'Tổng lỗi: ${jsonText(history.stats, 'totalErrors')}',
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    if (history.groups.isEmpty)
                      const Text('Bạn chưa nộp bài viết nào.'),
                    for (final group in history.groups)
                      Card(
                        child: ExpansionTile(
                          title: Text(
                            '${group.topic.level} · ${group.topic.title}',
                          ),
                          subtitle: Text(
                            '${group.attempts.length} lần nộp · Điểm gần nhất: ${group.latestScore ?? '—'}',
                          ),
                          expandedCrossAxisAlignment:
                              CrossAxisAlignment.stretch,
                          childrenPadding: const EdgeInsets.all(16),
                          children: [
                            if (group.improvement != null)
                              Text(
                                'Tiến bộ so với lần đầu: ${group.improvement! >= 0 ? '+' : ''}${group.improvement} điểm',
                              ),
                            for (final attempt in group.attempts)
                              Padding(
                                padding: const EdgeInsets.only(top: 16),
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    Text(
                                      'Lần ${attempt.number} · ${attempt.score ?? '—'}/100',
                                      style: const TextStyle(
                                        color: QTJPColors.navy,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                    Text(attempt.date.replaceFirst('T', ' ')),
                                    const SizedBox(height: 8),
                                    SelectableText(
                                      attempt.text,
                                      style: const TextStyle(height: 1.7),
                                    ),
                                    TextButton(
                                      onPressed: () async {
                                        await Navigator.of(context).push(
                                          MaterialPageRoute<void>(
                                            builder: (_) => WritingEditorScreen(
                                              topic: group.topic,
                                              initialText: attempt.text,
                                              parentWritingId: attempt.id,
                                            ),
                                          ),
                                        );
                                        if (mounted) _reload();
                                      },
                                      child: const Text('Sửa bài này'),
                                    ),
                                    const Divider(),
                                  ],
                                ),
                              ),
                          ],
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    ),
  );
}
