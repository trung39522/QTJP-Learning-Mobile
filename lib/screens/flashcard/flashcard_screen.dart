import 'package:flutter/material.dart';

import '../../app/app_controller.dart';
import '../../core/theme/qtjp_colors.dart';
import '../../core/network/api_client.dart';
import '../../core/widgets/api_error_view.dart';
import '../home/widgets/jlpt_level_selector.dart';
import 'data/flashcard_repository.dart';
import 'flashcard_study_screen.dart';
import 'models/flashcard_deck.dart';

class FlashcardScreen extends StatefulWidget {
  const FlashcardScreen({
    required this.initialLevel,
    this.repository,
    super.key,
  });
  final String initialLevel;
  final FlashcardRepository? repository;

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

  Future<void> _openDeck(FlashcardDeck deck) async {
    if (_opening != null) return;
    final session = _app?.api.sessionVersion;
    setState(() {
      _opening = deck.id;
      _openError = null;
    });
    try {
      final words = await _repository!.getWords(deck);
      if (!mounted || session != _app?.api.sessionVersion) return;
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => FlashcardStudyScreen(
            deck: deck.withWords(words),
            sessionVersion: session,
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

  @override
  Widget build(BuildContext context) {
    final sample = _repository is DemoFlashcardRepository;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Flashcard từ vựng'),
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
                  const Text(
                    'FLASHCARD JLPT',
                    style: TextStyle(
                      color: QTJPColors.red,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.5,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Học từ vựng theo chủ đề',
                    style: TextStyle(
                      color: QTJPColors.navyDark,
                      fontSize: 28,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    sample
                        ? 'Bộ thẻ mẫu dùng để kiểm thử, không đồng bộ tài khoản.'
                        : 'Bộ thẻ từ website QTJP. Tiến độ được lưu vào tài khoản sau mỗi lần tự đánh giá.',
                    style: const TextStyle(
                      color: QTJPColors.muted,
                      height: 1.6,
                    ),
                  ),
                  const SizedBox(height: 20),
                  JlptLevelSelector(
                    selectedLevel: _level,
                    onSelected: _selectLevel,
                  ),
                  const SizedBox(height: 14),
                  Text(
                    'Cấp độ đang chọn: $_level',
                    style: const TextStyle(
                      color: QTJPColors.navy,
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
                                const Icon(
                                  Icons.style_outlined,
                                  size: 40,
                                  color: QTJPColors.blue,
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
                                          style: const TextStyle(
                                            color: QTJPColors.navy,
                                            fontSize: 22,
                                            fontWeight: FontWeight.w800,
                                          ),
                                        ),
                                        if (deck.description.isNotEmpty) ...[
                                          const SizedBox(height: 8),
                                          Text(
                                            deck.description,
                                            style: const TextStyle(
                                              color: QTJPColors.muted,
                                              height: 1.6,
                                            ),
                                          ),
                                        ],
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
                                              const Text(
                                                'Bắt đầu học →',
                                                style: TextStyle(
                                                  color: QTJPColors.blue,
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
