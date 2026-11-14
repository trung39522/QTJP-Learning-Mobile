import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

import '../../core/widgets/kyuto_scaffold.dart';

import '../../app/app_controller.dart';
import '../../core/theme/qtjp_colors.dart';
import '../alphabet/services/kana_speech.dart';
import 'models/flashcard_deck.dart';

enum VocabularyMode { quiz, listening, typing, fill, auto }

const _modeLabels = {
  VocabularyMode.quiz: 'Trắc nghiệm',
  VocabularyMode.listening: 'Nghe chọn',
  VocabularyMode.typing: 'Gõ chữ',
  VocabularyMode.fill: 'Điền từ',
  VocabularyMode.auto: 'Tự động phát',
};
String normalizeVocabularyAnswer(String value) =>
    value.trim().toLowerCase().replaceAll(RegExp(r'[\s。、，,.!?！？]'), '');

class VocabularyPracticeScreen extends StatefulWidget {
  const VocabularyPracticeScreen({
    required this.deck,
    required this.onAnswer,
    this.sessionVersion,
    this.speech,
    this.initialMode = VocabularyMode.quiz,
    super.key,
  });
  final FlashcardDeck deck;
  final Future<void> Function(FlashcardWord, bool)? onAnswer;
  final int? sessionVersion;
  final KanaSpeech? speech;
  final VocabularyMode initialMode;
  @override
  State<VocabularyPracticeScreen> createState() =>
      _VocabularyPracticeScreenState();
}

