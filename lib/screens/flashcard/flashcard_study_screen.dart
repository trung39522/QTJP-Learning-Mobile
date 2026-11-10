import 'package:flutter/material.dart';

import '../../core/theme/qtjp_colors.dart';
import '../../app/app_controller.dart';
import '../../core/network/api_client.dart';
import '../../core/widgets/api_error_view.dart';
import 'models/flashcard_deck.dart';
import 'models/flashcard_session.dart';

class FlashcardStudyScreen extends StatefulWidget {
  const FlashcardStudyScreen({
    required this.deck,
    this.onAnswer,
    this.sessionVersion,
    super.key,
  });

  final FlashcardDeck deck;
  final Future<void> Function(FlashcardWord word, bool remembered)? onAnswer;
  final int? sessionVersion;

  @override
  State<FlashcardStudyScreen> createState() => _FlashcardStudyScreenState();
}

class _FlashcardStudyScreenState extends State<FlashcardStudyScreen> {
  late FlashcardSession _session;
  bool _saving = false;
  String? _saveError;
  AppController? _app;
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
    try {
      await widget.onAnswer?.call(_session.current!, remembered);
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
  }

  void _start(List<FlashcardWord> words) => setState(() {
    _session = FlashcardSession(words);
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_sessionValid ? widget.deck.name : 'Flashcard'),
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
          : SafeArea(
              top: false,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 640),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          '${widget.deck.level} · ${widget.deck.isSample ? 'BỘ THẺ MẪU' : 'QTJP LEARNING'}',
                          style: const TextStyle(
                            color: QTJPColors.red,
                            fontSize: 12,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          widget.onAnswer == null
                              ? 'Kết quả chỉ được giữ trong phiên học này.'
                              : 'Tiến độ được lưu vào tài khoản QTJP sau mỗi thẻ.',
                          style: const TextStyle(
                            color: QTJPColors.muted,
                            fontSize: 12,
                            height: 1.5,
                          ),
                        ),
                        const SizedBox(height: 24),
                        if (widget.deck.words.isEmpty)
                          const Text(
                            'Bộ thẻ chưa có từ vựng.',
                            textAlign: TextAlign.center,
                          )
                        else if (_session.isComplete)
                          _buildSummary()
                        else ...[
                          Text(
                            'Thẻ ${_session.answered + 1} / ${_session.words.length}',
                            key: const ValueKey('study-position'),
                            style: const TextStyle(
                              color: QTJPColors.navy,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 12),
                          LinearProgressIndicator(
                            value: _session.progress,
                            minHeight: 7,
                            borderRadius: BorderRadius.circular(8),
                            semanticsLabel:
                                'Tiến độ phiên học: ${_session.answered} trên ${_session.words.length} thẻ',
                          ),
                          const SizedBox(height: 24),
                          _buildCard(),
                          const SizedBox(height: 20),
                          OutlinedButton.icon(
                            key: const ValueKey('study-flip'),
                            onPressed: _saving
                                ? null
                                : () => setState(_session.flip),
                            icon: const Icon(Icons.flip_rounded),
                            label: Text(
                              _session.isRevealed ? 'Xem mặt trước' : 'Lật thẻ',
                            ),
                          ),
                          const SizedBox(height: 16),
                          Wrap(
                            spacing: 12,
                            runSpacing: 12,
                            alignment: WrapAlignment.center,
                            children: [
                              OutlinedButton.icon(
                                key: const ValueKey('study-forgot'),
                                onPressed: !_session.isRevealed || _saving
                                    ? null
                                    : () => _answer(false),
                                icon: const Icon(Icons.replay_rounded),
                                label: const Text('Chưa nhớ'),
                              ),
                              FilledButton.icon(
                                key: const ValueKey('study-remembered'),
                                style: FilledButton.styleFrom(
                                  backgroundColor: QTJPColors.navy,
                                ),
                                onPressed: !_session.isRevealed || _saving
                                    ? null
                                    : () => _answer(true),
                                icon: const Icon(Icons.check_rounded),
                                label: const Text('Đã nhớ'),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          if (_saving) const LinearProgressIndicator(),
                          if (_saveError != null)
                            Text(
                              _saveError!,
                              style: const TextStyle(color: QTJPColors.red),
                              textAlign: TextAlign.center,
                            ),
                          const Text(
                            'Lật thẻ để xem nghĩa và ví dụ, sau đó tự đánh giá mức độ ghi nhớ.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: QTJPColors.muted,
                              height: 1.6,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
    );
  }

  Widget _buildCard() {
    final card = _session.current!;
    return Semantics(
      button: true,
      label: _session.isRevealed
          ? 'Mặt sau. Chạm để xem mặt trước.'
          : 'Mặt trước. Chạm để lật thẻ.',
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: _saving ? null : () => setState(_session.flip),
          child: Container(
            constraints: const BoxConstraints(minHeight: 280),
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(28),
              border: Border.all(color: QTJPColors.border),
            ),
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 180),
              child: _session.isRevealed
                  ? Column(
                      key: ValueKey('back-${_session.answered}'),
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          card.word,
                          style: const TextStyle(
                            color: QTJPColors.navy,
                            fontSize: 36,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '${card.hiragana} · ${card.romaji}',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: QTJPColors.blue,
                            fontSize: 16,
                            height: 1.5,
                          ),
                        ),
                        const SizedBox(height: 20),
                        Text(
                          card.meaning,
                          key: const ValueKey('study-meaning'),
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: QTJPColors.navyDark,
                            fontSize: 26,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 20),
                        const Divider(),
                        Text(
                          card.example,
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 18, height: 1.6),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          card.exampleVi,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: QTJPColors.muted,
                            height: 1.6,
                          ),
                        ),
                      ],
                    )
                  : Column(
                      key: ValueKey('front-${_session.answered}'),
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          'TIẾNG NHẬT',
                          style: TextStyle(
                            color: QTJPColors.blue,
                            fontSize: 11,
                            letterSpacing: 1.5,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 28),
                        Text(
                          card.word,
                          key: const ValueKey('study-word'),
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: QTJPColors.navy,
                            fontSize: 52,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 28),
                        const Text(
                          'Bạn có nhớ nghĩa của từ này?',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: QTJPColors.muted),
                        ),
                      ],
                    ),
            ),
          ),
        ),
      ),
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
        const Text(
          'Hoàn thành phiên học!',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: QTJPColors.navy,
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
                  style: const TextStyle(
                    color: QTJPColors.navy,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Chưa nhớ: ${_session.forgotten.length}',
                  style: const TextStyle(color: QTJPColors.muted, fontSize: 16),
                ),
                const SizedBox(height: 12),
                Text(
                  'Tự đánh giá ghi nhớ: $accuracy%',
                  style: const TextStyle(color: QTJPColors.blue),
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
