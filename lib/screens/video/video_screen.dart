import 'dart:async';

import 'package:flutter/material.dart';

import '../../app/app_controller.dart';
import '../../core/network/api_client.dart';
import '../../core/navigation/app_routes.dart';
import '../../core/widgets/api_error_view.dart';
import '../assistant/assistant_screen.dart';
import '../home/widgets/jlpt_level_selector.dart';
import 'learning_video_player.dart';
import 'video_repository.dart';

typedef LearningPlayerBuilder = Widget Function(
  BuildContext context,
  LearningVideo video,
  VideoControls controls,
  ValueChanged<int> onPosition,
);

class VideoScreen extends StatefulWidget {
  const VideoScreen({this.initialLevel = 'ALL', this.playerBuilder, super.key});
  final String initialLevel;
  final LearningPlayerBuilder? playerBuilder;
  @override
  State<VideoScreen> createState() => _VideoScreenState();
}

class _VideoScreenState extends State<VideoScreen> {
  late AppController _app;
  late VideoRepository _repository;
  late String _level = widget.initialLevel;
  final _url = TextEditingController();
  final _controls = VideoControls();
  int? _session;
  List<Map<String, dynamic>> _presets = [], _history = [];
  Map<String, dynamic>? _usage;
  final _grammar = <int, Map<String, dynamic>>{};
  LearningVideo? _video;
  int _selected = 0;
  int? _repeatEnd;
  int? _seekTarget;
  DateTime? _seekUntil;
  bool _busy = false,
      _presetsLoaded = false,
      _historyLoaded = false,
      _uncertain = false,
      _preview = false;
  final _catalogErrors = <String, Object>{};
  String? _working;
  Object? _error;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _app = AppScope.of(context);
    _repository = VideoRepository(_app.api);
    if (_session != _app.api.sessionVersion) {
      _session = _app.api.sessionVersion;
      _video = null;
      _presets = [];
      _history = [];
      _usage = null;
      _grammar.clear();
      _url.clear();
      _busy = false;
      _presetsLoaded = false;
      _historyLoaded = false;
      _preview = false;
      _seekTarget = null;
      _seekUntil = null;
      _repeatEnd = null;
      _catalogErrors.clear();
      _uncertain = false;
      _error = null;
      unawaited(_load());
    }
  }

  bool _current(int version) => mounted && _app.api.sessionVersion == version;
  Future<void> _run(
    String working,
    Future<void> Function(int session) action,
  ) async {
    if (_busy) return;
    final session = _app.api.sessionVersion;
    setState(() {
      _busy = true;
      _working = working;
      _error = null;
    });
    try {
      await action(session);
    } catch (error) {
      if (_current(session)) setState(() => _error = error);
    } finally {
      if (_current(session)) {
        setState(() {
          _busy = false;
          _working = null;
        });
      }
    }
  }

  Future<void> _load() => _run('Đang tải video…', (session) async {
    if (!_app.isAuthenticated) return;
    _catalogErrors.clear();
    // A failed quota/history request must not hide successfully loaded presets.
    Future<void> read(String label, Future<void> Function() fetch) async {
      try {
        await fetch();
      } catch (error) {
        if (_current(session)) _catalogErrors[label] = error;
      }
    }

    await Future.wait([
      read('Video có sẵn', () async {
        final presets = await _repository.presets(_level);
        if (!_current(session)) return;
        _presets = presets;
        _presetsLoaded = true;
      }),
      read('Lịch sử', () async {
        final history = await _repository.history();
        if (!_current(session)) return;
        _history = history;
        _historyLoaded = true;
        _uncertain = false;
      }),
      read('Lượt AI', () async {
        final usage = await _repository.usage();
        if (_current(session)) _usage = usage;
      }),
    ]);
  });
  void _accept(LearningVideo video, int session) {
    if (!_current(session)) return;
    _video = video;
    _preview = false;
    _selected = 0;
    _repeatEnd = null;
    _seekTarget = null;
    _seekUntil = null;
    _grammar.clear();
    if (video.data['usage'] is Map<String, dynamic>) {
      _usage = jsonObject(video.data['usage']);
    }
  }

  Future<void> _open(int id, bool preset) => _run(
    preset
        ? 'Đang mở video mẫu; backend có thể cần tạo phụ đề…'
        : 'Đang mở video…',
    (session) async {
      try {
        _accept(await _repository.open(id, preset: preset), session);
      } on ApiException catch (error) {
        if (_current(session) && preset && error.code == 'REQUEST_TIMEOUT') {
          _uncertain = true;
        }
        rethrow;
      }
    },
  );
  void _previewPreset(Map<String, dynamic> preset) {
    if (_busy || !_app.isAuthenticated) return;
    try {
      // The metadata is from the authenticated catalog, not invented subtitles.
      final video = LearningVideo.fromJson({...preset, 'subtitles': []});
      setState(() {
        _accept(video, _app.api.sessionVersion);
        _preview = true;
        _error = null;
      });
    } catch (error) {
      setState(() => _error = error);
    }
  }

  Future<void> _closeVideo() async {
    if (_busy) return;
    final session = _app.api.sessionVersion;
    await _controls.pause();
    if (!_current(session)) return;
    setState(() {
      _video = null;
      _repeatEnd = null;
      _seekTarget = null;
      _seekUntil = null;
    });
    await _load();
  }

  Future<void> _analyze() async {
    if (_uncertain || !_app.isAuthenticated) return;
    try {
      validateVideoUrl(_url.text);
    } catch (error) {
      setState(() => _error = error);
      return;
    }
    await _run('Backend đang phân tích video. Có thể mất vài phút…', (
      session,
    ) async {
      try {
        _accept(await _repository.analyze(_url.text), session);
      } on ApiException catch (error) {
        if (_current(session) && error.code == 'REQUEST_TIMEOUT') {
          _uncertain = true;
        }
        rethrow;
      }
    });
  }

  Future<void> _reanalyze() async {
    final video = _video;
    if (video == null || _busy || _uncertain) return;
    final session = _app.api.sessionVersion;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Phân tích lại video?'),
        content: const Text(
          'Backend sẽ tạo lại nội dung phân tích. Giới hạn lượt và quyền truy cập do máy chủ kiểm tra.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Phân tích lại'),
          ),
        ],
      ),
    );
    if (confirmed != true || !_current(session)) return;
    await _run('Đang phân tích lại video…', (version) async {
      try {
        _accept(await _repository.reanalyze(video.id), version);
      } on ApiException catch (error) {
        if (_current(version) && error.code == 'REQUEST_TIMEOUT') {
          _uncertain = true;
        }
        rethrow;
      }
    });
  }

  Map<String, dynamic>? get _subtitle =>
      _video == null || _video!.subtitles.isEmpty
      ? null
      : _video!.subtitles[_selected];
  Future<void> _explain() async {
    final subtitle = _subtitle;
    if (subtitle == null) return;
    final id = videoId(subtitle['id']);
    if (_grammar.containsKey(id)) return;
    await _run('Đang giải thích ngữ pháp của câu đã chọn…', (session) async {
      final grammar = await _repository.grammar(id);
      if (_current(session)) _grammar[id] = grammar;
    });
  }

  void _position(int ms) {
    if (!mounted || _video == null) return;
    if (_seekTarget != null && _seekUntil != null) {
      if (DateTime.now().isBefore(_seekUntil!) &&
          (ms - _seekTarget!).abs() > 700) {
        return;
      }
      _seekTarget = null;
      _seekUntil = null;
    }
    if (_repeatEnd != null && ms >= _repeatEnd!) {
      _repeatEnd = null;
      unawaited(_controls.pause());
    }
    final index = _video!.subtitleAt(ms);
    if (index >= 0 && index != _selected) setState(() => _selected = index);
  }

  Future<void> _seek(int index, {bool sentence = false}) async {
    final session = _app.api.sessionVersion;
    final video = _video!;
    final subtitle = _video!.subtitles[index];
    setState(() {
      _selected = index;
      _repeatEnd = sentence ? (subtitle['endMs'] as num).toInt() : null;
      _seekTarget = (subtitle['startMs'] as num).toInt();
      _seekUntil = DateTime.now().add(const Duration(milliseconds: 1800));
    });
    await _controls.seek((subtitle['startMs'] as num).toInt());
    if (!_current(session) || _video != video) return;
    await _controls.play();
  }

  Widget _line(String text) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: Text(text, style: const TextStyle(height: 1.7)),
  );
  List<Widget> _catalog() => [
    ChoiceChip(
      label: const Text('Tất cả'),
      selected: _level == 'ALL',
      onSelected: _busy ? null : (_) => _changeLevel('ALL'),
    ),
    JlptLevelSelector(selectedLevel: _level, onSelected: _changeLevel),
    _line(
      'Video mẫu có thể cần tạo phụ đề khi bạn bấm mở. Phân tích link riêng chỉ chạy khi bấm Phân tích video.',
    ),
    if (_app.isAuthenticated) ...[
      TextField(
        key: const ValueKey('video-url'),
        controller: _url,
        enabled: !_busy,
        decoration: const InputDecoration(
          labelText: 'Liên kết YouTube hoặc TikTok',
          border: OutlineInputBorder(),
        ),
        autocorrect: false,
      ),
      FilledButton(
        key: const ValueKey('video-analyze'),
        onPressed: _busy || _uncertain ? null : _analyze,
        child: const Text('Phân tích video bằng AI'),
      ),
    ] else
      ApiErrorView(
        error: const ApiException(
          'Đăng nhập để mở video học và dùng phụ đề QTJP.',
          status: 401,
        ),
        onRetry: _load,
      ),
    _line(
      _level == 'ALL' ? 'Video có sẵn · Tất cả cấp độ' : 'Video mẫu $_level',
    ),
    if (_presetsLoaded && _presets.isEmpty)
      _line('Máy chủ chưa có video mẫu ở cấp độ này.'),
    for (final preset in _presets)
      Card(
        child: Column(
          children: [
            ListTile(
              key: ValueKey('video-preset-${preset['id']}'),
              title: Text(jsonText(preset, 'title')),
              subtitle: Text('${preset['level']} · ${preset['platform']}'),
              onTap: _busy || _uncertain || !_app.isAuthenticated
                  ? null
                  : () => _open(videoId(preset['id']), true),
            ),
            if (jsonText(preset, 'videoId').isNotEmpty)
              TextButton.icon(
                onPressed: _busy ? null : () => _previewPreset(preset),
                icon: const Icon(Icons.play_circle_outline),
                label: const Text('Xem video trước, chưa gọi AI'),
              ),
          ],
        ),
      ),
    if (_app.isAuthenticated) ...[
      _line('Lịch sử video của bạn'),
      if (_historyLoaded && _history.isEmpty)
        _line('Bạn chưa có video trong lịch sử.'),
      for (final item in _history)
        Card(
          child: ListTile(
            key: ValueKey('video-history-${item['id']}'),
            title: Text(jsonText(item, 'title')),
            onTap: _busy ? null : () => _open(videoId(item['id']), false),
          ),
        ),
    ],
  ];
  void _changeLevel(String level) {
    if (_busy || level == _level) return;
    setState(() {
      _level = level;
      _presets = [];
      _presetsLoaded = false;
    });
    unawaited(_load());
  }

  List<Widget> _learning() {
    final video = _video!;
    final subtitle = _subtitle;
    final explanation = subtitle == null ? null : _grammar[subtitle['id']];
    return [
      Text(
        jsonText(video.data, 'title'),
        style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
      ),
      KeyedSubtree(
        key: ValueKey('video-player-$_session-${video.id}'),
        child:
            widget.playerBuilder?.call(context, video, _controls, _position) ??
            LearningVideoPlayer(
              video: video,
              controls: _controls,
              onPosition: _position,
            ),
      ),
      OutlinedButton(
        onPressed: _busy ? null : _closeVideo,
        child: const Text('Về danh sách video'),
      ),
      if (_preview) ...[
        _line(
          'Đang xem video gốc. Bấm bên dưới để tải phụ đề, bản dịch và từ vựng từ AI.',
        ),
        FilledButton.icon(
          key: const ValueKey('video-load-ai'),
          onPressed: _busy || _uncertain ? null : () => _open(video.id, true),
          icon: const Icon(Icons.auto_awesome),
          label: const Text('Tải phụ đề và phân tích AI'),
        ),
      ],
      if (!_preview && video.subtitles.isEmpty)
        _line(
          'Máy chủ chưa trả phụ đề cho video này. Bạn vẫn có thể xem video gốc.',
        ),
      Wrap(
        spacing: 6,
        children: [
          for (var i = 0; i < video.subtitles.length; i++)
            ChoiceChip(
              label: Text('${i + 1}'),
              selected: _selected == i,
              onSelected: _busy ? null : (_) => _seek(i),
            ),
        ],
      ),
      if (subtitle != null) ...[
        _line(jsonText(subtitle, 'japanese')),
        _line(jsonText(subtitle, 'vietnamese')),
        OutlinedButton(
          key: const ValueKey('video-repeat'),
          onPressed: _busy ? null : () => _seek(_selected, sentence: true),
          child: const Text('Nghe lại câu đã chọn'),
        ),
        _line('Từ vựng trong câu'),
        for (final word in jsonObjects(subtitle['words'] ?? []))
          ListTile(
            title: Text('${word['text'] ?? ''} · ${word['reading'] ?? ''}'),
            subtitle: Text(jsonText(word, 'meaning')),
          ),
        FilledButton(
          key: const ValueKey('video-grammar'),
          onPressed: _busy || explanation != null ? null : _explain,
          child: const Text('Giải thích ngữ pháp câu này'),
        ),
        OutlinedButton.icon(
          key: const ValueKey('video-ask-ai'),
          onPressed: _busy
              ? null
              : () async {
                  final session = _app.api.sessionVersion;
                  await _controls.pause();
                  if (!_current(session)) return;
                  final question =
                      'Giải thích câu tiếng Nhật trong video: ${jsonText(subtitle, 'japanese')}';
                  if (!mounted) return;
                  await Navigator.push(
                    context,
                    MaterialPageRoute<void>(
                      builder: (_) => AssistantScreen(
                        initialMessage: question.length > 1000
                            ? question.substring(0, 1000)
                            : question,
                      ),
                    ),
                  );
                },
          icon: const Icon(Icons.auto_awesome),
          label: const Text('Hỏi Kyuto về câu này'),
        ),
        if (explanation != null) ...[
          if (jsonObjects(explanation['points'] ?? []).isEmpty)
            _line(
              'Backend chưa tìm thấy mẫu ngữ pháp cần giải thích cho câu này.',
            ),
          for (final point in jsonObjects(explanation['points'] ?? []))
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _line(
                      '${point['pattern'] ?? ''} · ${point['level'] ?? ''}',
                    ),
                    for (final structure in point['structure'] as List? ?? [])
                      _line('$structure'),
                    _line(jsonText(point, 'usage')),
                    _line(jsonText(point, 'contextNote')),
                    for (final example in jsonObjects(
                      point['examples'] ?? [],
                    )) ...[
                      _line(
                        jsonObjects(example['segments'] ?? [])
                            .map((s) => jsonText(s, 'text'))
                            .join(),
                      ),
                      _line(jsonText(example, 'translation')),
                    ],
                  ],
                ),
              ),
            ),
        ],
      ],
      if (jsonText(_app.user ?? {}, 'role').toUpperCase() == 'ADMIN')
        OutlinedButton(
          onPressed: _busy || _uncertain ? null : _reanalyze,
          child: const Text('Phân tích lại video'),
        ),
    ];
  }

  @override
  void dispose() {
    _url.dispose();
    unawaited(_controls.pause());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: _video == null,
    onPopInvokedWithResult: (didPop, result) {
      if (!didPop) unawaited(_closeVideo());
    },
    child: Scaffold(
      appBar: AppBar(
        title: const Text('Học qua video'),
        actions: [
          IconButton(
            tooltip: 'Tải lại danh sách và lượt dùng',
            onPressed: _busy ? null : _load,
            icon: const Icon(Icons.refresh),
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
                  if (_busy) ...[
                    const LinearProgressIndicator(),
                    _line(_working ?? 'Đang xử lý…'),
                  ],
                  if (_error != null)
                    _line(
                      _error is ApiException
                          ? _error.toString()
                          : 'Chưa tải được dữ liệu video. Hãy thử lại.',
                    ),
                  for (final entry in _catalogErrors.entries)
                    _line(
                      '${entry.key}: ${entry.value is ApiException ? entry.value : 'Chưa tải được. Hãy thử lại.'}',
                    ),
                  if (_catalogErrors.isNotEmpty)
                    OutlinedButton(
                      onPressed: _busy ? null : _load,
                      child: const Text('Thử tải lại dữ liệu video'),
                    ),
                  if (_usage != null)
                    _line(
                      _usage!['dailyLimit'] == -1 && _usage!['remaining'] == -1
                          ? 'Theo máy chủ: không giới hạn lượt phân tích · Gói ${_usage!['membership']}'
                          : 'Theo máy chủ: ${_usage!['remaining']} lượt phân tích còn lại · Gói ${_usage!['membership']}',
                    ),
                  if (_app.isAuthenticated)
                    TextButton(
                      onPressed: () async {
                        final session = _app.api.sessionVersion;
                        await Navigator.pushNamed(context, AppRoutes.vip);
                        if (_current(session)) await _load();
                      },
                      child: const Text('Xem gói VIP và thanh toán'),
                    ),
                  if (_uncertain)
                    OutlinedButton(
                      onPressed: _busy
                          ? null
                          : () async {
                              if (mounted) setState(() => _video = null);
                              await _load();
                            },
                      child: const Text(
                        'Kiểm tra lịch sử trước khi phân tích lại',
                      ),
                    ),
                  ...(_video == null ? _catalog() : _learning()),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
