import 'package:flutter/material.dart';

import '../../core/widgets/kyuto_scaffold.dart';

import '../../app/app_controller.dart';
import '../../core/theme/qtjp_colors.dart';
import '../../core/network/api_client.dart';
import '../../core/widgets/api_error_view.dart';
import '../../core/widgets/qtjp_feature_intro.dart';
import '../home/widgets/jlpt_level_selector.dart';
import 'data/flashcard_repository.dart';
import 'flashcard_study_screen.dart';
import 'flashcard_editor_screen.dart';
import 'models/flashcard_deck.dart';

class FlashcardScreen extends StatefulWidget {
  const FlashcardScreen({
    required this.initialLevel,
    this.repository,
    this.vocabularyOnly = false,
    super.key,
  });
  final String initialLevel;
  final FlashcardRepository? repository;
  final bool vocabularyOnly;

  @override
  State<FlashcardScreen> createState() => _FlashcardScreenState();
}

class _FlashcardScreenState extends State<FlashcardScreen> {
  late String _level;
  FlashcardRepository? _repository;
  Future<List<FlashcardDeck>>? _decks;
  String? _opening;
  Object? _openError;
  int? _sessionVersion;
  AppController? _app;
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    _level = widget.initialLevel;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final app = widget.repository == null ? AppScope.of(context) : null;
    _app = app;
    _repository ??= widget.repository ?? ApiFlashcardRepository(app!.api);
    if (!_initialized || _sessionVersion != app?.api.sessionVersion) {
      _initialized = true;
      _sessionVersion = app?.api.sessionVersion;
      _opening = null;
      _openError = null;
      _decks = _repository!.getDecks(_level);
    }
  }

  void _reload() => setState(() {
    _openError = null;
    _decks = _repository!.getDecks(_level);
  });

  void _selectLevel(String level) {
    if (_level == level || _opening != null) return;
    _level = level;
    _reload();
  }

  Future<void> _openDeck(FlashcardDeck deck, {bool vocabulary = false}) async {
    if (_opening != null) return;
    final session = _app?.api.sessionVersion;
    setState(() {
      _opening = deck.id;
      _openError = null;
    });
    try {
      final words = await _repository!.getWords(deck);
      final progress = _repository is ApiFlashcardRepository
          ? await (_repository as ApiFlashcardRepository).getProgress()
          : <int, bool>{};
      if (!mounted || session != _app?.api.sessionVersion) return;
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => FlashcardStudyScreen(
            deck: deck.withWords(words),
            initiallyShowVocabulary: vocabulary || widget.vocabularyOnly,
            sessionVersion: session,
            initialProgress: progress,
            onAnswer: deck.isSample
                ? null
                : (word, remembered) async {
                    if (session != _app?.api.sessionVersion) {
                      throw const ApiException(
                        'Phiên học đã thay đổi.',
                        status: 401,
                      );
                    }
                    await _repository!.saveProgress(word, remembered);
                  },
          ),
        ),
      );
    } catch (error) {
      if (mounted && session == _app?.api.sessionVersion) {
        setState(() => _openError = error);
      }
    } finally {
      if (mounted && session == _app?.api.sessionVersion) {
        setState(() => _opening = null);
      }
    }
  }

  Future<void> _edit([FlashcardDeck? deck]) async {
    final repository = _repository;
    if (repository is! ApiFlashcardRepository || _opening != null) return;
    await Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (_) => FlashcardEditorScreen(
          repository: repository,
          level: _level,
          deck: deck,
        ),
      ),
    );
    if (mounted) _reload();
  }

  @override
  Widget build(BuildContext context) {
    final sample = _repository is DemoFlashcardRepository;
    return KyutoScaffold(
      backgroundColor: Theme.of(context).brightness == Brightness.dark
          ? const Color(0xFF0B1425)
          : const Color(0xFFEAF0F8),
      appBar: AppBar(
        title: Text(
          widget.vocabularyOnly ? 'Từ vựng theo cấp độ' : 'Flashcard từ vựng',
        ),
        actions: [
          IconButton(
            onPressed: _opening == null ? _reload : null,
            icon: const Icon(Icons.refresh),
            tooltip: 'Tải lại bộ thẻ',
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
                  if (!widget.vocabularyOnly)
                    const QTJPFeatureIntro(QTJPFeature.flashcard)
                  else ...[
                    Text(
                      'TỪ VỰNG JLPT',
                      style: TextStyle(
                        color: context.qtjp.blue,
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Học từ theo từng bài',
                      style: TextStyle(
                        color: context.qtjp.heading,
                        fontSize: 26,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                  JlptLevelSelector(
                    selectedLevel: _level,
                    onSelected: _selectLevel,
                  ),
                  const SizedBox(height: 14),
                  if (_repository is ApiFlashcardRepository) ...[
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        OutlinedButton.icon(
                          key: const ValueKey('deck-create'),
                          onPressed:
                              _app?.isAuthenticated == true && _opening == null
                              ? () => _edit()
                              : null,
                          icon: const Icon(Icons.add_rounded),
                          label: const Text('Tạo bộ từ cá nhân'),
                        ),
                        TextButton(
                          onPressed: _opening == null
                              ? () => _openDeck(
                                  FlashcardDeck(
                                    id: 'all',
                                    name: 'Tổng hợp từ vựng $_level',
                                    level: _level,
                                    description: '',
                                    words: const [],
                                  ),
                                  vocabulary: widget.vocabularyOnly,
                                )
                              : null,
                          child: Text('Học toàn bộ $_level'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                  ],
                  Text(
                    'Cấp độ đang chọn: $_level',
                    style: TextStyle(
                      color: context.qtjp.heading,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  if (_openError != null)
                    ApiErrorView(error: _openError!, onRetry: _reload),
                  const SizedBox(height: 20),
                  FutureBuilder<List<FlashcardDeck>>(
                    future: _decks,
                    builder: (context, snapshot) {
                      if (snapshot.connectionState != ConnectionState.done) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      if (snapshot.hasError) {
                        return ApiErrorView(
                          error: snapshot.error!,
                          onRetry: _reload,
                        );
                      }
                      final decks = snapshot.data ?? [];
                      if (decks.isEmpty) {
                        return Card(
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Column(
                              children: [
                                Icon(
                                  Icons.style_outlined,
                                  size: 40,
                                  color: context.qtjp.blue,
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  sample
                                      ? 'Chưa có bộ thẻ mẫu cho $_level'
                                      : 'Chưa có bộ thẻ cho $_level trên máy chủ.',
                                  textAlign: TextAlign.center,
                                ),
                                if (sample)
                                  OutlinedButton(
                                    onPressed: () => _selectLevel('N5'),
                                    child: const Text('Khám phá bộ mẫu N5'),
                                  ),
                              ],
                            ),
                          ),
                        );
                      }
                      return Column(
                        children: [
                          for (final deck in decks)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 16),
                              child: Card(
                                color: context.qtjp.surface,
                                elevation: 2,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(22),
                                  side: BorderSide(color: context.qtjp.border),
                                ),
                                clipBehavior: Clip.antiAlias,
                                child: InkWell(
                                  key: ValueKey(deck.id),
                                  onTap: _opening == null && deck.count > 0
                                      ? () => _openDeck(deck)
                                      : null,
                                  child: Padding(
                                    padding: const EdgeInsets.all(22),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.stretch,
                                      children: [
                                        Text(
                                          '${deck.level} · ${deck.isSample ? 'BỘ MẪU' : 'QTJP LEARNING'}',
                                          style: const TextStyle(
                                            color: QTJPColors.red,
                                            fontWeight: FontWeight.w900,
                                          ),
                                        ),
                                        const SizedBox(height: 12),
                                        Text(
                                          deck.name,
                                          style: TextStyle(
                                            color: context.qtjp.heading,
                                            fontSize: 22,
                                            fontWeight: FontWeight.w800,
                                          ),
                                        ),
                                        if (!deck.systemDeck &&
                                            deck.ownerUserId != null &&
                                            '${deck.ownerUserId}' ==
                                                '${_app?.user?['id']}')
                                          Align(
                                            alignment: Alignment.centerLeft,
                                            child: TextButton.icon(
                                              onPressed: _opening == null
                                                  ? () => _edit(deck)
                                                  : null,
                                              icon: const Icon(
                                                Icons.edit_outlined,
                                                size: 18,
                                              ),
                                              label: const Text(
                                                'Chỉnh sửa bộ từ',
                                              ),
                                            ),
                                          ),
                                        const SizedBox(height: 20),
                                        Wrap(
                                          spacing: 20,
                                          runSpacing: 8,
                                          alignment: WrapAlignment.spaceBetween,
                                          children: [
                                            Text('${deck.count} từ vựng'),
                                            if (_opening == deck.id)
                                              const SizedBox(
                                                width: 20,
                                                height: 20,
                                                child:
                                                    CircularProgressIndicator(
                                                      strokeWidth: 2,
                                                    ),
                                              )
                                            else
                                              Text(
                                                widget.vocabularyOnly
                                                    ? 'Xem từ vựng →'
                                                    : 'Bắt đầu học →',
                                                style: TextStyle(
                                                  color: context.qtjp.blue,
                                                  fontWeight: FontWeight.w800,
                                                ),
                                              ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
