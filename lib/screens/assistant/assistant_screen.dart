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

const _chatPink = Color(0xFFB5356B);
const _chatPale = Color(0xFFFFF3F8);
const _chatBorder = Color(0xFFF0B3CC);

class AssistantScreen extends StatefulWidget {
  const AssistantScreen({
    this.initialMessage,
    this.compact = false,
    this.onClose,
    this.onNavigate,
    super.key,
  });
  final String? initialMessage;
  final bool compact;
  final VoidCallback? onClose;
  final ValueChanged<String>? onNavigate;
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
    if (widget.onNavigate != null) {
      widget.onNavigate!(route);
      return;
    }
    if (route == '/') {
      Navigator.of(context).popUntil((route) => route.isFirst);
    } else {
      Navigator.of(context).pushNamed(route);
    }
  }

  @override
  void didUpdateWidget(covariant AssistantScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialMessage != oldWidget.initialMessage &&
        widget.initialMessage != null &&
        _app.isAuthenticated) {
      _input.text = widget.initialMessage!;
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
  Widget build(BuildContext context) {
    final content = SafeArea(
      top: false,
      bottom: !widget.compact,
      child: !_app.isAuthenticated
          ? SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: widget.compact
                  ? Column(
                      children: [
                        const Text(
                          'Đăng nhập để trò chuyện với Kyuto.',
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),
                        FilledButton(
                          onPressed: () => _openRoute(AppRoutes.login),
                          child: const Text('Đăng nhập'),
                        ),
                        const SizedBox(height: 12),
                        ..._studyShortcuts(),
                      ],
                    )
                  : ApiErrorView(
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
                        onPressed: () => _openRoute(AppRoutes.vip),
                        child: const Text('Xem gói VIP và thanh toán'),
                      ),
                    if (!widget.compact)
                      Padding(
                        padding: EdgeInsets.fromLTRB(16, 8, 16, 4),
                        child: Text(
                          'Kyuto có thể mắc lỗi. Hãy kiểm tra lại thông tin quan trọng.',
                          style: TextStyle(
                            fontSize: 12,
                            color: context.qtjp.muted,
                          ),
                        ),
                      ),
                    Expanded(
                      child: ListView(
                        controller: _scroll,
                        padding: const EdgeInsets.all(16),
                        children: [
                          if (_messages.isEmpty && !_busy) ...[
                            Container(
                              padding: widget.compact
                                  ? const EdgeInsets.all(12)
                                  : EdgeInsets.zero,
                              decoration: widget.compact
                                  ? BoxDecoration(
                                      color:
                                          Theme.of(context).brightness ==
                                              Brightness.dark
                                          ? const Color(0xFF352330)
                                          : _chatPale,
                                      borderRadius: BorderRadius.circular(16),
                                    )
                                  : null,
                              child: Text(
                                'こんにちは！ Bạn muốn Kyuto hỗ trợ điều gì?',
                                style: TextStyle(
                                  fontSize: widget.compact ? 13 : 21,
                                  color:
                                      widget.compact &&
                                          Theme.of(context).brightness !=
                                              Brightness.dark
                                      ? const Color(0xFF67485A)
                                      : context.qtjp.heading,
                                  fontWeight: widget.compact
                                      ? FontWeight.w400
                                      : FontWeight.w800,
                                ),
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
                                    backgroundColor: widget.compact
                                        ? Colors.transparent
                                        : null,
                                    side: widget.compact
                                        ? const BorderSide(color: _chatBorder)
                                        : null,
                                    label: Text(question),
                                    labelStyle: widget.compact
                                        ? const TextStyle(
                                            color: _chatPink,
                                            fontSize: 12,
                                          )
                                        : null,
                                    onPressed: () =>
                                        setState(() => _input.text = question),
                                  ),
                              ],
                            ),
                            if (widget.compact) ..._studyShortcuts(),
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
                          style: TextStyle(
                            fontSize: 12,
                            color: context.qtjp.muted,
                          ),
                        ),
                      ),
                    Padding(
                      padding: EdgeInsets.all(widget.compact ? 10 : 16),
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
                              style: widget.compact
                                  ? const TextStyle(fontSize: 13)
                                  : null,
                              decoration: InputDecoration(
                                labelText: widget.compact ? null : 'Hỏi Kyuto',
                                hintText: widget.compact
                                    ? 'Hỏi nội dung QTJP…'
                                    : null,
                                counterText: '',
                                isDense: widget.compact,
                                contentPadding: widget.compact
                                    ? const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 12,
                                      )
                                    : null,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                enabledBorder: widget.compact
                                    ? OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        borderSide: const BorderSide(
                                          color: _chatBorder,
                                        ),
                                      )
                                    : null,
                                focusedBorder: widget.compact
                                    ? OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        borderSide: const BorderSide(
                                          color: _chatPink,
                                        ),
                                      )
                                    : null,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Padding(
                            padding: EdgeInsets.zero,
                            child: IconButton.filled(
                              style: widget.compact
                                  ? IconButton.styleFrom(
                                      backgroundColor: const Color(0xFFD984AA),
                                      foregroundColor: Colors.white,
                                    )
                                  : null,
                              key: const ValueKey('assistant-send'),
                              tooltip: 'Gửi câu hỏi',
                              onPressed: _busy ? null : _send,
                              icon: const Icon(Icons.send_outlined),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
    if (!widget.compact) {
      return Scaffold(
        appBar: AppBar(title: const Text('Kyuto · Trợ lý AI QTJP')),
        body: content,
      );
    }
    return Column(
      children: [
        Container(
          color: _chatPink,
          padding: const EdgeInsets.only(left: 12, right: 4, top: 4, bottom: 4),
          child: Row(
            children: [
              CircleAvatar(
                radius: 16,
                backgroundColor: Colors.white,
                child: Padding(
                  padding: const EdgeInsets.all(5),
                  child: Image.asset(
                    'assets/mascot/kyuto_avatar.webp',
                    fit: BoxFit.contain,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Kyuto · Trợ lý AI QTJP',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                  ),
                ),
              ),
              IconButton(
                key: const ValueKey('kyuto-chat-close'),
                tooltip: 'Đóng khung chat',
                onPressed: widget.onClose,
                icon: const Icon(Icons.close, size: 20, color: Colors.white),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(child: content),
      ],
    );
  }

  Widget _bubble(_ChatMessage message) {
    final fromUser = message.turn.role == 'user';
    final reply = message.reply;
    return Card(
      color: widget.compact
          ? (Theme.of(context).brightness == Brightness.dark
                ? const Color(0xFF352330)
                : (fromUser ? const Color(0xFFFCE5EF) : _chatPale))
          : (fromUser ? context.qtjp.soft : context.qtjp.surface),
      elevation: widget.compact ? 0 : null,
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: EdgeInsets.all(widget.compact ? 12 : 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              fromUser ? 'Bạn' : 'Kyuto',
              style: TextStyle(
                color: widget.compact ? _chatPink : context.qtjp.heading,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            SelectableText(
              message.turn.content,
              style: TextStyle(
                height: 1.6,
                fontSize: widget.compact ? 13 : null,
                color:
                    widget.compact &&
                        Theme.of(context).brightness != Brightness.dark
                    ? const Color(0xFF67485A)
                    : null,
              ),
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

  List<Widget> _studyShortcuts() => [
    Wrap(
      spacing: 4,
      children: [
        for (final item in [
          ('Tra từ vựng', '/learn/dictionary'),
          ('Giải thích ngữ pháp', '/learn/grammar'),
          ('Luyện đề JLPT', '/learn/exam'),
        ])
          TextButton(
            onPressed: () => _openRoute(item.$2),
            child: Text(item.$1, style: const TextStyle(fontSize: 12)),
          ),
      ],
    ),
  ];

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
