import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';

import '../../core/widgets/kyuto_scaffold.dart';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../app/app_controller.dart';
import '../../core/theme/qtjp_colors.dart';
import '../../core/widgets/api_error_view.dart';
import '../alphabet/services/kana_speech.dart';
import '../ai/learning_ai_repository.dart';
import '../ai/learning_ai_screen.dart';
import 'dictionary_entry_card.dart';
import 'dictionary_input_tools.dart';
import 'dictionary_repository.dart';

class DictionaryScreen extends StatefulWidget {
  const DictionaryScreen({
    this.speech,
    this.voice,
    this.embedded = false,
    super.key,
  });
  final bool embedded;
  final KanaSpeech? speech;
  final DictionaryVoice? voice;
  @override
  State<DictionaryScreen> createState() => _DictionaryScreenState();
}

class _DictionaryScreenState extends State<DictionaryScreen> {
  final _input = TextEditingController(text: '学校');
  final _storage = const FlutterSecureStorage();
  late final _speech = widget.speech ?? DeviceKanaSpeech();
  Future<List<DictionaryEntry>>? _results;
  late DictionaryRepository _repository;
  String _keyword = '学校', _language = 'ja-JP';
  bool _listening = false;
  List<Map<String, dynamic>> _history = [];
  Future<void> _historyWrite = Future.value();
  int _historyRevision = 0;

  @override
  void initState() {
    super.initState();
    unawaited(_restoreHistory());
  }

  Future<void> _restoreHistory() async {
    final revision = _historyRevision;
    try {
      final raw = jsonDecode(
        await _storage.read(key: 'qtjp.dictionary.history') ?? '[]',
      ) as List;
      final cutoff = DateTime.now()
          .subtract(const Duration(hours: 24))
          .millisecondsSinceEpoch;
      final history = raw
          .whereType<Map>()
          .where(
            (e) => e['word'] is String && e['at'] is int && e['at'] > cutoff,
          )
          .map((e) => Map<String, dynamic>.from(e))
          .take(12)
          .toList();
      if (mounted && revision == _historyRevision) {
        setState(() => _history = history);
      }
    } catch (_) {
      /* Search remains available without local history. */
    }
  }

