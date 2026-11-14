import 'package:flutter/material.dart';

import '../../core/widgets/kyuto_scaffold.dart';

import '../../app/app_controller.dart';
import '../../core/network/api_client.dart';
import '../../core/theme/qtjp_colors.dart';
import '../profile/models/account_presentation.dart';
import 'data/flashcard_repository.dart';
import 'models/flashcard_deck.dart';

class FlashcardEditorScreen extends StatefulWidget {
  const FlashcardEditorScreen({
    required this.repository,
    required this.level,
    this.deck,
    super.key,
  });
  final ApiFlashcardRepository repository;
  final String level;
  final FlashcardDeck? deck;
  @override
  State<FlashcardEditorScreen> createState() => _FlashcardEditorScreenState();
}

class _FlashcardEditorScreenState extends State<FlashcardEditorScreen> {
  late FlashcardDeck? _deck = widget.deck;
  late final _name = TextEditingController(text: _deck?.name);
  late final _category = TextEditingController(text: _deck?.category);
  late final _description = TextEditingController(text: _deck?.description);
  final _fields = {
    for (final name in [
      'word',
      'kanji',
      'hiragana',
      'romaji',
      'hanViet',
      'meaning',
      'partOfSpeech',
    ])
      name: TextEditingController(),
  };
  static const _labels = {
    'word': 'Từ vựng *',
    'kanji': 'Kanji',
    'hiragana': 'Hiragana',
    'romaji': 'Romaji',
    'hanViet': 'Hán Việt',
    'meaning': 'Nghĩa tiếng Việt *',
    'partOfSpeech': 'Loại từ',
  };
  List<FlashcardWord> _words = [];
  bool _busy = false;
  Object? _error;
  late final _session = widget.repository.api.sessionVersion;
  bool get _valid =>
      _session == widget.repository.api.sessionVersion &&
      widget.repository.api.token != null;
  @override
  void initState() {
    super.initState();
    if (_deck != null) _load();
  }

