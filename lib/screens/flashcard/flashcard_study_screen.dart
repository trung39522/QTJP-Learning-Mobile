import 'package:flutter/material.dart';

import '../../core/widgets/kyuto_scaffold.dart';

import 'dart:async';
import 'dart:math' as math;

import '../../core/theme/qtjp_colors.dart';
import '../../app/app_controller.dart';
import '../../core/network/api_client.dart';
import '../../core/widgets/api_error_view.dart';
import '../../core/widgets/japanese_sentence.dart';
import 'models/flashcard_deck.dart';
import 'models/flashcard_session.dart';
import '../alphabet/services/kana_speech.dart';
import 'widgets/flashcard_vocabulary_list.dart';
import 'vocabulary_practice_screen.dart';
import 'widgets/flashcard_workspace.dart';

class FlashcardStudyScreen extends StatefulWidget {
  const FlashcardStudyScreen({
    required this.deck,
    this.onAnswer,
    this.sessionVersion,
    this.initiallyShowVocabulary = false,
    this.initialProgress = const {},
    super.key,
  });

  final FlashcardDeck deck;
  final Future<void> Function(FlashcardWord word, bool remembered)? onAnswer;
  final int? sessionVersion;
  final bool initiallyShowVocabulary;
  final Map<int, bool> initialProgress;

  @override
  State<FlashcardStudyScreen> createState() => _FlashcardStudyScreenState();
}

class _FlashcardStudyScreenState extends State<FlashcardStudyScreen> {
  late FlashcardSession _session;
  bool _saving = false;
  String? _saveError;
  AppController? _app;
  final _speech = DeviceKanaSpeech();
  bool _reverse = false, _showVocabulary = false;
  late final Map<int, bool> _results = {...widget.initialProgress};

  Future<void> _record(FlashcardWord word, bool remembered) async {
    if (!_sessionValid) {
      throw const ApiException('Phiên học đã thay đổi.', status: 401);
    }
    await widget.onAnswer?.call(word, remembered);
    if (!_sessionValid) {
      throw const ApiException('Phiên học đã thay đổi.', status: 401);
    }
    if (mounted && word.id != null) {
      setState(() => _results[word.id!] = remembered);
    }
  }