class _VocabularyPracticeScreenState extends State<VocabularyPracticeScreen>
    with WidgetsBindingObserver {
  late final KanaSpeech _speech = widget.speech ?? DeviceKanaSpeech();
  late List<FlashcardWord> _words = [...widget.deck.words];
  final _input = TextEditingController();
  VocabularyMode _mode = VocabularyMode.quiz;
  int _index = 0, _hint = 0, _epoch = 0;
  bool _busy = false,
      _checked = false,
      _correct = false,
      _reverse = false,
      _running = false,
      _back = false;
  bool _readWord = true, _readExample = false;
  int _frontSeconds = 3, _backSeconds = 2, _repeat = 1;
  String? _error;
  List<FlashcardWord> _options = [];
  final Map<FlashcardWord, bool> _results = {};
  Timer? _delay;
  AppController? _app;
  bool get _valid =>
      widget.sessionVersion == null ||
      (_app!.isAuthenticated &&
          widget.sessionVersion == _app!.api.sessionVersion);
  FlashcardWord get _word => _words[_index];
  bool get _complete => _index >= _words.length;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _mode = widget.initialMode;
    if (_words.isNotEmpty) _prepare();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (widget.sessionVersion != null) _app = AppScope.of(context);
    if (!_valid) _stop();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed && _running) setState(_stop);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _stop();
    _input.dispose();
    unawaited(_speech.stop());
    super.dispose();
  }

  void _stop() {
    _epoch++;
    _delay?.cancel();
    _running = false;
    unawaited(_speech.stop());
  }

  void _prepare() {
    _checked = false;
    _error = null;
    _hint = 0;
    _back = false;
    _input.clear();
    if (_complete) return;
    final label = _label(_word);
    final seen = {label};
    final others = [..._words]..shuffle();
    _options = [
      _word,
      ...others
          .where(
            (word) =>
                word != _word &&
                _label(word).isNotEmpty &&
                seen.add(_label(word)),
          )
          .take(3),
    ]..shuffle();
  }

  String _label(FlashcardWord word) => _mode == VocabularyMode.fill
      ? (_fillAnswer == _word.hiragana ? word.hiragana : word.word)
      : _mode == VocabularyMode.listening || !_reverse
      ? word.meaning
      : word.word;
  String get _fillAnswer {
    final candidates =
        [_word.word, _word.hiragana].where((v) => v.isNotEmpty).toList()
          ..sort((a, b) => b.length.compareTo(a.length));
    return candidates.firstWhere(
      (v) => _word.example.contains(v),
      orElse: () => '',
    );
  }

  Future<bool> _speak(String text) async {
    if (!_valid) return false;
    try {
      await _speech.speak(text);
      return true;
    } catch (error) {
      if (mounted && _valid) {
        setState(() {
          _error = error is KanaSpeechFailure
              ? error.message
              : 'Chưa thể phát âm.';
          _stop();
        });
      }
      return false;
    }
  }

  void _next() {
    _stop();
    setState(() {
      _index++;
      _prepare();
    });
  }

  Future<void> _check(bool correct) async {
    if (_busy || _checked || !_valid) return;
    FocusScope.of(context).unfocus();
    final word = _word;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.onAnswer?.call(word, correct);
      if (!mounted || !_valid) return;
      setState(() {
        _checked = true;
        _correct = correct;
        _results[word] = correct;
      });
    } catch (_) {
      if (mounted && _valid) {
        setState(
          () => _error = 'Chưa lưu được kết quả. Kiểm tra kết nối rồi thử lại.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _autoStep(int epoch) async {
    if (!mounted || !_valid || !_running || epoch != _epoch || _complete) {
      return;
    }
    final word = _word;
    final text = _back
        ? (_readExample ? word.example : '')
        : (_readWord
              ? (word.hiragana.isEmpty ? word.word : word.hiragana)
              : '');
    if (text.isNotEmpty) {
      for (var i = 0; i < _repeat; i++) {
        if (epoch != _epoch || !await _speak(text)) return;
      }
    }
    if (!mounted || !_valid || !_running || epoch != _epoch) return;
    _delay = Timer(Duration(seconds: _back ? _backSeconds : _frontSeconds), () {
      if (!mounted || !_valid || !_running || epoch != _epoch) return;
      setState(() {
        if (_back) {
          _index++;
          _prepare();
        } else {
          _back = true;
        }
        if (_complete) _stop();
      });
      if (!_complete) unawaited(_autoStep(epoch));
    });
  }

  void _startAuto() {
    setState(() {
      _running = true;
      _error = null;
    });
    unawaited(_autoStep(++_epoch));
  }

  @override
  Widget build(BuildContext context) => KyutoScaffold(
    backgroundColor: Theme.of(context).brightness == Brightness.dark
        ? const Color(0xFF0B1425)
        : const Color(0xFFEAF0F8),
    appBar: AppBar(title: const Text('Luyện tập từ vựng')),
    body: SafeArea(
      top: false,
      child: !_valid
          ? const Center(
              child: Text('Phiên học đã thay đổi. Vui lòng mở lại bộ từ.'),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 640),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        widget.deck.name,
                        style: TextStyle(
                          color: context.qtjp.heading,
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 12),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            for (final mode in VocabularyMode.values)
                              Padding(
                                padding: const EdgeInsets.only(right: 8),
                                child: ChoiceChip(
                                  key: ValueKey('practice-mode-${mode.name}'),
                                  label: Text(_modeLabels[mode]!),
                                  selected: _mode == mode,
                                  onSelected: _busy
                                      ? null
                                      : (_) {
                                          _stop();
                                          setState(() {
                                            _mode = mode;
                                            if (_complete) _index = 0;
                                            if (mode ==
                                                VocabularyMode.listening) {
                                              _reverse = false;
                                            }
                                            _prepare();
                                          });
                                        },
                                ),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      if (_words.isEmpty)
                        const Text('Bộ từ chưa có dữ liệu.')
                      else if (_complete) ...[
                        const Icon(
                          Icons.task_alt_rounded,
                          size: 64,
                          color: Color(0xFF21845B),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _mode == VocabularyMode.auto
                              ? 'Đã xem hết bộ từ'
                              : 'Kết quả luyện tập',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: context.qtjp.heading,
                            fontSize: 26,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 16),
                        if (_mode != VocabularyMode.auto)
                          Text(
                            '${_results.values.where((v) => v).length}/${_results.length} câu đúng',
                            textAlign: TextAlign.center,
                          ),
                        const SizedBox(height: 16),
                        FilledButton(
                          onPressed: () => setState(() {
                            _index = 0;
                            _results.clear();
                            _prepare();
                          }),
                          child: const Text('Luyện lại bộ từ'),
                        ),
                        if (_results.values.contains(false))
                          OutlinedButton(
                            onPressed: () => setState(() {
                              _words = _words
                                  .where((w) => _results[w] == false)
                                  .toList();
                              _index = 0;
                              _results.clear();
                              _prepare();
                            }),
                            child: const Text('Ôn lại từ trả lời sai'),
                          ),
                      ] else ...[
                        if (_mode == VocabularyMode.quiz)
                          SegmentedButton<bool>(
                            segments: const [
                              ButtonSegment(
                                value: false,
                                label: Text('Nhật → Việt'),
                              ),
                              ButtonSegment(
                                value: true,
                                label: Text('Việt → Nhật'),
                              ),
                            ],
                            selected: {_reverse},
                            showSelectedIcon: false,
                            onSelectionChanged: _busy
                                ? null
                                : (v) => setState(() {
                                    _reverse = v.single;
                                    _prepare();
                                  }),
                          ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                'Từ ${_index + 1}/${_words.length}',
                                style: TextStyle(
                                  color: context.qtjp.heading,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                            IconButton(
                              tooltip: 'Trộn từ',
                              onPressed: _busy || _running
                                  ? null
                                  : () => setState(() {
                                      _words.shuffle(Random());
                                      _index = 0;
                                      _prepare();
                                    }),
                              icon: const Icon(Icons.shuffle_rounded),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        if (_mode == VocabularyMode.auto) ...[
                          _autoSettings(),
                          const SizedBox(height: 12),
                          Card(
                            color: context.qtjp.surface,
                            child: Padding(
                              padding: const EdgeInsets.all(24),
                              child: Column(
                                children: [
                                  Text(
                                    _back ? _word.meaning : _word.word,
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      color: context.qtjp.heading,
                                      fontSize: 32,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  if (_back) ...[
                                    Text(
                                      _word.hiragana,
                                      style: TextStyle(
                                        color: context.qtjp.blue,
                                        height: 2,
                                      ),
                                    ),
                                    Text(
                                      _word.example,
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(height: 1.8),
                                    ),
                                    Text(
                                      _word.exampleVi,
                                      textAlign: TextAlign.center,
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ),
                          FilledButton.icon(
                            onPressed: _running
                                ? () => setState(_stop)
                                : _startAuto,
                            icon: Icon(
                              _running
                                  ? Icons.pause_rounded
                                  : Icons.play_arrow_rounded,
                            ),
                            label: Text(
                              _running
                                  ? 'Dừng tự động phát'
                                  : 'Bắt đầu tự động phát',
                            ),
                          ),
                          const Text(
                            'Tự động phát giúp ôn lại nội dung, không tự đánh giá hoặc lưu tiến độ.',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 12, height: 1.7),
                          ),
                        ] else ...[
                          Card(
                            color: context.qtjp.surface,
                            child: Padding(
                              padding: const EdgeInsets.all(22),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Text(
                                    switch (_mode) {
                                      VocabularyMode.listening =>
                                        'Nghe và chọn nghĩa đúng',
                                      VocabularyMode.typing =>
                                        'Nhập từ tiếng Nhật',
                                      VocabularyMode.fill =>
                                        'Chọn từ còn thiếu',
                                      _ => 'Chọn đáp án đúng',
                                    },
                                    style: TextStyle(
                                      color: context.qtjp.muted,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  const SizedBox(height: 20),
                                  if (_mode == VocabularyMode.listening)
                                    Center(
                                      child: IconButton.filled(
                                        key: const ValueKey('practice-listen'),
                                        iconSize: 42,
                                        padding: const EdgeInsets.all(18),
                                        onPressed: () => _speak(
                                          _word.hiragana.isEmpty
                                              ? _word.word
                                              : _word.hiragana,
                                        ),
                                        icon: const Icon(
                                          Icons.volume_up_rounded,
                                        ),
                                      ),
                                    )
                                  else
                                    Text(
                                      _mode == VocabularyMode.fill
                                          ? (_fillAnswer.isEmpty
                                                ? 'Từ này chưa có ví dụ phù hợp để điền từ.'
                                                : _word.example.replaceFirst(
                                                    _fillAnswer,
                                                    '＿＿＿＿',
                                                  ))
                                          : _mode == VocabularyMode.typing ||
                                                _reverse
                                          ? _word.meaning
                                          : _word.word,
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        color: context.qtjp.heading,
                                        fontSize: _mode == VocabularyMode.fill
                                            ? 23
                                            : 30,
                                        fontWeight: FontWeight.w800,
                                        height: 1.7,
                                      ),
                                    ),
                                  if (_mode == VocabularyMode.fill &&
                                      _fillAnswer.isNotEmpty)
                                    Text(
                                      _word.exampleVi,
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        color: context.qtjp.muted,
                                        height: 1.7,
                                      ),
                                    ),
                                  if (_mode == VocabularyMode.typing) ...[
                                    const SizedBox(height: 20),
                                    TextField(
                                      key: const ValueKey('practice-typing'),
                                      controller: _input,
                                      enabled: !_checked && !_busy,
                                      decoration: const InputDecoration(
                                        hintText: 'Kanji, Hiragana hoặc Romaji',
                                      ),
                                      onSubmitted: (_) {
                                        if (_input.text.trim().isNotEmpty) {
                                          _check(
                                            [
                                                  _word.word,
                                                  _word.hiragana,
                                                  _word.romaji,
                                                ]
                                                .where((v) => v.isNotEmpty)
                                                .map(normalizeVocabularyAnswer)
                                                .contains(
                                                  normalizeVocabularyAnswer(
                                                    _input.text,
                                                  ),
                                                ),
                                          );
                                        }
                                      },
                                    ),
                                    if (_hint > 0)
                                      Text(
                                        'Gợi ý: ${String.fromCharCodes((_word.hiragana.isEmpty ? _word.word : _word.hiragana).runes.take(_hint))}',
                                        style: TextStyle(
                                          color: context.qtjp.blue,
                                          height: 2,
                                        ),
                                      ),
                                    const SizedBox(height: 12),
                                    if (!_checked)
                                      Wrap(
                                        spacing: 8,
                                        children: [
                                          TextButton(
                                            onPressed: _busy
                                                ? null
                                                : () => setState(() => _hint++),
                                            child: const Text('Gợi ý'),
                                          ),
                                          FilledButton(
                                            key: const ValueKey(
                                              'practice-check',
                                            ),
                                            onPressed: _busy
                                                ? null
                                                : () {
                                                    if (_input.text
                                                        .trim()
                                                        .isNotEmpty) {
                                                      _check(
                                                        [
                                                              _word.word,
                                                              _word.hiragana,
                                                              _word.romaji,
                                                            ]
                                                            .where(
                                                              (v) =>
                                                                  v.isNotEmpty,
                                                            )
                                                            .map(
                                                              normalizeVocabularyAnswer,
                                                            )
                                                            .contains(
                                                              normalizeVocabularyAnswer(
                                                                _input.text,
                                                              ),
                                                            ),
                                                      );
                                                    }
                                                  },
                                            child: const Text('Kiểm tra'),
                                          ),
                                        ],
                                      ),
                                  ],
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          if (_mode != VocabularyMode.typing &&
                              !(_mode == VocabularyMode.fill &&
                                  _fillAnswer.isEmpty))
                            if (_options.length < 2)
                              const Text(
                                'Cần ít nhất hai đáp án khác nhau để luyện lựa chọn. Bạn có thể chuyển sang Gõ chữ.',
                              )
                            else
                              for (final option in _options)
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 10),
                                  child: OutlinedButton(
                                    key: ValueKey(
                                      'practice-option-${option.id ?? option.word}',
                                    ),
                                    style: OutlinedButton.styleFrom(
                                      backgroundColor:
                                          _checked && option == _word
                                          ? const Color(0xFFDDF4E8)
                                          : context.qtjp.surface,
                                      foregroundColor:
                                          _checked && option == _word
                                          ? const Color(0xFF155B3D)
                                          : context.qtjp.heading,
                                      padding: const EdgeInsets.all(16),
                                      alignment: Alignment.centerLeft,
                                    ),
                                    onPressed: _checked || _busy
                                        ? null
                                        : () => _check(option == _word),
                                    child: Text(
                                      _label(option),
                                      style: const TextStyle(
                                        fontSize: 17,
                                        height: 1.5,
                                      ),
                                    ),
                                  ),
                                ),
                          if (_checked)
                            Container(
                              key: const ValueKey('practice-feedback'),
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: _correct
                                    ? const Color(0xFFDDF4E8)
                                    : context.qtjp.pink,
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Text(
                                    _correct ? 'Chính xác!' : 'Chưa đúng',
                                    style: TextStyle(
                                      color: _correct
                                          ? const Color(0xFF155B3D)
                                          : QTJPColors.red,
                                      fontWeight: FontWeight.w900,
                                      fontSize: 20,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    '${_word.word} · ${_word.hiragana}\n${_word.meaning}',
                                    style: TextStyle(
                                      color: _correct
                                          ? const Color(0xFF155B3D)
                                          : context.qtjp.heading,
                                      height: 1.7,
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  FilledButton(
                                    key: const ValueKey('practice-next'),
                                    onPressed: _next,
                                    child: Text(
                                      _index == _words.length - 1
                                          ? 'Xem kết quả'
                                          : 'Từ tiếp theo',
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          if (!_checked && !_busy)
                            TextButton(
                              onPressed: () => _check(false),
                              child: const Text('Chưa biết · Xem đáp án'),
                            ),
                          if (_mode == VocabularyMode.fill &&
                              _fillAnswer.isEmpty)
                            TextButton(
                              onPressed: _busy ? null : _next,
                              child: const Text('Bỏ qua từ này'),
                            ),
                        ],
                      ],
                      if (_busy) const LinearProgressIndicator(),
                      if (_error != null)
                        Padding(
                          padding: const EdgeInsets.all(12),
                          child: Text(
                            _error!,
                            style: const TextStyle(color: QTJPColors.red),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
    ),
  );

  Widget _autoSettings() => Card(
    child: Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        children: [
          for (final front in [true, false])
            Row(
              children: [
                Expanded(
                  child: Text(front ? 'Mặt trước (giây)' : 'Mặt sau (giây)'),
                ),
                IconButton(
                  onPressed: _running
                      ? null
                      : () => setState(() {
                          if (front) {
                            _frontSeconds = (_frontSeconds - 1).clamp(1, 15);
                          } else {
                            _backSeconds = (_backSeconds - 1).clamp(1, 15);
                          }
                        }),
                  icon: const Icon(Icons.remove),
                ),
                Text('${front ? _frontSeconds : _backSeconds}'),
                IconButton(
                  onPressed: _running
                      ? null
                      : () => setState(() {
                          if (front) {
                            _frontSeconds = (_frontSeconds + 1).clamp(1, 15);
                          } else {
                            _backSeconds = (_backSeconds + 1).clamp(1, 15);
                          }
                        }),
                  icon: const Icon(Icons.add),
                ),
              ],
            ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Nghe từ vựng'),
            value: _readWord,
            onChanged: _running ? null : (v) => setState(() => _readWord = v),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Nghe câu ví dụ'),
            value: _readExample,
            onChanged: _running
                ? null
                : (v) => setState(() => _readExample = v),
          ),
          Row(
            children: [
              const Expanded(child: Text('Số lần nghe lại')),
              IconButton(
                onPressed: _running
                    ? null
                    : () => setState(() => _repeat = (_repeat - 1).clamp(1, 5)),
                icon: const Icon(Icons.remove),
              ),
              Text('$_repeat'),
              IconButton(
                onPressed: _running
                    ? null
                    : () => setState(() => _repeat = (_repeat + 1).clamp(1, 5)),
                icon: const Icon(Icons.add),
              ),
            ],
          ),
        ],
      ),
    ),
  );
}
