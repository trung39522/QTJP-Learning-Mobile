import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/widgets/kyuto_scaffold.dart';

import '../../app/app_controller.dart';
import '../../core/network/api_client.dart';
import '../../core/navigation/app_routes.dart';
import '../../core/widgets/api_error_view.dart';
import '../../core/theme/qtjp_colors.dart';
import '../assistant/kyuto_assistant_host.dart';
import 'models/video_presentation.dart';
import 'widgets/video_card.dart';
import 'widgets/video_rail.dart';
import 'widgets/video_catalog_widgets.dart';
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
  final _scroll = ScrollController();
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
      if (_current(session)) {
        setState(() => _error = error);
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_current(session) && _scroll.hasClients) _scroll.jumpTo(0);
        });
      }
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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_current(session) && _scroll.hasClients) _scroll.jumpTo(0);
    });
    if (video.data['usage'] is Map<String, dynamic>) {
      _usage = jsonObject(video.data['usage']);
    }
  }

  Future<void> _open(int id, bool preset) => _run(
    preset ? 'Đang mở video và chuẩn bị phụ đề…' : 'Đang mở video…',
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
    await _run('Đang phân tích video. Có thể mất vài phút…', (session) async {
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
          'Nội dung phân tích sẽ được tạo lại. Bạn có muốn tiếp tục?',
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
  Future<void> _openVip() async {
    final session = _app.api.sessionVersion;
    await _controls.pause();
    if (!mounted || !_current(session)) return;
    await Navigator.pushNamed(context, AppRoutes.vip);
    if (_current(session)) await _load();
  }

  Widget _usageCard() => VideoUsageCard(
    usage: _usage,
    loading: _busy && _usage == null,
    error: _catalogErrors['Lượt AI'],
    onRetry: _busy ? null : _load,
    onVip: _app.isAuthenticated ? _openVip : null,
  );

  List<Widget> _catalogHeader() => [
    if (_app.isAuthenticated) ...[
      _usageCard(),
      VideoAnalysisCard(
        controller: _url,
        enabled: !_busy,
        onAnalyze: _busy || _uncertain ? null : _analyze,
        working: _busy && _working != 'Đang tải video…' ? _working : null,
      ),
    ] else
      ApiErrorView(
        error: const ApiException(
          'Đăng nhập để mở video học và dùng phụ đề QTJP.',
          status: 401,
        ),
        onRetry: _load,
      ),
    const VideoSectionHeading(
      'Video có sẵn',
      description: 'Học cùng các video được hệ thống cung cấp theo trình độ.',
    ),
    VideoLevelFilters(level: _level, onSelected: _busy ? null : _changeLevel),
    const SizedBox(height: 14),
    if (_busy && !_presetsLoaded) const VideoCardSkeleton(),
    if (_presetsLoaded && _presets.isEmpty)
      const VideoEmptyState('Máy chủ chưa có video mẫu ở cấp độ này.'),
  ];

  List<Map<String, dynamic>> _unique(List<Map<String, dynamic>> items) {
    final ids = <Object?>{};
    return items.where((item) => ids.add(item['id'])).toList();
  }

  Widget _videoCard(Map<String, dynamic> item, bool preset) {
    final metadata = VideoPresentation(item, baseUrl: _app.api.baseUrl);
    return VideoCard(
      key: ValueKey(
        'video-card-${preset ? 'preset' : 'history'}-${item['id']}',
      ),
      video: metadata,
      preset: preset,
      compact: true,
      onWatch: _busy || !_app.isAuthenticated
          ? null
          : preset
          ? metadata.canPreview
                ? () => _previewPreset(item)
                : null
          : () => _open(videoId(item['id']), false),
      onAnalyze: _busy || _uncertain || !_app.isAuthenticated
          ? null
          : () => _open(videoId(item['id']), true),
    );
  }

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
      VideoSurface(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                Text(
                  VideoPresentation(video.data).sourceLabel,
                  style: TextStyle(
                    color: context.qtjp.blue,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                if (VideoPresentation(video.data).level.isNotEmpty)
                  Text(
                    VideoPresentation(video.data).level,
                    style: TextStyle(
                      color: context.qtjp.heading,
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              jsonText(video.data, 'title'),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: context.qtjp.heading,
                fontSize: 22,
                height: 1.3,
                fontWeight: FontWeight.w800,
              ),
            ),
            if (jsonText(video.data, 'description').isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  jsonText(video.data, 'description'),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: context.qtjp.muted,
                    fontSize: 13,
                    height: 1.5,
                  ),
                ),
              ),
          ],
        ),
      ),
      ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: KeyedSubtree(
          key: ValueKey('video-player-$_session-${video.id}'),
          child:
              widget.playerBuilder?.call(
                context,
                video,
                _controls,
                _position,
              ) ??
              LearningVideoPlayer(
                video: video,
                controls: _controls,
                onPosition: _position,
              ),
        ),
      ),
      const SizedBox(height: 12),
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
      const SizedBox(height: 12),
      _usageCard(),
      if (video.subtitles.isNotEmpty) ...[
        const VideoSectionHeading(
          'Phụ đề & luyện nghe',
          description: 'Chọn câu để nghe, xem bản dịch và học trong ngữ cảnh.',
        ),
        SizedBox(
          height: 52,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: video.subtitles.length,
            separatorBuilder: (_, _) => const SizedBox(width: 6),
            itemBuilder: (_, i) => ChoiceChip(
              label: Text('${i + 1}'),
              selected: _selected == i,
              selectedColor: QTJPColors.navy,
              labelStyle: TextStyle(
                color: _selected == i ? Colors.white : QTJPColors.navy,
              ),
              onSelected: _busy ? null : (_) => _seek(i),
            ),
          ),
        ),
      ],
      if (subtitle != null) ...[
        const SizedBox(height: 12),
        VideoSurface(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                jsonText(subtitle, 'japanese'),
                style: TextStyle(
                  color: context.qtjp.heading,
                  fontSize: 21,
                  height: 1.6,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                jsonText(subtitle, 'vietnamese'),
                style: TextStyle(
                  color: context.qtjp.muted,
                  fontSize: 14,
                  height: 1.6,
                ),
              ),
            ],
          ),
        ),
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
                  KyutoAssistantScope.show(
                    context,
                    message: question.length > 1000
                        ? question.substring(0, 1000)
                        : question,
                  );
                },
          icon: const Icon(Icons.auto_awesome),
          label: const Text('Hỏi Kyuto về câu này'),
        ),
        if (explanation != null) ...[
          if (jsonObjects(explanation['points'] ?? []).isEmpty)
            _line('Chưa tìm thấy mẫu ngữ pháp để giải thích cho câu này.'),
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
    _scroll.dispose();
    unawaited(_controls.pause());
    super.dispose();
  }

  List<Widget> _status() => [
    if (_busy) ...[
      const LinearProgressIndicator(minHeight: 2),
      _line(_working ?? 'Đang xử lý…'),
    ],
    if (_error != null)
      VideoSurface(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(
              Icons.info_outline_rounded,
              color: QTJPColors.red,
              size: 20,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                _error is ApiException
                    ? _error.toString()
                    : 'Chưa tải được dữ liệu video. Hãy thử lại.',
                style: const TextStyle(color: QTJPColors.red, height: 1.5),
              ),
            ),
          ],
        ),
      ),
    for (final entry in _catalogErrors.entries.where(
      (entry) => entry.key != 'Lượt AI',
    ))
      _line(
        '${entry.key}: ${entry.value is ApiException ? entry.value : 'Chưa tải được. Hãy thử lại.'}',
      ),
    if (_catalogErrors.keys.any((key) => key != 'Lượt AI'))
      OutlinedButton(
        onPressed: _busy ? null : _load,
        child: const Text('Thử tải lại dữ liệu video'),
      ),
    if (_uncertain)
      OutlinedButton(
        onPressed: _busy
            ? null
            : () async {
                if (mounted) setState(() => _video = null);
                await _load();
              },
        child: const Text('Kiểm tra lịch sử trước khi phân tích lại'),
      ),
  ];

  @override
  Widget build(BuildContext context) {
    final presets = _unique(_presets), history = _unique(_history);
    return PopScope(
      canPop: _video == null,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) unawaited(_closeVideo());
      },
      child: KyutoScaffold(
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
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 760),
              child: CustomScrollView(
                key: const ValueKey('video-scroll'),
                controller: _scroll,
                slivers: [
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                    sliver: SliverToBoxAdapter(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          ..._status(),
                          ...(_video == null ? _catalogHeader() : _learning()),
                        ],
                      ),
                    ),
                  ),
                  if (_video == null) ...[
                    SliverPadding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      sliver: SliverToBoxAdapter(
                        child: presets.isEmpty
                            ? const SizedBox.shrink()
                            : VideoRail(
                                storageKey: 'video-presets-$_level',
                                itemCount: presets.length,
                                itemBuilder: (_, index) =>
                                    _videoCard(presets[index], true),
                              ),
                      ),
                    ),
                    if (_app.isAuthenticated) ...[
                      SliverPadding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        sliver: SliverToBoxAdapter(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              const VideoSectionHeading(
                                'Đã học gần đây',
                                description: 'Lịch sử video của tài khoản, đồng bộ từ hệ thống.',
                              ),
                              if (_busy && !_historyLoaded)
                                const VideoCardSkeleton(),
                              if (_historyLoaded && history.isEmpty)
                                const VideoEmptyState(
                                  'Bạn chưa có video trong lịch sử.',
                                ),
                            ],
                          ),
                        ),
                      ),
                      SliverPadding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        sliver: SliverToBoxAdapter(
                          child: history.isEmpty
                              ? const SizedBox.shrink()
                              : VideoRail(
                                  storageKey: 'video-history-$_session',
                                  itemCount: history.length,
                                  itemBuilder: (_, index) =>
                                      _videoCard(history[index], false),
                                ),
                        ),
                      ),
                    ],
                  ],
                  const SliverToBoxAdapter(child: SizedBox(height: 24)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
