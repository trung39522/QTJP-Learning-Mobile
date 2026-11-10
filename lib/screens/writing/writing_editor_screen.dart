import 'package:flutter/material.dart';

import '../../app/app_controller.dart';
import '../../core/navigation/app_routes.dart';
import '../../core/network/api_client.dart';
import '../../core/theme/qtjp_colors.dart';
import '../../core/widgets/api_error_view.dart';
import 'writing_history_screen.dart';
import 'writing_repository.dart';

class WritingEditorScreen extends StatefulWidget {
  const WritingEditorScreen({
    required this.topic,
    this.initialText = '',
    this.parentWritingId,
    super.key,
  });
  final WritingTopic topic;
  final String initialText;
  final int? parentWritingId;
  @override
  State<WritingEditorScreen> createState() => _WritingEditorScreenState();
}

class _WritingEditorScreenState extends State<WritingEditorScreen> {
  late final _input = TextEditingController(text: widget.initialText);
  late String _savedText = widget.initialText;
  late int? _parentId = widget.parentWritingId;
  late AppController _app;
  Object? _owner;
  bool _bound = false;
  bool _busy = false;
  bool _allowPop = false;
  bool _confirming = false;
  bool _uncertain = false;
  WritingReview? _review;
  Object? _error;
  bool get _dirty => _input.text != _savedText;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _app = AppScope.of(context);
    if (!_bound) {
      _bound = true;
      _owner = _app.user?['id'];
    }
  }

  Future<void> _leave() async {
    if (_confirming) return;
    _confirming = true;
    final leave = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Rời bài viết?'),
        content: Text(
          _busy
              ? 'Máy chủ có thể tiếp tục chấm bài sau khi bạn rời màn hình. Kiểm tra lịch sử trước khi nộp lại.'
              : 'Bản thảo chưa nộp chỉ nằm trong màn hình này và sẽ không được giữ nếu bạn rời đi.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Ở lại'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Rời bài viết'),
          ),
        ],
      ),
    );
    _confirming = false;
    if (leave == true && mounted) {
      setState(() => _allowPop = true);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) Navigator.of(context).pop();
      });
    }
  }

  Future<void> _submit() async {
    if (_busy || _uncertain || _review != null) return;
    final text = _input.text.trim();
    if (text.isEmpty || text.length > 10000) {
      setState(
        () => _error = const ApiException(
          'Hãy viết từ 1 đến 10.000 ký tự trước khi nộp.',
        ),
      );
      return;
    }
    final token = _app.api.token;
    setState(() {
      _busy = true;
      _error = null;
    });
    FocusScope.of(context).unfocus();
    try {
      final review = await WritingRepository(_app.api)
          .submit(widget.topic.id, text, parentWritingId: _parentId);
      if (!mounted || token != _app.api.token) return;
      setState(() {
        _review = review;
        _savedText = _input.text;
        _parentId = null;
      });
    } catch (error) {
      if (mounted && token == _app.api.token) {
        setState(() {
          _error = error;
          _uncertain = error is ApiException && error.code == 'REQUEST_TIMEOUT';
        });
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ownerValid = _app.isAuthenticated && _app.user?['id'] == _owner;
    return PopScope(
      canPop: _allowPop || (!_busy && !_dirty),
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _leave();
      },
      child: Scaffold(
        appBar: AppBar(title: const Text('Bài luyện viết')),
        body: SafeArea(
          top: false,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 760),
                child: !ownerValid
                    ? ApiErrorView(
                        error: const ApiException(
                          'Phiên học đã thay đổi. Đăng nhập lại tài khoản ban đầu hoặc quay lại chọn chủ đề.',
                          status: 401,
                        ),
                        onRetry: () => setState(() {}),
                      )
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            '${widget.topic.level} · ${widget.topic.title}',
                            style: const TextStyle(
                              fontSize: 24,
                              color: QTJPColors.navy,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          if (widget.topic.minSentences != null)
                            _text(
                              'Gợi ý: ${widget.topic.minSentences}–${widget.topic.maxSentences ?? widget.topic.minSentences} câu.',
                            ),
                          if (widget.topic.vocabularyHints.isNotEmpty)
                            _text(
                              'Từ vựng gợi ý: ${widget.topic.vocabularyHints.join(' · ')}',
                            ),
                          if (widget.topic.grammarHints.isNotEmpty)
                            _text(
                              'Ngữ pháp gợi ý: ${widget.topic.grammarHints.join(' · ')}',
                            ),
                          if (_parentId != null)
                            _text(
                              'Đang sửa bài #$_parentId. Lần nộp này được lưu cùng chuỗi luyện viết.',
                            ),
                          const SizedBox(height: 20),
                          TextField(
                            key: const ValueKey('writing-input'),
                            controller: _input,
                            minLines: 7,
                            maxLines: 15,
                            maxLength: 10000,
                            readOnly: _busy || _review != null,
                            onChanged: (_) => setState(() {}),
                            decoration: const InputDecoration(
                              labelText: 'Bài viết tiếng Nhật',
                              alignLabelWithHint: true,
                              border: OutlineInputBorder(),
                            ),
                          ),
                          const SizedBox(height: 12),
                          FilledButton.icon(
                            key: const ValueKey('writing-submit'),
                            onPressed: _busy || _uncertain || _review != null
                                ? null
                                : _submit,
                            icon: const Icon(Icons.send_outlined),
                            label: Text(
                              _busy
                                  ? 'AI đang chấm bài…'
                                  : _parentId == null
                                  ? 'Gửi chấm AI'
                                  : 'Nộp bài sửa',
                            ),
                          ),
                          if (_busy) ...[
                            const LinearProgressIndicator(),
                            _text(
                              'Có thể mất vài phút. Không cần bấm gửi lại.',
                            ),
                          ],
                          if (_error != null) ...[
                            _text(
                              _error is ApiException ? _error.toString() : 'Chưa thể chấm bài. Bản thảo vẫn được giữ tại đây.',
                            ),
                            if (_error is ApiException &&
                                (_error as ApiException).requiresLogin)
                              TextButton(
                                onPressed: () =>
                                    Navigator.of(context)
                                        .pushNamed(AppRoutes.login),
                                child: const Text('Đăng nhập lại'),
                              ),
                          ],
                          if (_uncertain)
                            OutlinedButton(
                              onPressed: () async {
                                await Navigator.of(context).push(
                                  MaterialPageRoute<void>(
                                    builder: (_) =>
                                        const WritingHistoryScreen(),
                                  ),
                                );
                                if (mounted) setState(() => _uncertain = false);
                              },
                              child: const Text(
                                'Kiểm tra lịch sử trước khi gửi lại',
                              ),
                            ),
                          if (_review case final review?) ...[
                            const SizedBox(height: 24),
                            Text(
                              'Kết quả: ${review.score}/100 · Lần ${review.attempt}',
                              key: const ValueKey('writing-score'),
                              style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.w800,
                                color: QTJPColors.navy,
                              ),
                            ),
                            if (review.improvement != null)
                              _text(
                                'So với lần trước: ${review.improvement! >= 0 ? '+' : ''}${review.improvement} điểm',
                              ),
                            _text(review.summary),
                            for (final entry in const {
                              'grammar': 'Ngữ pháp',
                              'vocabulary': 'Từ vựng',
                              'naturalness': 'Tự nhiên',
                              'task': 'Đáp ứng đề',
                              'kanji': 'Kanji',
                            }.entries)
                              if (review.scores[entry.key] != null)
                                _text(
                                  '${entry.value}: ${review.scores[entry.key]}',
                                ),
                            for (final correction in review.corrections)
                              Card(
                                child: Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: [
                                      _text(
                                        '${jsonText(correction, 'original')} → ${jsonText(correction, 'corrected')}',
                                      ),
                                      _text(
                                        '${jsonText(correction, 'errorType')}: ${jsonText(correction, 'explanation')}',
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            if (review.correctedText.isNotEmpty) ...[
                              _heading('Bài viết đã chỉnh'),
                              _text(review.correctedText),
                            ],
                            if (review.strengths.isNotEmpty)
                              _heading('Điểm tốt'),
                            for (final strength in review.strengths)
                              _text('• $strength'),
                            if (review.nextSteps.isNotEmpty)
                              _heading('Bước cải thiện'),
                            for (final step in review.nextSteps)
                              _text('• $step'),
                            if (review.suggestions.isNotEmpty)
                              _heading('Từ vựng gợi ý'),
                            for (final word in review.suggestions)
                              _text(
                                '${jsonText(word, 'word')} (${jsonText(word, 'reading')}): ${jsonText(word, 'meaning')}',
                              ),
                            const SizedBox(height: 16),
                            OutlinedButton(
                              key: const ValueKey('writing-revise'),
                              onPressed: () => setState(() {
                                _parentId = review.id;
                                _review = null;
                                _error = null;
                              }),
                              child: const Text('Sửa bài và nộp lại'),
                            ),
                            OutlinedButton(
                              onPressed: () => Navigator.of(context).push(
                                MaterialPageRoute<void>(
                                  builder: (_) => const WritingHistoryScreen(),
                                ),
                              ),
                              child: const Text('Xem lịch sử & thống kê'),
                            ),
                          ],
                        ],
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _text(String text) => Padding(
    padding: const EdgeInsets.only(top: 12),
    child: SelectableText(text, style: const TextStyle(height: 1.7)),
  );
  Widget _heading(String text) => Padding(
    padding: const EdgeInsets.only(top: 20),
    child: Text(
      text,
      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
    ),
  );
}
