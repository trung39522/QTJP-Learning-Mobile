import 'dart:async';

import 'package:flutter/material.dart';

import '../assistant/kyuto_assistant_host.dart';

import '../../core/widgets/kyuto_scaffold.dart';

import '../../app/app_controller.dart';
import '../../core/network/api_client.dart';
import '../../core/theme/qtjp_colors.dart';
import '../../core/widgets/qtjp_feature_intro.dart';
import '../../core/widgets/api_error_view.dart';
import '../home/widgets/jlpt_level_selector.dart';
import 'exam_listening_player.dart';
import 'exam_question_view.dart';
import 'exam_repository.dart';
import 'widgets/exam_presentation.dart';
import 'widgets/exam_question_navigator.dart';
import 'widgets/exam_result_dashboard.dart';

enum _ExamPage { catalog, detail, taking, result }

class ExamScreen extends StatefulWidget {
  const ExamScreen({
    required this.initialLevel,
    this.embedded = false,
    this.onLevelChanged,
    this.onTakingChanged,
    this.audioFactory,
    this.now,
    super.key,
  });
  final String initialLevel;
  final bool embedded;
  final ValueChanged<String>? onLevelChanged;
  final ValueChanged<bool>? onTakingChanged;
  final ExamAudio Function()? audioFactory;
  final DateTime Function()? now;
  @override
  State<ExamScreen> createState() => _ExamScreenState();
}

class _ExamScreenState extends State<ExamScreen> with WidgetsBindingObserver {
  late final Timer _timer;
  late AppController _app;
  late ExamRepository _repository;
  late String _level = widget.initialLevel;
  int? _session;
  _ExamPage _page = _ExamPage.catalog;
  List<Map<String, dynamic>> _exams = [], _history = [];
  Map<String, dynamic>? _detail, _result, _document;
  ExamAttempt? _attempt;
  String? _documentUrl, _handledDeadline;
  Object? _error, _documentError;
  bool _busy = false, _loaded = false, _confirming = false;
  bool _mustSync = false;
  int _index = 0;
  bool _takingReported = false;
  KyutoAssistantController? _assistant;
  final _scroll = ScrollController();
  final _clock = ValueNotifier<int>(0);
  final _scaffold = GlobalKey<ScaffoldState>();
  final _questionAnchor = GlobalKey();
  double _questionDrag = 0;

