enum KanaScript { hiragana, katakana }

class Kana {
  const Kana(this.hiragana, this.romaji);

  final String hiragana;
  final String romaji;

  // The kana used here have corresponding katakana 0x60 code points later.
  String get katakana =>
      String.fromCharCodes(hiragana.runes.map((codePoint) => codePoint + 0x60));

  String text(KanaScript script) =>
      script == KanaScript.hiragana ? hiragana : katakana;
}

class KanaGroup {
  KanaGroup(this.title, this.columns, List<(String, String)> rows)
    : cells = List.unmodifiable(
        rows.expand((row) {
          final characters = row.$1.split(' ');
          final readings = row.$2.split(' ');
          assert(characters.length == readings.length);
          return List.generate(
            characters.length,
            (index) => characters[index] == '_'
                ? null
                : Kana(characters[index], readings[index]),
          );
        }),
      );

  final String title;
  final int columns;
  final List<Kana?> cells;
}

// Content and row order follow the website's JapaneseAlphabet page.
final kanaGroups = List<KanaGroup>.unmodifiable([
  KanaGroup('Âm trong · Seion', 5, const [
    ('あ い う え お', 'a i u e o'),
    ('か き く け こ', 'ka ki ku ke ko'),
    ('さ し す せ そ', 'sa shi su se so'),
    ('た ち つ て と', 'ta chi tsu te to'),
    ('な に ぬ ね の', 'na ni nu ne no'),
    ('は ひ ふ へ ほ', 'ha hi fu he ho'),
    ('ま み む め も', 'ma mi mu me mo'),
    ('や _ ゆ _ よ', 'ya _ yu _ yo'),
    ('ら り る れ ろ', 'ra ri ru re ro'),
    ('わ _ _ _ を', 'wa _ _ _ wo'),
    ('ん _ _ _ _', 'n _ _ _ _'),
  ]),
  KanaGroup('Âm đục · Bán đục', 5, const [
    ('が ぎ ぐ げ ご', 'ga gi gu ge go'),
    ('ざ じ ず ぜ ぞ', 'za ji zu ze zo'),
    ('だ ぢ づ で ど', 'da ji zu de do'),
    ('ば び ぶ べ ぼ', 'ba bi bu be bo'),
    ('ぱ ぴ ぷ ぺ ぽ', 'pa pi pu pe po'),
  ]),
  KanaGroup('Âm ghép · Yōon', 3, const [
    ('きゃ きゅ きょ', 'kya kyu kyo'),
    ('しゃ しゅ しょ', 'sha shu sho'),
    ('ちゃ ちゅ ちょ', 'cha chu cho'),
    ('にゃ にゅ にょ', 'nya nyu nyo'),
    ('ひゃ ひゅ ひょ', 'hya hyu hyo'),
    ('みゃ みゅ みょ', 'mya myu myo'),
    ('りゃ りゅ りょ', 'rya ryu ryo'),
    ('ぎゃ ぎゅ ぎょ', 'gya gyu gyo'),
    ('じゃ じゅ じょ', 'ja ju jo'),
    ('びゃ びゅ びょ', 'bya byu byo'),
    ('ぴゃ ぴゅ ぴょ', 'pya pyu pyo'),
  ]),
]);

final allKana = List<Kana>.unmodifiable(
  kanaGroups.expand((group) => group.cells.whereType<Kana>()),
);
