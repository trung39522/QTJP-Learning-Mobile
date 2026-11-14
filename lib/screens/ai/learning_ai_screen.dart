import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/widgets/kyuto_scaffold.dart';

import '../../app/app_controller.dart';
import '../../core/navigation/app_routes.dart';
import '../../core/network/api_client.dart';
import '../../core/widgets/api_error_view.dart';
import 'learning_ai_repository.dart';

class LearningAiScreen extends StatefulWidget {
  const LearningAiScreen({
    required this.tool,
    this.initialText = '',
    super.key,
  });
  final LearningAiTool tool;
  final String initialText;
  @override
  State<LearningAiScreen> createState() => _LearningAiScreenState();
}

class _LearningAiScreenState extends State<LearningAiScreen> {
  final _input = TextEditingController();
  late AppController _app;
  int? _session;
  int _quotaRequest = 0;
  bool _busy = false, _uncertain = false;
  Map<String, dynamic>? _result, _quota;
  Object? _error;
  String? _quotaError;
  bool get _dictionary => widget.tool == LearningAiTool.dictionary;
  bool _current(int session) =>
      mounted && _app.isAuthenticated && _app.api.sessionVersion == session;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _app = AppScope.of(context);
    if (_session != _app.api.sessionVersion) {
      final first = _session == null;
      _session = _app.api.sessionVersion;
      _quotaRequest++;
      _input.text = first ? widget.initialText : '';
      _result = null;
      _quota = null;
      _error = null;
      _quotaError = null;
      _busy = false;
      _uncertain = false;
      if (_dictionary && _app.isAuthenticated) unawaited(_loadQuota());
    }
  }

  Future<void> _loadQuota({bool acknowledge = false}) async {
    if (!_app.isAuthenticated) return;
    final session = _app.api.sessionVersion, request = ++_quotaRequest;
    try {
      final quota = await LearningAiRepository(_app.api).quota();
      if (_current(session) && request == _quotaRequest) {
        setState(() {
          _quota = quota;
          _quotaError = null;
          if (acknowledge) _uncertain = false;
        });
      }
    } catch (_) {
      if (_current(session) && request == _quotaRequest) {
        setState(
          () => _quotaError = 'Chưa tải được lượt AI. Bạn có thể kiểm tra lại.',
        );
      }
    }
  }

  Future<void> _call({bool explain = false}) async {
    if (_busy || _uncertain || !_app.isAuthenticated) return;
    final session = _app.api.sessionVersion;
    _quotaRequest++;
    setState(() {
      _busy = true;
      _error = null;
      _result = null;
    });
    FocusScope.of(context).unfocus();
    try {
      final result = await LearningAiRepository(_app.api)
          .request(widget.tool, _input.text, explain: explain);
      if (!_current(session)) return;
      setState(() => _result = result);
      if (_dictionary) await _loadQuota();
    } catch (error) {
      if (_current(session)) {
        setState(() {
          _error = error;
          if (_dictionary && error is ApiException) {
            _uncertain = error.code == 'REQUEST_TIMEOUT';
            if (error.details?['quota'] is Map<String, dynamic>) {
              _quota = jsonObject(error.details!['quota']);
            }
          }
        });
      }
    } finally {
      if (_current(session)) setState(() => _busy = false);
    }
  }

  Widget _text(String value) => value.isEmpty
      ? const SizedBox.shrink()
      : Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: SelectableText(value, style: const TextStyle(height: 1.6)),
        );
  List<Widget> _answer() {
    final result = _result!;
    if (_dictionary) {
      final entry = jsonObject(result['entry']);
      return [
        _text(
          result['fromCache'] == true
              ? 'AI · kết quả đã lưu trên máy chủ'
              : 'Kết quả AI · cần kiểm tra khi sử dụng',
        ),
        if (entry['found'] != true) _text('AI chưa tìm thấy từ phù hợp.'),
        _text('${jsonText(entry, 'word')} · ${jsonText(entry, 'reading')}'),
        for (final key in [
          'romaji',
          'meaning',
          'hanViet',
          'partOfSpeech',
          'level',
          'explanation',
          'note',
        ])
          _text(jsonText(entry, key)),
        for (final example in jsonObjects(entry['examples'] ?? [])) ...[
          _text(jsonText(example, 'japanese')),
          _text(jsonText(example, 'vietnamese')),
        ],
        if (aiTexts(entry['relatedWords']).isNotEmpty)
          _text('Từ liên quan: ${aiTexts(entry['relatedWords']).join(' · ')}'),
      ];
    }
    return [
      _text(jsonText(result, 'sentence')),
      _text(jsonText(result, 'translation')),
      if (jsonObjects(result['grammarPoints'] ?? []).isEmpty)
        _text('Chưa có điểm ngữ pháp trong kết quả máy chủ.'),
      for (final item in jsonObjects(result['grammarPoints'] ?? []))
        _grammarPoint(item),
    ];
  }

  Widget _grammarPoint(Map<String, dynamic> item) {
    final grammar = jsonObject(item['grammar']);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final key in ['pattern', 'level', 'meaning', 'usage'])
              _text(jsonText(grammar, key)),
            for (final key in ['structure', 'notes', 'relatedPatterns'])
              for (final text in aiTexts(grammar[key])) _text(text),
            _text(jsonText(item, 'contextNote')),
            for (final example in jsonObjects(grammar['examples'] ?? [])) ...[
              _text(
                jsonObjects(example['segments'] ?? [])
                    .map((segment) => jsonText(segment, 'text'))
                    .join(),
              ),
              _text(jsonText(example, 'translation')),
            ],
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => KyutoScaffold(
    appBar: AppBar(
      title: Text(_dictionary ? 'Từ điển AI' : 'Phân tích ngữ pháp AI'),
    ),
    body: SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          if (!_app.isAuthenticated)
            ApiErrorView(
              error: const ApiException(
                'Đăng nhập để sử dụng AI của QTJP.',
                status: 401,
              ),
              onRetry: () => setState(() {}),
            )
          else ...[
            TextField(
              key: const ValueKey('learning-ai-input'),
              controller: _input,
              enabled: !_busy,
              maxLength: _dictionary ? 100 : 1000,
              minLines: _dictionary ? 1 : 3,
              maxLines: _dictionary ? 2 : 8,
              decoration: InputDecoration(
                labelText: _dictionary ? 'Từ cần tra' : 'Câu hoặc mẫu ngữ pháp',
                border: const OutlineInputBorder(),
              ),
            ),
            FilledButton.icon(
              key: const ValueKey('learning-ai-submit'),
              onPressed: _busy || _uncertain ? null : _call,
              icon: const Icon(Icons.auto_awesome),
              label: Text(
                _busy
                    ? 'AI đang xử lý…'
                    : _dictionary
                    ? 'Tra cứu bằng AI'
                    : 'Phân tích bằng AI',
              ),
            ),
            if (_dictionary)
              OutlinedButton(
                key: const ValueKey('learning-ai-explain'),
                onPressed: _busy || _uncertain
                    ? null
                    : () => _call(explain: true),
                child: const Text('AI giải thích chi tiết'),
              ),
            if (_busy) const LinearProgressIndicator(),
            if (_quota != null)
              _text(
                _quota!['vip'] == true
                    ? 'Lượt AI theo gói VIP · máy chủ quản lý'
                    : 'Lượt AI còn lại: ${_quota!['remaining']} · làm mới: ${_quota!['resetAt'] ?? ''}',
              ),
            if (_quotaError != null) _text(_quotaError!),
            if (_dictionary)
              TextButton(
                onPressed: _busy ? null : () => _loadQuota(acknowledge: true),
                child: Text(
                  _uncertain
                      ? 'Kiểm tra lượt AI trước khi thử lại'
                      : 'Cập nhật lượt AI',
                ),
              ),
            if (_error != null)
              _text(
                _uncertain
                    ? 'Chưa nhận được kết quả; máy chủ có thể vẫn đang xử lý. Kiểm tra lượt AI trước khi gửi lại.'
                    : _error is ApiException
                    ? _error.toString()
                    : 'AI tạm thời chưa phản hồi. Vui lòng thử lại.',
              ),
            TextButton(
              onPressed: () async {
                final session = _app.api.sessionVersion;
                await Navigator.pushNamed(context, AppRoutes.vip);
                if (_dictionary && _current(session)) await _loadQuota();
              },
              child: const Text('Xem gói VIP và thanh toán'),
            ),
            if (_result != null) ..._answer(),
          ],
        ],
      ),
    ),
  );
}