  Future<void> _practice([VocabularyMode mode = VocabularyMode.quiz]) async {
    unawaited(_speech.stop());
    await Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (_) => VocabularyPracticeScreen(
          deck: widget.deck,
          initialMode: mode,
          onAnswer: _record,
          sessionVersion: widget.sessionVersion,
        ),
      ),
    );
  }

  Future<void> _speak(String text) async {
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

  bool get _sessionValid =>
      widget.sessionVersion == null ||
      (_app!.isAuthenticated &&
          _app!.api.sessionVersion == widget.sessionVersion);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (widget.sessionVersion != null) _app = AppScope.of(context);
  }

  Future<void> _answer(bool remembered) async {
    if (!_sessionValid ||
        _saving ||
        !_session.isRevealed ||
        _session.current == null) {
      return;
    }
    setState(() {
      _saving = true;
      _saveError = null;
    });
    unawaited(_speech.stop());
    try {
      await _record(_session.current!, remembered);
      if (mounted && _sessionValid) {
        setState(() => _session.answer(remembered: remembered));
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => _saveError = 'Chưa lưu được tiến độ. Kiểm tra kết nối hoặc đăng nhập lại, rồi bấm đánh giá lần nữa.',
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  void initState() {
    super.initState();
    _session = FlashcardSession(widget.deck.words);
    _showVocabulary = widget.initiallyShowVocabulary;
  }

  void _start(List<FlashcardWord> words) => setState(() {
    _session = FlashcardSession(words);
  });

  void _selectCard(int index) {
    if (_saving) return;
    unawaited(_speech.stop());
    setState(() => _session.select(index));
  }

  @override
  Widget build(BuildContext context) => KyutoScaffold(
    appBar: AppBar(
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _sessionValid ? widget.deck.name : 'Flashcard',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
          ),
          if (_sessionValid)
            Text(
              '${widget.deck.level} · ${widget.deck.words.length} từ vựng',
              style: TextStyle(
                color: context.qtjp.muted,
                fontSize: 11,
                height: 1.8,
              ),
            ),
        ],
      ),
      actions: [
        if (_sessionValid)
          IconButton(
            tooltip: _showVocabulary ? 'Về lật thẻ' : 'Danh sách từ vựng',
            onPressed: _saving
                ? null
                : () {
                    unawaited(_speech.stop());
                    setState(() => _showVocabulary = !_showVocabulary);
                  },
            icon: Icon(
              _showVocabulary
                  ? Icons.style_outlined
                  : Icons.format_list_bulleted_rounded,
            ),
          ),
        const SizedBox(width: 8),
      ],
    ),
    body: !_sessionValid
        ? Center(
            child: ApiErrorView(
              error: const ApiException(
                'Phiên học đã thay đổi. Quay lại chọn bộ thẻ bằng tài khoản hiện tại.',
                status: 401,
              ),
              onRetry: () => Navigator.of(context).pop(),
            ),
          )
        : FlashcardWorkspace(
            child: SafeArea(
              top: false,
              child: _showVocabulary
                  ? FlashcardVocabularyList(
                      deck: widget.deck,
                      onSpeak: _speak,
                      results: _results,
                      onPractice: _practice,
                      onSelect: (word) {
                        unawaited(_speech.stop());
                        setState(() {
                          _session = FlashcardSession(widget.deck.words);
                          _session.select(widget.deck.words.indexOf(word));
                          _showVocabulary = false;
                        });
                      },
                    )
                  : SingleChildScrollView(
                      padding: const EdgeInsets.all(16),
                      child: Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 640),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              if (widget.deck.words.isEmpty)
                                const Padding(
                                  padding: EdgeInsets.all(24),
                                  child: Text(
                                    'Bộ thẻ chưa có từ vựng.',
                                    textAlign: TextAlign.center,
                                  ),
                                )
                              else if (_session.isComplete)
                                _buildSummary()
                              else ...[
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(6),
                                  child: LinearProgressIndicator(
                                    value: _session.progress,
                                    minHeight: 4,
                                    backgroundColor: context.qtjp.border,
                                    color: context.qtjp.blue,
                                    semanticsLabel:
                                        'Tiến độ phiên học: ${_session.answered} trên ${_session.words.length} thẻ',
                                  ),
                                ),
                                const SizedBox(height: 12),
                                _buildCard(),
                                const SizedBox(height: 12),
                                _buildControls(),
                              ],
                              const SizedBox(height: 12),
                              FlashcardModeBar(
                                enabled: !_saving,
                                onSelected: (mode) => _practice(mode),
                              ),
                              if (_saving)
                                const Padding(
                                  padding: EdgeInsets.only(top: 12),
                                  child: LinearProgressIndicator(),
                                ),
                              if (_saveError != null)
                                Padding(
                                  padding: const EdgeInsets.all(12),
                                  child: Text(
                                    _saveError!,
                                    style: const TextStyle(
                                      color: QTJPColors.red,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                              const SizedBox(height: 16),
                              Text(
                                'Chạm vào thẻ để lật · Vuốt hàng chế độ để chọn cách luyện tập',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: context.qtjp.muted,
                                  fontSize: 11,
                                  height: 1.7,
                                ),
                              ),
                              const SizedBox(height: 12),
                            ],
                          ),
                        ),
                      ),
                    ),
            ),
          ),
  );

  Widget _buildControls() => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: context.qtjp.surface,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: context.qtjp.border),
      boxShadow: [
        BoxShadow(
          color: QTJPColors.navy.withValues(alpha: .035),
          blurRadius: 18,
          offset: const Offset(0, 6),
        ),
      ],
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SegmentedButton<bool>(
          segments: const [
            ButtonSegment(value: false, label: Text('Nhật → Việt')),
            ButtonSegment(value: true, label: Text('Việt → Nhật')),
          ],
          showSelectedIcon: false,
          selected: {_reverse},
          onSelectionChanged: _saving
              ? null
              : (value) => setState(() {
                  _reverse = value.single;
                  if (_session.isRevealed) _session.flip();
                }),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                key: const ValueKey('study-forgot'),
                onPressed: !_session.isRevealed || _saving
                    ? null
                    : () => _answer(false),
                style: OutlinedButton.styleFrom(
                  foregroundColor: QTJPColors.red,
                  side: BorderSide(color: QTJPColors.red.withValues(alpha: .3)),
                ),
                icon: const Icon(Icons.close_rounded, size: 19),
                label: const Text('Chưa nhớ'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: FilledButton.icon(
                key: const ValueKey('study-remembered'),
                onPressed: !_session.isRevealed || _saving
                    ? null
                    : () => _answer(true),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF21845B),
                ),
                icon: const Icon(Icons.check_rounded, size: 19),
                label: const Text('Đã nhớ'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Wrap(
          alignment: WrapAlignment.spaceEvenly,
          spacing: 4,
          runSpacing: 2,
          children: [
            _tool(
              Icons.volume_up_outlined,
              'Phát âm',
              () => _speak(
                _session.current!.hiragana.isEmpty
                    ? _session.current!.word
                    : _session.current!.hiragana,
              ),
            ),
            _tool(
              Icons.shuffle_rounded,
              'Trộn',
              () => setState(() {
                unawaited(_speech.stop());
                final words = [...widget.deck.words]..shuffle();
                _session = FlashcardSession(words);
              }),
            ),
            _tool(
              Icons.restart_alt_rounded,
              'Học lại',
              () => _start(widget.deck.words),
            ),
            _tool(
              Icons.play_circle_outline_rounded,
              'Tự động',
              () => _practice(VocabularyMode.auto),
            ),
          ],
        ),
      ],
    ),
  );

  Widget _tool(IconData icon, String label, VoidCallback action) => TextButton(
    onPressed: _saving ? null : action,
    style: TextButton.styleFrom(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
    ),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 21),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(fontSize: 10)),
      ],
    ),
  );

  Widget _buildCard() {
    final card = _session.current!;
    const white = Colors.white;
    const muted = Color(0xFFB5C8E0);
    const teal = Color(0xFF7EE3DC);
    Widget nav(bool next) => IconButton(
      tooltip: next ? 'Thẻ tiếp' : 'Thẻ trước',
      onPressed:
          _saving ||
              (next
                  ? _session.answered >= _session.words.length - 1
                  : _session.answered == 0)
          ? null
          : () => _selectCard(_session.answered + (next ? 1 : -1)),
      icon: Icon(
        next ? Icons.chevron_right_rounded : Icons.chevron_left_rounded,
      ),
      style: IconButton.styleFrom(
        foregroundColor: Colors.white,
        disabledForegroundColor: const Color(0xFF65748A),
        backgroundColor: Colors.white.withValues(alpha: .08),
        minimumSize: const Size(44, 44),
      ),
    );
    final front = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(height: MediaQuery.sizeOf(context).height < 700 ? 30 : 48),
        Text(
          _reverse ? card.meaning : card.word,
          key: const ValueKey('study-word'),
          textAlign: TextAlign.center,
          style: TextStyle(
            color: white,
            fontSize: _reverse ? 28 : 38,
            fontWeight: FontWeight.w700,
            height: 1.55,
            letterSpacing: _reverse ? 0 : 1,
          ),
        ),
        const SizedBox(height: 36),
        Text(
          _reverse ? 'TIẾNG VIỆT' : 'TIẾNG NHẬT',
          style: const TextStyle(
            color: muted,
            fontSize: 10,
            letterSpacing: 1.5,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
    final back = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(height: 12),
        Text(
          card.word,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: white,
            fontSize: 30,
            fontWeight: FontWeight.w800,
            height: 1.6,
          ),
        ),
        if (card.hanViet.isNotEmpty)
          Text(
            '「${card.hanViet}」',
            style: const TextStyle(color: muted, fontSize: 12, height: 1.8),
          ),
        Text(
          [card.hiragana, card.romaji].where((s) => s.isNotEmpty).join(' · '),
          textAlign: TextAlign.center,
          style: const TextStyle(color: teal, fontSize: 15, height: 1.8),
        ),
        const SizedBox(height: 16),
        Text(
          card.meaning,
          key: const ValueKey('study-meaning'),
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: white,
            fontSize: 23,
            fontWeight: FontWeight.w700,
            height: 1.5,
          ),
        ),
        if (card.example.isNotEmpty) ...[
          Divider(height: 28, color: white.withValues(alpha: .15)),
          Row(
            children: [
              const Expanded(
                child: Text(
                  'VÍ DỤ',
                  style: TextStyle(
                    color: muted,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1,
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Phát âm câu ví dụ',
                onPressed: () => _speak(card.example),
                icon: const Icon(
                  Icons.volume_up_outlined,
                  color: teal,
                  size: 20,
                ),
              ),
            ],
          ),
          JapaneseSentence(
            text: card.example,
            segments: card.exampleFurigana,
            centered: true,
            foregroundColor: white,
            readingColor: teal,
          ),
          if (card.exampleVi.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                card.exampleVi,
                textAlign: TextAlign.center,
                style: const TextStyle(color: muted, height: 1.6, fontSize: 13),
              ),
            ),
        ],
      ],
    );
    return TweenAnimationBuilder<double>(
      key: ValueKey('study-card-${_session.answered}-$_reverse'),
      tween: Tween(begin: 0, end: _session.isRevealed ? 1 : 0),
      duration: MediaQuery.disableAnimationsOf(context)
          ? Duration.zero
          : const Duration(milliseconds: 380),
      curve: Curves.easeInOutCubic,
      builder: (context, value, _) {
        final showBack = value >= .5;
        final angle = value * math.pi;
        return Semantics(
          button: true,
          label: showBack
              ? 'Mặt sau. Chạm để xem mặt trước.'
              : 'Mặt trước. Chạm để lật thẻ.',
          child: Transform(
            alignment: Alignment.center,
            transform: Matrix4.identity()
              ..setEntry(3, 2, .0012)
              ..rotateY(showBack ? angle - math.pi : angle),
            child: AnimatedSize(
              duration: const Duration(milliseconds: 160),
              alignment: Alignment.topCenter,
              child: Material(
                color: const Color(0xFF263651),
                elevation: 4,
                shadowColor: QTJPColors.navy.withValues(alpha: .2),
                borderRadius: BorderRadius.circular(20),
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  onTap: _saving ? null : () => setState(_session.flip),
                  child: Container(
                    constraints: const BoxConstraints(minHeight: 300),
                    padding: const EdgeInsets.fromLTRB(18, 16, 18, 12),
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [Color(0xFF304363), Color(0xFF1C2B44)],
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: white.withValues(alpha: .1),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                'Thẻ ${_session.answered + 1} / ${_session.words.length}',
                                key: const ValueKey('study-position'),
                                style: const TextStyle(
                                  color: white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Align(
                                alignment: Alignment.centerRight,
                                child: card.partOfSpeech.isEmpty
                                    ? const SizedBox()
                                    : Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 5,
                                        ),
                                        decoration: BoxDecoration(
                                          color: teal.withValues(alpha: .1),
                                          borderRadius: BorderRadius.circular(
                                            7,
                                          ),
                                          border: Border.all(
                                            color: teal.withValues(alpha: .35),
                                          ),
                                        ),
                                        child: Text(
                                          card.partOfSpeech,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            color: teal,
                                            fontSize: 10,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            IconButton(
                              tooltip: 'Phát âm tiếng Nhật',
                              onPressed: () => _speak(
                                card.hiragana.isEmpty
                                    ? card.word
                                    : card.hiragana,
                              ),
                              icon: const Icon(
                                Icons.volume_up_rounded,
                                size: 20,
                              ),
                              style: IconButton.styleFrom(
                                backgroundColor: const Color(0xFF327ACA),
                                foregroundColor: white,
                              ),
                            ),
                          ],
                        ),
                        showBack ? back : front,
                        const SizedBox(height: 20),
                        Row(
                          children: [
                            nav(false),
                            Expanded(
                              child: TextButton.icon(
                                key: const ValueKey('study-flip'),
                                onPressed: _saving
                                    ? null
                                    : () => setState(_session.flip),
                                icon: const Icon(Icons.flip_rounded, size: 17),
                                label: Text(showBack ? 'Mặt trước' : 'Lật thẻ'),
                                style: TextButton.styleFrom(
                                  foregroundColor: muted,
                                  textStyle: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    fontFamily: 'Roboto',
                                  ),
                                ),
                              ),
                            ),
                            nav(true),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildSummary() {
    final count = _session.words.length;
    final accuracy = count == 0
        ? 0
        : (_session.remembered / count * 100).round();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Icon(Icons.celebration_outlined, color: QTJPColors.red, size: 52),
        const SizedBox(height: 16),
        Text(
          _session.graded == count
              ? 'Hoàn thành phiên học!'
              : 'Kết quả phiên học',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: context.qtjp.heading,
            fontSize: 26,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 24),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                Text(
                  'Đã nhớ: ${_session.remembered} / $count',
                  key: const ValueKey('study-summary-remembered'),
                  style: TextStyle(
                    color: context.qtjp.heading,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Chưa nhớ: ${_session.forgotten.length}',
                  style: TextStyle(color: context.qtjp.muted, fontSize: 16),
                ),
                if (_session.graded < count)
                  Text(
                    'Chưa đánh giá: ${count - _session.graded}',
                    style: TextStyle(color: context.qtjp.muted, height: 2),
                  ),
                const SizedBox(height: 12),
                Text(
                  'Tự đánh giá ghi nhớ: $accuracy%',
                  style: TextStyle(color: context.qtjp.blue),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),
        if (_session.forgotten.isNotEmpty) ...[
          FilledButton(
            key: const ValueKey('study-review'),
            onPressed: () => _start(_session.forgotten),
            child: Text('Ôn lại ${_session.forgotten.length} từ chưa nhớ'),
          ),
          const SizedBox(height: 12),
        ],
        OutlinedButton(
          key: const ValueKey('study-restart'),
          onPressed: () => _start(widget.deck.words),
          child: const Text('Học lại bộ thẻ'),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Về danh sách bộ thẻ'),
        ),
      ],
    );
  }
}
