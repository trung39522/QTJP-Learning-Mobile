import 'flashcard_deck.dart';

/// In-memory practice only. Results are not persisted or sent to the server.
class FlashcardSession {
  FlashcardSession(List<FlashcardWord> words)
    : words = List.unmodifiable(words);

  final List<FlashcardWord> words;
  final List<FlashcardWord> _forgotten = [];
  int _index = 0;
  int _remembered = 0;
  bool _revealed = false;

  int get answered => _index;
  int get remembered => _remembered;
  List<FlashcardWord> get forgotten => List.unmodifiable(_forgotten);
  bool get isComplete => _index >= words.length;
  bool get isRevealed => _revealed;
  FlashcardWord? get current => isComplete ? null : words[_index];
  double get progress => words.isEmpty ? 0 : _index / words.length;

  void flip() {
    if (!isComplete) _revealed = !_revealed;
  }

  bool answer({required bool remembered}) {
    if (isComplete || !_revealed) return false;
    if (remembered) {
      _remembered++;
    } else {
      _forgotten.add(current!);
    }
    _index++;
    _revealed = false;
    return true;
  }
}
