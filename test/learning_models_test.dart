import 'package:flutter_test/flutter_test.dart';
import 'package:qtjp_mobile/screens/alphabet/models/kana.dart';
import 'package:qtjp_mobile/screens/flashcard/data/flashcard_repository.dart';
import 'package:qtjp_mobile/screens/flashcard/models/flashcard_session.dart';

void main() {
  test(
    'kana catalogue includes all three groups and corresponding scripts',
    () {
      expect(kanaGroups.map((group) => group.cells.whereType<Kana>().length), [
        46,
        25,
        33,
      ]);
      expect(allKana.map((kana) => kana.hiragana).toSet().length, 104);
      expect(allKana.map((kana) => kana.katakana).toSet().length, 104);
      expect(allKana.first.text(KanaScript.hiragana), 'あ');
      expect(allKana.first.text(KanaScript.katakana), 'ア');
      expect(allKana.firstWhere((kana) => kana.hiragana == 'ぢ').katakana, 'ヂ');
      expect(allKana.last.katakana, 'ピョ');
      expect(allKana.last.romaji, 'pyo');
      expect(kanaGroups.first.cells[36], isNull); // Blank slot in the ya row.
    },
  );

  test(
    'sample repository never labels N5 data as another JLPT level',
    () async {
      const repository = DemoFlashcardRepository();
      final decks = await repository.getDecks('N5');
      expect(decks, hasLength(2));
      expect(
        decks.every((deck) => deck.level == 'N5' && deck.words.isNotEmpty),
        isTrue,
      );
      for (final level in ['N4', 'N3', 'N2', 'N1']) {
        expect(await repository.getDecks(level), isEmpty);
      }
    },
  );

  test(
    'session requires a revealed card and reviews only forgotten words',
    () async {
      final decks = await const DemoFlashcardRepository().getDecks('N5');
      final words = decks.first.words.take(2).toList();
      final session = FlashcardSession(words);
      expect(session.answer(remembered: true), isFalse);
      expect(session.answered, 0);

      session.flip();
      expect(session.answer(remembered: false), isTrue);
      expect(session.isRevealed, isFalse);
      expect(session.current, words[1]);
      expect(session.progress, 0.5);
      expect(session.answer(remembered: false), isFalse);
      session.flip();
      session.answer(remembered: true);
      expect(session.isComplete, isTrue);
      expect(session.current, isNull);
      expect(session.remembered, 1);
      expect(session.progress, 1);
      expect(session.forgotten, [words.first]);
      session.flip();
      expect(session.answer(remembered: false), isFalse);
      expect(session.forgotten, [words.first]);

      final review = FlashcardSession(session.forgotten);
      expect(review.words, [words.first]);
      review.flip();
      review.answer(remembered: true);
      expect(review.isComplete, isTrue);
      expect(review.forgotten, isEmpty);
    },
  );

  test('an empty session has no current card and cannot be graded', () {
    final session = FlashcardSession([]);
    expect(session.isComplete, isTrue);
    expect(session.current, isNull);
    session.flip();
    expect(session.isRevealed, isFalse);
    expect(session.answer(remembered: true), isFalse);
  });
}
