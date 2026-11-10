import 'package:flutter/material.dart';

import '../../app/app_controller.dart';
import '../../core/network/api_client.dart';
import '../../core/navigation/app_routes.dart';
import '../../core/theme/qtjp_colors.dart';
import '../../core/widgets/api_error_view.dart';
import 'assistant_repository.dart';

class _ChatMessage {
  const _ChatMessage(this.turn, [this.reply]);
  final AssistantTurn turn;
  final AssistantReply? reply;
}

class AssistantScreen extends StatefulWidget {
  const AssistantScreen({this.initialMessage, super.key});
  final String? initialMessage;
  @override
  State<AssistantScreen> createState() => _AssistantScreenState();
}

class _AssistantScreenState extends State<AssistantScreen> {
  final _input = TextEditingController();
  final _scroll = ScrollController();
  final _messages = <_ChatMessage>[];
  late AppController _app;
  int? _sessionVersion;
  int _generation = 0;
  int? _remaining;
  bool _busy = false;
  String? _pending;
  Object? _error;
  List<AssistantLink> _fallbackLinks = [];
  List<Map<String, dynamic>> _fallbackSources = [];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _app = AppScope.of(context);
    if (_sessionVersion != _app.api.sessionVersion) {
      final firstSession = _sessionVersion == null;
      _generation++;
      _sessionVersion = _app.api.sessionVersion;
      _messages.clear();
      _input.clear();
      if (firstSession &&
          _app.isAuthenticated &&
          widget.initialMessage != null) {
        _input.text = widget.initialMessage!;
      }
      _remaining = null;
      _error = null;
      _fallbackLinks = [];
      _fallbackSources = [];
      _busy = false;
      _pending = null;
    }
    if (_app.user?['isVip'] == true) _remaining = null;
  }

  void _toBottom() => WidgetsBinding.instance.addPostFrameCallback((_) {
    if (mounted && _scroll.hasClients) {
      _scroll.animateTo(
        _scroll.position.maxScrollExtent,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
    }
  });

  Future<void> _send() async {
    final question = _input.text.trim();
    if (_busy || question.isEmpty) return;
    final generation = _generation;
    final history = _messages
        .map((message) => message.turn)
        .toList(growable: false);
    setState(() {
      _busy = true;
      _pending = question;
      _error = null;
      _fallbackLinks = [];
      _fallbackSources = [];
    });
    FocusScope.of(context).unfocus();
    _toBottom();
    try {
      final reply = await AssistantRepository(_app.api).send(question, history);
      if (!mounted || generation != _generation) return;
      setState(() {
        _messages.add(_ChatMessage(AssistantTurn('user', question)));
        _messages.add(
          _ChatMessage(AssistantTurn('assistant', reply.answer), reply),
        );
        if (_messages.length > 100) {
          _messages.removeRange(0, _messages.length - 100);
        }
        if (reply.remaining != null) _remaining = reply.remaining;
        _input.clear();
      });
    } catch (error) {
      if (mounted && generation == _generation) {
        setState(() {
          _error = error;
          if (error is ApiException) {
            if (error.code == 'QUOTA_EXCEEDED') _remaining = 0;
            try {
              _fallbackLinks = jsonObjects(error.details?['links'] ?? [])
                  .map(AssistantLink.fromJson)
                  .toList(growable: false);
            } on ApiException {
              _fallbackLinks = [];
            }
            try {
              _fallbackSources = jsonObjects(error.details?['sources'] ?? []);
            } on ApiException {
              _fallbackSources = [];
            }
          }
        });
      }
    } finally {
      if (mounted && generation == _generation) {
        setState(() {
          _busy = false;
          _pending = null;
        });
        _toBottom();
      }
    }
  }

  void _openRoute(String route) {
    if (route == '/') {
      Navigator.of(context).popUntil((route) => route.isFirst);
    } else {
      Navigator.of(context).pushNamed(route);
    }
  }

  @override
  void dispose() {
    _generation++;
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Kyuto · Trợ lý AI QTJP')),
    body: SafeArea(
      top: false,
      child: !_app.isAuthenticated
          ? SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ApiErrorView(
                error: const ApiException(
                  'Đăng nhập để trò chuyện với Kyuto và xem dữ liệu học của tài khoản.',
                  status: 401,
                ),
                onRetry: () => setState(() {}),
              ),
            )
          : Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 760),
                child: Column(
                  children: [
                    if (_remaining == 0)
                      TextButton(
                        onPressed: () =>
                            Navigator.pushNamed(context, AppRoutes.vip),
                        child: const Text('Xem gói VIP và thanh toán'),
                      ),
                    const Padding(
                      padding: EdgeInsets.fromLTRB(16, 8, 16, 4),
                      child: Text(
                        'Câu trả lời dùng backend QTJP. Hội thoại chỉ giữ trong phiên màn hình này; AI có thể sai.',
                        style: TextStyle(fontSize: 12, color: QTJPColors.muted),
                      ),
                    ),
                    Expanded(
                      child: ListView(
                        controller: _scroll,
                        padding: const EdgeInsets.all(16),
                        children: [
                          if (_messages.isEmpty && !_busy) ...[
                            const Text(
                              'こんにちは！ Bạn muốn Kyuto hỗ trợ điều gì?',
                              style: TextStyle(
                                fontSize: 21,
                                color: QTJPColors.navy,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                for (final question in [
                                  'Giải thích mẫu ～ている',
                                  'Phân tích kết quả JLPT của tôi',
                                  'Tiến độ flashcard của tôi',
                                ])
                                  ActionChip(
                                    label: Text(question),
                                    onPressed: () =>
                                        setState(() => _input.text = question),
                                  ),
                              ],
                            ),
                          ],
                          for (final message in _messages) _bubble(message),
                          if (_pending != null)
                            _bubble(
                              _ChatMessage(AssistantTurn('user', _pending!)),
                            ),
                          if (_busy)
                            const Padding(
                              padding: EdgeInsets.all(16),
                              child: Row(
                                children: [
                                  SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  ),
                                  SizedBox(width: 12),
                                  Expanded(child: Text('Kyuto đang xử lý…')),
                                ],
                              ),
                            ),
                          if (_error != null)
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              child: Text(
                                _error is ApiException ? _error.toString() : 'Chưa nhận được câu trả lời. Câu hỏi vẫn ở ô nhập để bạn thử lại.',
                                key: const ValueKey('assistant-error'),
                                style: const TextStyle(
                                  color: QTJPColors.red,
                                  height: 1.6,
                                ),
                              ),
                            ),
                          if (_fallbackLinks.isNotEmpty) ...[
                            const Text('Bạn vẫn có thể mở học liệu QTJP:'),
                            ..._links(_fallbackLinks),
                          ],
                          if (_fallbackSources.isNotEmpty)
                            _sources(_fallbackSources),
                        ],
                      ),
                    ),
                    if (_remaining != null)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Text(
                          'Lượt tổng hợp AI còn lại theo máy chủ: $_remaining',
                          style: const TextStyle(
                            fontSize: 12,
                            color: QTJPColors.muted,
                          ),
                        ),
                      ),
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Expanded(
                            child: TextField(
                              key: const ValueKey('assistant-input'),
                              controller: _input,
                              enabled: !_busy,
                              minLines: 1,
                              maxLines: 4,
                              maxLength: 1000,
                              textInputAction: TextInputAction.send,
                              onSubmitted: (_) => _send(),
                              decoration: const InputDecoration(
                                labelText: 'Hỏi Kyuto',
                                border: OutlineInputBorder(),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Padding(
                            padding: const EdgeInsets.only(bottom: 22),
                            child: IconButton.filled(
                              key: const ValueKey('assistant-send'),
                              tooltip: 'Gửi câu hỏi',
                              onPressed: _busy ? null : _send,
                              icon: const Icon(Icons.send),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
    ),
  );

  Widget _bubble(_ChatMessage message) {
    final fromUser = message.turn.role == 'user';
    final reply = message.reply;
    return Card(
      color: fromUser ? QTJPColors.softBlue : Colors.white,
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              fromUser ? 'Bạn' : 'Kyuto',
              style: const TextStyle(
                color: QTJPColors.navy,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            SelectableText(
              message.turn.content,
              style: const TextStyle(height: 1.7),
            ),
            if (reply != null && reply.mode != 'VOCAB_LOOKUP') ...[
              ..._links(reply.links),
              if (reply.sources.isNotEmpty) _sources(reply.sources),
            ],
          ],
        ),
      ),
    );
  }

  Widget _sources(List<Map<String, dynamic>> sources) => ExpansionTile(
    title: Text('Nguồn dữ liệu QTJP (${sources.length})'),
    children: [
      for (final source in sources)
        ListTile(
          title: Text(jsonText(source, 'title')),
          subtitle: Text(
            '${jsonText(source, 'type')} · ${jsonText(source, 'excerpt')}',
          ),
          onTap: _sourceAction(source),
        ),
    ],
  );

  List<Widget> _links(List<AssistantLink> links) => [
    for (final link in links)
      if (link.route case final route?)
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: () => _openRoute(route),
            icon: const Icon(Icons.arrow_forward),
            label: Text(link.title),
          ),
        ),
  ];

  VoidCallback? _sourceAction(Map<String, dynamic> source) {
    final route = assistantMobileRoute(jsonText(source, 'path'));
    return route == null ? null : () => _openRoute(route);
  }
}