  @override
  void dispose() {
    _name.dispose();
    _category.dispose();
    _description.dispose();
    for (final c in _fields.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _busy = true);
    try {
      final words = await widget.repository.getWords(_deck!);
      if (mounted && _valid) setState(() => _words = words);
    } catch (e) {
      if (mounted && _valid) setState(() => _error = e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _run(Future<void> Function() action) async {
    if (_busy || !_valid) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await action();
    } catch (e) {
      if (mounted && _valid) setState(() => _error = e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<bool> _confirm(String title, String message) async =>
      await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(title),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Hủy'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Xóa', style: TextStyle(color: QTJPColors.red)),
            ),
          ],
        ),
      ) ==
      true;
  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final owned =
        _deck == null ||
        (!_deck!.systemDeck &&
            _deck!.ownerUserId != null &&
            '${_deck!.ownerUserId}' == '${app.user?['id']}');
    return KyutoScaffold(
      appBar: AppBar(
        title: Text(_deck == null ? 'Tạo bộ từ cá nhân' : 'Chỉnh sửa bộ từ'),
      ),
      body: SafeArea(
        top: false,
        child: !_valid || !owned
            ? const Center(
                child: Text('Bạn không có quyền chỉnh sửa bộ từ này.'),
              )
            : SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 640),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          'Bộ từ của tôi · ${widget.level}',
                          style: TextStyle(
                            color: context.qtjp.heading,
                            fontSize: 24,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          AccountPresentation(app.user).vipAt(DateTime.now())
                              ? 'Thành viên VIP · Bộ từ cá nhân không giới hạn'
                              : 'Thành viên FREE · Tối đa 3 bộ từ cá nhân',
                          style: TextStyle(
                            color: context.qtjp.muted,
                            height: 1.6,
                          ),
                        ),
                        const SizedBox(height: 20),
                        for (final field in [
                          (controller: _name, label: 'Tên bộ từ *'),
                          (controller: _category, label: 'Chủ đề'),
                          (controller: _description, label: 'Mô tả'),
                        ])
                          Padding(
                            padding: const EdgeInsets.only(bottom: 14),
                            child: TextField(
                              controller: field.controller,
                              enabled: !_busy,
                              maxLines: field.controller == _description
                                  ? 3
                                  : 1,
                              decoration: InputDecoration(
                                labelText: field.label,
                              ),
                            ),
                          ),
                        FilledButton.icon(
                          key: const ValueKey('deck-save'),
                          onPressed: _busy
                              ? null
                              : () => _run(() async {
                                  if (_name.text.trim().isEmpty) {
                                    throw const ApiException(
                                      'Vui lòng nhập tên bộ từ.',
                                    );
                                  }
                                  final saved = await widget.repository
                                      .saveDeck(
                                        id: _deck?.id,
                                        level: widget.level,
                                        name: _name.text,
                                        category: _category.text,
                                        description: _description.text,
                                      );
                                  if (context.mounted && _valid) {
                                    setState(() => _deck = saved);
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('Đã lưu bộ từ.'),
                                      ),
                                    );
                                  }
                                }),
                          icon: const Icon(Icons.save_outlined),
                          label: Text(
                            _deck == null ? 'Tạo bộ từ' : 'Lưu thông tin',
                          ),
                        ),
                        if (_deck != null) ...[
                          const Divider(height: 36),
                          Text(
                            'Thêm từ vựng',
                            style: TextStyle(
                              color: context.qtjp.heading,
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 16),
                          for (final field in _fields.entries)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: TextField(
                                key: ValueKey('custom-word-${field.key}'),
                                controller: field.value,
                                enabled: !_busy,
                                decoration: InputDecoration(
                                  labelText: _labels[field.key],
                                ),
                              ),
                            ),
                          OutlinedButton.icon(
                            key: const ValueKey('custom-word-add'),
                            onPressed: _busy
                                ? null
                                : () => _run(() async {
                                    if (_fields['word']!.text.trim().isEmpty ||
                                        _fields['meaning']!.text
                                            .trim()
                                            .isEmpty) {
                                      throw const ApiException(
                                        'Vui lòng nhập từ vựng và nghĩa.',
                                      );
                                    }
                                    await widget.repository.addWord(_deck!.id, {
                                      for (final entry in _fields.entries)
                                        entry.key: entry.value.text.trim(),
                                    });
                                    if (!mounted || !_valid) return;
                                    for (final c in _fields.values) {
                                      c.clear();
                                    }
                                    final words = await widget.repository
                                        .getWords(_deck!);
                                    if (mounted && _valid) {
                                      setState(() => _words = words);
                                    }
                                  }),
                            icon: const Icon(Icons.add_rounded),
                            label: const Text('Thêm từ vào bộ'),
                          ),
                          const SizedBox(height: 24),
                          Text(
                            '${_words.length} từ trong bộ',
                            style: TextStyle(
                              color: context.qtjp.heading,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          for (final word in _words)
                            Card(
                              child: ListTile(
                                title: Text(word.word),
                                subtitle: Text(
                                  '${word.hiragana}\n${word.meaning}',
                                ),
                                trailing: IconButton(
                                  tooltip: 'Xóa từ khỏi bộ',
                                  icon: const Icon(
                                    Icons.delete_outline,
                                    color: QTJPColors.red,
                                  ),
                                  onPressed: _busy || word.id == null
                                      ? null
                                      : () async {
                                          if (!await _confirm(
                                                'Xóa từ?',
                                                'Xóa ${word.word} khỏi bộ từ này?',
                                              ) ||
                                              !mounted ||
                                              !_valid) {
                                            return;
                                          }
                                          await _run(() async {
                                            await widget.repository.removeWord(
                                              _deck!.id,
                                              word.id!,
                                            );
                                            if (mounted && _valid) {
                                              setState(
                                                () => _words.remove(word),
                                              );
                                            }
                                          });
                                        },
                                ),
                              ),
                            ),
                          const SizedBox(height: 24),
                          TextButton.icon(
                            onPressed: _busy
                                ? null
                                : () async {
                                    if (!await _confirm(
                                          'Xóa bộ từ?',
                                          'Xóa toàn bộ bộ từ cá nhân này?',
                                        ) ||
                                        !mounted ||
                                        !_valid) {
                                      return;
                                    }
                                    await _run(() async {
                                      await widget.repository.deleteDeck(
                                        _deck!.id,
                                      );
                                      if (context.mounted && _valid) {
                                        Navigator.pop(context, true);
                                      }
                                    });
                                  },
                            icon: const Icon(
                              Icons.delete_outline,
                              color: QTJPColors.red,
                            ),
                            label: const Text(
                              'Xóa bộ từ',
                              style: TextStyle(color: QTJPColors.red),
                            ),
                          ),
                        ],
                        if (_busy) const LinearProgressIndicator(),
                        if (_error != null)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            child: Text(
                              '$_error',
                              style: const TextStyle(color: QTJPColors.red),
                            ),
                          ),
                        const SizedBox(height: 24),
                      ],
                    ),
                  ),
                ),
              ),
      ),
    );
  }
}