  void _saveHistory() {
    _historyRevision++;
    final value = jsonEncode(_history);
    _historyWrite = _historyWrite.then((_) async {
      try {
        await _storage.write(key: 'qtjp.dictionary.history', value: value);
      } catch (_) {
        /* Optional local history. */
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _repository = DictionaryRepository(AppScope.of(context).api);
    _results ??= _repository.search(_keyword);
  }

  void _search([String? keyword]) {
    FocusScope.of(context).unfocus();
    if (keyword != null) _input.text = keyword;
    setState(() {
      _keyword = _input.text.trim();
      _results = _repository.search(_keyword);
      if (_keyword.isNotEmpty) {
        _history = [
          {'word': _keyword, 'at': DateTime.now().millisecondsSinceEpoch},
          ..._history.where((e) => e['word'] != _keyword),
        ].take(12).toList();
        _saveHistory();
      }
    });
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

  Future<void> _voice() async {
    if (_listening) return;
    setState(() => _listening = true);
    try {
      final candidates = await (widget.voice ?? DictionaryVoice()).recognize(
        _language,
      );
      if (!mounted || candidates.isEmpty) return;
      setState(() => _listening = false);
      final result = await showDialog<String>(
        context: context,
        builder: (context) => SimpleDialog(
          title: const Text('Chọn từ vừa nói'),
          children: [
            for (final word in candidates)
              SimpleDialogOption(
                onPressed: () => Navigator.pop(context, word),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Text(word, style: const TextStyle(fontSize: 20)),
                ),
              ),
          ],
        ),
      );
      if (mounted && result != null) _search(result);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              error is FormatException
                  ? error.message
                  : 'Không thể tra giọng nói lúc này.',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _listening = false);
    }
  }

  Future<void> _handwriting() async {
    final word = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (_) => const DictionaryHandwritingSheet(),
    );
    if (mounted && word != null) _search(word);
  }

  void _ai() => unawaited(
    Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (_) => LearningAiScreen(
          tool: LearningAiTool.dictionary,
          initialText: _input.text.trim(),
        ),
      ),
    ),
  );

  @override
  void dispose() {
    _input.dispose();
    unawaited(_speech.stop());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => KyutoScaffold(
    showAssistant: !widget.embedded,
    appBar: AppBar(
      automaticallyImplyLeading: !widget.embedded,
      title: const Text('Từ điển'),
      actions: [
        Padding(
          padding: const EdgeInsets.only(right: 16),
          child: SegmentedButton<String>(
            showSelectedIcon: false,
            style: SegmentedButton.styleFrom(
              visualDensity: VisualDensity.compact,
              padding: const EdgeInsets.symmetric(horizontal: 10),
            ),
            segments: const [
              ButtonSegment(value: 'ja-JP', label: Text('JA')),
              ButtonSegment(value: 'vi-VN', label: Text('VI')),
            ],
            selected: {_language},
            onSelectionChanged: _listening
                ? null
                : (s) => setState(() => _language = s.single),
          ),
        ),
      ],
    ),
    body: SafeArea(
      top: false,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      TextField(
                        key: const ValueKey('dictionary-query'),
                        controller: _input,
                        textInputAction: TextInputAction.search,
                        onSubmitted: (_) => _search(),
                        decoration: InputDecoration(
                          hintText: _language == 'ja-JP'
                              ? 'Tiếng Nhật hoặc romaji'
                              : 'Nghĩa tiếng Việt',
                          filled: true,
                          fillColor: context.qtjp.surface,
                          prefixIcon: const Icon(Icons.translate_rounded),
                          suffixIcon: IconButton(
                            tooltip: 'Tra cứu',
                            onPressed: _search,
                            icon: const Icon(Icons.search),
                            style: IconButton.styleFrom(
                              foregroundColor: context.qtjp.blue,
                            ),
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _tool(
                            'Giọng nói',
                            _listening ? Icons.hearing : Icons.mic_none_rounded,
                            _listening ? null : _voice,
                          ),
                          const SizedBox(width: 8),
                          _tool('Viết tay', Icons.draw_outlined, _handwriting),
                          const SizedBox(width: 8),
                          _tool(
                            'Tra với AI',
                            Icons.auto_awesome_outlined,
                            _ai,
                            key: const ValueKey('dictionary-ai'),
                          ),
                        ],
                      ),
                      if (_listening)
                        const Padding(
                          padding: EdgeInsets.only(top: 8),
                          child: LinearProgressIndicator(),
                        ),
                      const SizedBox(height: 12),
                      Wrap(
                        alignment: WrapAlignment.spaceBetween,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text(
                            'TỪ VỰNG',
                            style: TextStyle(
                              color: context.qtjp.heading,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1,
                            ),
                          ),
                          if (_history.isNotEmpty)
                            TextButton(
                              onPressed: () => setState(() {
                                _history = [];
                                _saveHistory();
                              }),
                              child: const Text('Xóa lịch sử'),
                            ),
                        ],
                      ),
                      if (_history.isNotEmpty)
                        SizedBox(
                          height: 44,
                          child: ListView.separated(
                            scrollDirection: Axis.horizontal,
                            itemCount: _history.length,
                            separatorBuilder: (_, _) =>
                                const SizedBox(width: 8),
                            itemBuilder: (context, i) => ActionChip(
                              avatar: const Icon(Icons.history, size: 16),
                              label: Text(_history[i]['word'] as String),
                              onPressed: () =>
                                  _search(_history[i]['word'] as String),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              FutureBuilder<List<DictionaryEntry>>(
                future: _results,
                builder: (context, snapshot) {
                  if (snapshot.connectionState != ConnectionState.done) {
                    return const SliverFillRemaining(
                      hasScrollBody: false,
                      child: Center(child: CircularProgressIndicator()),
                    );
                  }
                  if (snapshot.hasError) {
                    return SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: ApiErrorView(
                          error: snapshot.error!,
                          onRetry: _search,
                        ),
                      ),
                    );
                  }
                  final results = snapshot.data ?? [];
                  if (results.isEmpty) {
                    return SliverFillRemaining(
                      hasScrollBody: false,
                      child: Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Text(
                            _keyword.isEmpty
                                ? 'Nhập từ cần tra cứu.'
                                : 'Không tìm thấy “$_keyword”. Hãy thử cách viết khác.',
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                    );
                  }
                  return SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                    sliver: SliverList.builder(
                      itemCount: results.length + 1,
                      itemBuilder: (context, index) {
                        if (index == 0) {
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: Text(
                              '${results.length} kết quả · $_keyword',
                              style: TextStyle(
                                color: context.qtjp.muted,
                                fontSize: 12,
                              ),
                            ),
                          );
                        }
                        return DictionaryEntryCard(
                          key: ValueKey('dictionary-result-${index - 1}'),
                          entry: results[index - 1],
                          initiallyExpanded: index == 1,
                          onSpeak: _speak,
                          onSearch: _search,
                        );
                      },
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    ),
  );

  Widget _tool(String label, IconData icon, VoidCallback? onTap, {Key? key}) =>
      Expanded(
        child: Material(
          color: context.qtjp.soft,
          borderRadius: BorderRadius.circular(9),
          child: InkWell(
            key: key,
            onTap: onTap,
            borderRadius: BorderRadius.circular(9),
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 44),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  vertical: 10,
                  horizontal: 4,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(icon, color: context.qtjp.blue, size: 17),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: context.qtjp.heading,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
}