  void _selectQuestion(int index) {
    final count = _attempt?.questions.length ?? 0;
    if (_busy || index < 0 || index >= count || index == _index) return;
    FocusScope.of(context).unfocus();
    setState(() => _index = index);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final anchor = _questionAnchor.currentContext;
      if (mounted && anchor != null) {
        unawaited(
          Scrollable.ensureVisible(
            anchor,
            alignment: 0,
            duration: const Duration(milliseconds: 180),
          ),
        );
      }
    });
  }

  void _scrollToTop() => WidgetsBinding.instance.addPostFrameCallback((_) {
    if (mounted && _scroll.hasClients) _scroll.jumpTo(0);
  });
  DateTime get _now => widget.now?.call() ?? DateTime.now();
  void _reportTaking(bool value) {
    if (_takingReported == value) return;
    _takingReported = value;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) widget.onTakingChanged?.call(value);
    });
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted || _attempt == null || !_app.isAuthenticated) return;
      _clock.value++;
      final attempt = _attempt!;
      if (!_busy &&
          attempt.deadline != null &&
          !_now.isBefore(attempt.deadline!) &&
          _handledDeadline != attempt.deadlineKey) {
        _handledDeadline = attempt.deadlineKey;
        unawaited(_refreshAttempt());
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _app = AppScope.of(context);
    _assistant = KyutoAssistantScope.maybeOf(context);
    _repository = ExamRepository(_app.api);
    if (_session != _app.api.sessionVersion) {
      _session = _app.api.sessionVersion;
      _page = _ExamPage.catalog;
      _exams = [];
      _history = [];
      _detail = null;
      _result = null;
      _attempt = null;
      _document = null;
      _documentUrl = null;
      _documentError = null;
      _error = null;
      _busy = false;
      _loaded = false;
      _mustSync = false;
      _reportTaking(false);
      if (_app.isAuthenticated) unawaited(_loadCatalog());
    }
  }

  @override
  void didUpdateWidget(covariant ExamScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialLevel != widget.initialLevel &&
        _page == _ExamPage.catalog) {
      _level = widget.initialLevel;
      if (_app.isAuthenticated && !_busy) unawaited(_loadCatalog());
    }
  }

  bool _current(int session) => mounted && _app.api.sessionVersion == session;
  Future<void> _run(Future<void> Function(int session) action) async {
    if (_busy || !_app.isAuthenticated) return;
    final session = _app.api.sessionVersion;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await action(session);
    } catch (error) {
      if (_current(session)) setState(() => _error = error);
    } finally {
      if (_current(session)) setState(() => _busy = false);
    }
  }

  Future<void> _loadCatalog() => _run((session) async {
    final responses = await Future.wait([
      _repository.exams(_level),
      _repository.history(),
    ]);
    if (!_current(session)) return;
    _exams = responses[0];
    _history = responses[1];
    _loaded = true;
    _page = _ExamPage.catalog;
  });

  Future<void> _loadDocument(
    String url,
    int session, {
    bool force = false,
  }) async {
    if (!_current(session) ||
        (!force && url == _documentUrl && _document != null)) {
      return;
    }
    _documentUrl = url;
    _document = null;
    _documentError = null;
    if (url.isEmpty) return;
    try {
      final document = await _repository.document(url);
      if (_current(session)) _document = document;
    } catch (error) {
      if (_current(session)) _documentError = error;
    }
  }

  Future<void> _openDetail(int id) => _run((session) async {
    final detail = await _repository.detail(id);
    if (!_current(session)) return;
    final exam = jsonObject(detail['exam']);
    examId(exam['id']);
    jsonObjects(exam['sections'] ?? []);
    _detail = detail;
    _page = _ExamPage.detail;
    _scrollToTop();
    _reportTaking(true);
    await _loadDocument(jsonText(exam, 'examJsonUrl'), session);
  });

  Future<void> _acceptAttempt(ExamAttempt attempt, int session) async {
    if (!_current(session)) return;
    final phaseChanged =
        _attempt?.id != attempt.id ||
        _attempt?.section?['sectionId'] != attempt.section?['sectionId'] ||
        (_attempt?.breakState != null) != (attempt.breakState != null) ||
        _page != _ExamPage.taking;
    if (phaseChanged || attempt.submitted) _scrollToTop();
    if (attempt.submitted) {
      _reportTaking(true);
      _attempt = null;
      _page = _ExamPage.result;
      _result = null;
      setState(() {});
      final result = await _repository.result(attempt.id);
      if (!_current(session)) return;
      _result = result;
      await _loadDocument(jsonText(result, 'examJsonUrl'), session);
    } else {
      final changed =
          _attempt?.section?['sectionId'] != attempt.section?['sectionId'];
      _attempt = attempt;
      _mustSync = false;
      _page = _ExamPage.taking;
      _reportTaking(true);
      if (changed || _index >= attempt.questions.length) _index = 0;
      setState(() {});
      await _loadDocument(jsonText(attempt.data, 'examJsonUrl'), session);
    }
  }

  Future<void> _resume(int id) => _run(
    (session) async => _acceptAttempt(await _repository.attempt(id), session),
  );
  Future<void> _refreshAttempt() async {
    final attempt = _attempt;
    if (attempt != null) await _resume(attempt.id);
  }

  Future<void> _openResult(int id) => _run((session) async {
    final result = await _repository.result(id);
    if (!_current(session)) return;
    _result = result;
    _attempt = null;
    _page = _ExamPage.result;
    _reportTaking(true);
    await _loadDocument(jsonText(result, 'examJsonUrl'), session);
  });

  Future<void> _start(Map<String, dynamic> exam) => _run((session) async {
    // A lost POST response may already have created the attempt. Force a fresh
    // catalogue read before another explicit start to discover server progress.
    _mustSync = true;
    final attempt = await _repository.start(examId(exam['id']));
    await _acceptAttempt(attempt, session);
  });

  Future<void> _save(
    Map<String, dynamic> question, {
    int? option,
    bool? marked,
  }) async {
    final attempt = _attempt;
    if (attempt == null || _mustSync) return;
    await _run((session) async {
      _mustSync = true;
      final answer = marked == null
          ? await _repository.answer(
              attempt.id,
              examId(question['answerKeyId']),
              option,
            )
          : await _repository.mark(
              attempt.id,
              examId(question['answerKeyId']),
              marked,
            );
      if (!_current(session)) return;
      if (answer['answerKeyId'] != question['answerKeyId']) {
        throw const ApiException(
          'Máy chủ trả đáp án của câu khác. Hãy tải lại lượt thi.',
        );
      }
      // Only acknowledged server state is rendered; failed saves keep the card.
      question['selectedOption'] = answer['selectedOption'];
      question['markedForReview'] = answer['markedForReview'] == true;
      _mustSync = false;
    });
  }

  Future<bool> _confirm(String title, String message) async {
    if (_confirming || _busy) return false;
    _confirming = true;
    final session = _app.api.sessionVersion;
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Quay lại'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Xác nhận'),
          ),
        ],
      ),
    );
    _confirming = false;
    return result == true && _current(session);
  }

  Future<void> _complete() async {
    final attempt = _attempt;
    if (attempt == null || _mustSync) return;
    final answered = attempt.questions
        .where((q) => q['selectedOption'] != null)
        .length;
    final yes = await _confirm(
      'Kết thúc phần thi?',
      'Đã lưu $answered/${attempt.questions.length} câu. Khi kết thúc, phần này sẽ bị khóa. Phần cuối sẽ nộp toàn bộ bài thi.',
    );
    if (!yes || _attempt?.deadlineKey != attempt.deadlineKey) return;
    await _run((session) async {
      _mustSync = true;
      await _acceptAttempt(await _repository.complete(attempt.id), session);
    });
  }

  Future<void> _next() async {
    final attempt = _attempt;
    if (attempt == null || _mustSync) return;
    await _run((session) async {
      _mustSync = true;
      await _acceptAttempt(await _repository.next(attempt.id), session);
    });
  }

  Future<void> _back() async {
    if (_busy) return;
    if (_page == _ExamPage.taking &&
        !await _confirm(
          'Rời phòng thi?',
          'Các đáp án đã lưu vẫn nằm trên máy chủ. Đồng hồ thi tiếp tục chạy khi bạn rời ứng dụng.',
        )) {
      return;
    }
    if (!mounted) return;
    if (_page == _ExamPage.catalog) {
      Navigator.of(context).maybePop();
      return;
    }
    setState(() {
      _attempt = null;
      _page = _ExamPage.catalog;
      _mustSync = false;
    });
    _reportTaking(false);
    await _loadCatalog();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _attempt != null && !_busy) {
      unawaited(_refreshAttempt());
    }
  }

  @override
  void dispose() {
    _assistant?.setExamActive(this, false);
    WidgetsBinding.instance.removeObserver(this);
    _timer.cancel();
    _scroll.dispose();
    _clock.dispose();
    super.dispose();
  }

  String _time(DateTime? deadline) {
    if (deadline == null) return 'Không giới hạn';
    final seconds = (deadline.difference(_now).inMilliseconds / 1000)
        .ceil()
        .clamp(0, 999999);
    return '${(seconds ~/ 60).toString().padLeft(2, '0')}:${(seconds % 60).toString().padLeft(2, '0')}';
  }

  Widget _title(String text) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 12),
    child: Text(
      text,
      style: const TextStyle(fontSize: 23, fontWeight: FontWeight.w800),
    ),
  );
  Widget _line(String text) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Text(text, style: const TextStyle(height: 1.6)),
  );

  List<Widget> _catalog() => [
    const QTJPFeatureIntro(QTJPFeature.exam),
    Text(
      'Cấp độ đang chọn: $_level',
      key: const ValueKey('feature-selected-level'),
    ),
    JlptLevelSelector(
      selectedLevel: _level,
      onSelected: (level) {
        if (_busy || level == _level) return;
        setState(() {
          _level = level;
          _loaded = false;
        });
        widget.onLevelChanged?.call(level);
        if (_app.isAuthenticated) unawaited(_loadCatalog());
      },
    ),
    if (_loaded && _exams.isEmpty)
      _line('Máy chủ chưa có đề $_level đã xuất bản.'),
    if (_loaded)
      Padding(
        padding: const EdgeInsets.only(top: 16),
        child: Text(
          '${_exams.length} đề thi · $_level',
          style: TextStyle(
            color: context.qtjp.heading,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    for (final exam in _exams)
      ExamCatalogCard(
        exam: exam,
        onTap: _busy ? null : () => _openDetail(examId(exam['id'])),
      ),
    _title('Lịch sử làm bài'),
    if (_loaded && !_history.any((h) => h['level'] == _level))
      _line('Chưa có lượt thi $_level.'),
    for (final item in _history.where((h) => h['level'] == _level))
      Card(
        child: ListTile(
          key: ValueKey('exam-history-${item['attemptId']}'),
          title: Text(jsonText(item, 'title')),
          subtitle: Text(
            item['status'] == 'SUBMITTED'
                ? '${item['correctCount']}/${item['totalQuestions']} câu đúng · Điểm luyện tập: ${item['practiceScore']}/180'
                : 'Đang làm · ${item['answeredQuestions']}/${item['totalQuestions']} câu đã lưu',
          ),
          trailing: Text(
            item['status'] == 'SUBMITTED' ? 'Kết quả' : 'Tiếp tục',
          ),
          onTap: _busy
              ? null
              : () => item['status'] == 'SUBMITTED'
                    ? _openResult(examId(item['attemptId']))
                    : _resume(examId(item['attemptId'])),
        ),
      ),
  ];

  List<Widget> _detailView() {
    final detail = _detail!;
    final exam = jsonObject(detail['exam']);
    final progress = exam['progress'] == null
        ? null
        : jsonObject(exam['progress']);
    return [
      _title(jsonText(exam, 'title')),
      _line(jsonText(detail, 'description')),
      Card(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.rule_rounded, color: context.qtjp.blue),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Trước khi bắt đầu',
                      style: TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ),
                ],
              ),
              for (final rule in detail['rules'] as List? ?? [])
                _line('• $rule'),
            ],
          ),
        ),
      ),
      _title('Cấu trúc đề thi'),
      for (final (index, section) in jsonObjects(
        exam['sections'] ?? [],
      ).indexed)
        ExamSectionCard(section: section, index: index + 1),
      const SizedBox(height: 12),
      if (exam['structuredReady'] != true)
        _line('Đề chưa có đủ nội dung số hóa để làm bài trên ứng dụng.'),
      if (_mustSync)
        _line(
          'Chưa xác nhận được lần bắt đầu trước. Tải lại danh sách để kiểm tra lượt đang làm trước khi bắt đầu lại.',
        ),
      FilledButton(
        key: const ValueKey('exam-start'),
        onPressed:
            _busy ||
                _mustSync ||
                exam['structuredReady'] != true ||
                (_documentUrl?.isNotEmpty == true && _document == null)
            ? null
            : () => progress == null
                  ? _start(exam)
                  : _resume(examId(progress['attemptId'])),
        child: Text(progress == null ? 'Bắt đầu thi' : 'Tiếp tục bài đang làm'),
      ),
      if (_mustSync)
        OutlinedButton(
          onPressed: _busy
              ? null
              : () async {
                  await _loadCatalog();
                  if (mounted && _error == null) {
                    setState(() => _mustSync = false);
                  }
                },
          child: const Text('Kiểm tra lượt đang làm'),
        ),
    ];
  }

  List<Widget> _taking() {
    final attempt = _attempt!;
    final section = attempt.section;
    if (section == null) {
      return [
        ValueListenableBuilder(
          valueListenable: _clock,
          builder: (context, _, _) => ExamBreakCard(
            state: attempt.breakState!,
            remaining: _time(attempt.deadline),
            onNext: _busy || _mustSync ? null : _next,
          ),
        ),
      ];
    }
    final questions = attempt.questions;
    final expired =
        attempt.deadline != null && !_now.isBefore(attempt.deadline!);
    final enabled = !_busy && !_mustSync && !expired;
    final question = questions.isEmpty ? null : questions[_index];
    return [
      _title(jsonText(attempt.data, 'title')),
      Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: context.qtjp.soft,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 12,
          runSpacing: 10,
          children: [
            Text(
              jsonText(section, 'name'),
              style: TextStyle(
                color: context.qtjp.heading,
                fontWeight: FontWeight.w800,
              ),
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.timer_outlined,
                  size: 20,
                  color: expired ? QTJPColors.red : context.qtjp.blue,
                ),
                const SizedBox(width: 8),
                ValueListenableBuilder(
                  valueListenable: _clock,
                  builder: (context, _, _) => Text(
                    _time(attempt.deadline),
                    style: TextStyle(
                      color: expired ? QTJPColors.red : context.qtjp.heading,
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      _line(
        'Đã lưu ${questions.where((q) => q['selectedOption'] != null).length}/${questions.length} câu của phần này.',
      ),
      if (section['audioUrl'] is String &&
          (section['audioUrl'] as String).isNotEmpty &&
          !expired)
        _listening(section),
      if (expired)
        _line(
          'Đã hết giờ trên đồng hồ thiết bị. Đang đồng bộ trạng thái phần thi với máy chủ; bạn cũng có thể bấm tải lại.',
        ),
      if (question != null) ...[
        Row(
          children: [
            Expanded(
              child: Text(
                'Câu ${_index + 1}/${questions.length}',
                style: TextStyle(
                  color: context.qtjp.heading,
                  fontWeight: FontWeight.w800,
                  fontSize: 18,
                ),
              ),
            ),
            TextButton.icon(
              key: const ValueKey('exam-question-menu'),
              onPressed: () => _scaffold.currentState?.openEndDrawer(),
              icon: const Icon(Icons.grid_view_rounded, size: 19),
              label: const Text('Các câu'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        GestureDetector(
          key: _questionAnchor,
          behavior: HitTestBehavior.translucent,
          onHorizontalDragStart: (_) => _questionDrag = 0,
          onHorizontalDragUpdate: (details) =>
              _questionDrag += details.delta.dx,
          onHorizontalDragEnd: (details) {
            final speed = details.primaryVelocity ?? 0;
            if (_questionDrag.abs() < 55 && speed.abs() < 300) return;
            final direction = speed.abs() > 300 ? speed : _questionDrag;
            _selectQuestion(_index + (direction < 0 ? 1 : -1));
          },
          child: Card(
            key: const ValueKey('exam-question-card'),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: BorderSide(color: context.qtjp.border),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          '問題 ${question['problemNo']}',
                          style: TextStyle(
                            color: context.qtjp.blue,
                            fontWeight: FontWeight.w800,
                            fontSize: 13,
                          ),
                        ),
                      ),
                      IconButton(
                        key: const ValueKey('exam-mark'),
                        tooltip: question['markedForReview'] == true
                            ? 'Bỏ đánh dấu'
                            : 'Đánh dấu xem lại',
                        isSelected: question['markedForReview'] == true,
                        onPressed: enabled
                            ? () => _save(
                                question,
                                marked: question['markedForReview'] != true,
                              )
                            : null,
                        icon: const Icon(Icons.star_outline_rounded),
                        selectedIcon: const Icon(
                          Icons.star_rounded,
                          color: Color(0xFFD39A20),
                        ),
                        style: IconButton.styleFrom(
                          backgroundColor: question['markedForReview'] == true
                              ? const Color(0xFFFFF3CD)
                              : context.qtjp.soft,
                          foregroundColor: context.qtjp.muted,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  ExamQuestionView(
                    key: ValueKey(
                      'question-content-${question['answerKeyId']}',
                    ),
                    question: question,
                    repository: _repository,
                    document: _document,
                    documentUrl: _documentUrl,
                    enabled: enabled,
                    onAnswer: (option) => _save(question, option: option),
                  ),
                ],
              ),
            ),
          ),
        ),
        Row(
          children: [
            IconButton.outlined(
              key: const ValueKey('exam-previous-question'),
              tooltip: 'Câu trước',
              onPressed: !_busy && _index > 0
                  ? () => _selectQuestion(_index - 1)
                  : null,
              icon: const Icon(Icons.chevron_left_rounded),
            ),
            Expanded(
              child: Text(
                'Vuốt để chuyển câu',
                textAlign: TextAlign.center,
                style: TextStyle(color: context.qtjp.muted, fontSize: 12),
              ),
            ),
            IconButton.outlined(
              key: const ValueKey('exam-next-question'),
              tooltip: 'Câu sau',
              onPressed: !_busy && _index + 1 < questions.length
                  ? () => _selectQuestion(_index + 1)
                  : null,
              icon: const Icon(Icons.chevron_right_rounded),
            ),
          ],
        ),
      ] else
        _line(
          'Phần thi chưa có câu hỏi. Tải lại để kiểm tra trạng thái máy chủ.',
        ),
      if (_mustSync)
        _line(
          'Chưa xác nhận được thao tác trước. Nhấn biểu tượng tải lại ở góc trên để kiểm tra trước khi tiếp tục.',
        ),
      FilledButton(
        key: const ValueKey('exam-complete'),
        onPressed: enabled ? _complete : null,
        child: const Text('Kết thúc phần thi'),
      ),
    ];
  }

  Widget _listening(Map<String, dynamic> section) {
    try {
      final startedAt = examTime(section['startedAt']);
      if (startedAt == null) {
        throw const ApiException('Thiếu thời điểm bắt đầu bài nghe.');
      }
      return ExamListeningPlayer(
        key: ValueKey('$_session:${section['sectionId']}'),
        uri: _repository.asset(section['audioUrl'] as String),
        startedAt: startedAt,
        audioFactory: widget.audioFactory,
      );
    } catch (_) {
      return _line(
        'Chưa thể mở bài nghe do dữ liệu âm thanh hoặc thời gian không hợp lệ. Đồng bộ lại lượt thi để kiểm tra.',
      );
    }
  }

  List<Widget> _resultView() {
    final result = _result;
    if (result == null) {
      return [
        _line(
          'Chưa tải được kết quả. Mở lại từ lịch sử để kiểm tra bài đã nộp.',
        ),
      ];
    }
    return [
      ExamResultDashboard(
        result: result,
        answerBuilder: (question) => Card(
          child: ExpansionTile(
            key: ValueKey('exam-review-${question['answerKeyId']}'),
            title: Text(
              '問題 ${question['problemNo']} · Câu ${question['questionNo']}${question['subQuestionNo'] == null ? '' : ' (${question['subQuestionNo']})'} · ${question['correct'] == true
                  ? 'Đúng'
                  : question['selectedOption'] == null
                  ? 'Bỏ trống'
                  : 'Chưa đúng'}',
            ),
            childrenPadding: const EdgeInsets.all(16),
            children: [
              ExamQuestionView(
                question: question,
                repository: _repository,
                document: _document,
                documentUrl: _documentUrl,
                review: true,
              ),
            ],
          ),
        ),
      ),
      OutlinedButton(
        onPressed: _busy ? null : _back,
        child: const Text('Về danh sách đề'),
      ),
    ];
  }

  Widget _refreshAction() => IconButton(
    tooltip: 'Tải lại',
    onPressed: _busy
        ? null
        : () {
            if (_attempt != null) {
              unawaited(_refreshAttempt());
            } else if (_page == _ExamPage.detail) {
              unawaited(
                _openDetail(examId(jsonObject(_detail!['exam'])['id'])),
              );
            } else if (_result != null) {
              unawaited(_openResult(examId(_result!['attemptId'])));
            } else {
              unawaited(_loadCatalog());
            }
          },
    icon: const Icon(Icons.refresh),
  );

  Widget _embeddedToolbar() => Row(
    children: [
      if (_page != _ExamPage.catalog) BackButton(onPressed: _back),
      Expanded(
        child: Text(
          'Luyện đề JLPT',
          style: TextStyle(
            color: context.qtjp.heading,
            fontSize: 20,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      if (_page == _ExamPage.taking && _attempt?.section != null)
        IconButton(
          tooltip: 'Danh sách câu hỏi',
          onPressed: () => _scaffold.currentState?.openEndDrawer(),
          icon: const Icon(Icons.grid_view_rounded),
        ),
      _refreshAction(),
    ],
  );

  @override
  Widget build(BuildContext context) {
    _assistant?.setExamActive(this, _page == _ExamPage.taking);
    return PopScope(
      canPop: _page == _ExamPage.catalog,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _scaffold.currentState?.isEndDrawerOpen == true) {
          _scaffold.currentState?.closeEndDrawer();
          return;
        }
        if (!didPop && _page != _ExamPage.catalog) unawaited(_back());
      },
      child: KyutoScaffold(
        scaffoldKey: _scaffold,
        showAssistant: !widget.embedded,
        endDrawer: _page == _ExamPage.taking && _attempt?.section != null
            ? ExamQuestionNavigator(
                questions: _attempt!.questions,
                current: _index,
                enabled: !_busy,
                onClose: () => _scaffold.currentState?.closeEndDrawer(),
                onSelected: (index) {
                  _scaffold.currentState?.closeEndDrawer();
                  _selectQuestion(index);
                },
              )
            : null,
        appBar: widget.embedded
            ? null
            : AppBar(
                title: const Text('Luyện đề JLPT'),
                leading: _page == _ExamPage.catalog
                    ? null
                    : BackButton(onPressed: _back),
                actions: [
                  if (_page == _ExamPage.taking && _attempt?.section != null)
                    IconButton(
                      tooltip: 'Danh sách câu hỏi',
                      onPressed: () => _scaffold.currentState?.openEndDrawer(),
                      icon: const Icon(Icons.grid_view_rounded),
                    ),
                  _refreshAction(),
                ],
              ),
        body: SafeArea(
          top: false,
          child: Column(
            children: [
              if (widget.embedded)
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 4,
                  ),
                  child: _embeddedToolbar(),
                ),
              Expanded(
                child: SingleChildScrollView(
                  controller: _scroll,
                  padding: const EdgeInsets.all(20),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 760),
                      child: !_app.isAuthenticated
                          ? Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                ..._catalog(),
                                ApiErrorView(
                                  error: const ApiException(
                                    'Đăng nhập để luyện đề và xem lịch sử JLPT.',
                                    status: 401,
                                  ),
                                  onRetry: _loadCatalog,
                                ),
                              ],
                            )
                          : Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                SizedBox(
                                  height: 4,
                                  child: _busy
                                      ? const LinearProgressIndicator()
                                      : null,
                                ),
                                if (_error != null)
                                  ApiErrorView(
                                    error: _error!,
                                    onRetry: () {
                                      if (_attempt != null) {
                                        unawaited(_refreshAttempt());
                                      } else {
                                        unawaited(_loadCatalog());
                                      }
                                    },
                                  ),
                                if (_documentError != null) ...[
                                  _line(
                                    'Chưa tải được tài liệu số hóa. Không tự thay nội dung của đề khác.',
                                  ),
                                  OutlinedButton(
                                    onPressed: _busy
                                        ? null
                                        : () => _run(
                                            (session) => _loadDocument(
                                              _documentUrl!,
                                              session,
                                              force: true,
                                            ),
                                          ),
                                    child: const Text(
                                      'Tải lại tài liệu đề thi',
                                    ),
                                  ),
                                ],
                                ...switch (_page) {
                                  _ExamPage.catalog => _catalog(),
                                  _ExamPage.detail => _detailView(),
                                  _ExamPage.taking => _taking(),
                                  _ExamPage.result => _resultView(),
                                },
                              ],
                            ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
