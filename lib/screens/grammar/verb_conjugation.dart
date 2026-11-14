/// Uses an explicitly selected verb group, like the website's practice tool.
/// This is a rule-based reference, not a dictionary that infers a verb's group.
List<String> conjugateVerb(String input, String group) {
  final word = input.trim();
  if (word.isEmpty) {
    throw const FormatException('Hãy nhập động từ dạng từ điển.');
  }
  if (group == 'kuru') {
    if (word != '来る' && word != 'くる') {
      throw const FormatException('Nhóm này dành cho 来る hoặc くる.');
    }
    return [
      '来る（くる）',
      '来ない（こない）',
      '来て（きて）',
      '来た（きた）',
      '来よう（こよう）',
      '来られる（こられる）',
      '来れば（くれば）',
      '来い（こい）',
      '来るな（くるな）',
      '来られる（こられる）',
      '来させる（こさせる）',
      '来させられる（こさせられる）',
    ];
  }
  if (group == 'suru') {
    if (!word.endsWith('する')) {
      throw const FormatException('Nhập する hoặc danh từ + する, ví dụ 勉強する.');
    }
    final stem = word.substring(0, word.length - 2);
    return [
      word,
      '$stemしない',
      '$stemして',
      '$stemした',
      '$stemしよう',
      '$stemできる',
      '$stemすれば',
      '$stemしろ／$stemせよ',
      '$wordな',
      '$stemされる',
      '$stemさせる',
      '$stemさせられる',
    ];
  }
  final stem = word.substring(0, word.length - 1);
  if (group == 'ichidan') {
    if (!word.endsWith('る')) {
      throw const FormatException(
        'Động từ nhóm II cần kết thúc bằng る, ví dụ 食べる.',
      );
    }
    return [
      word,
      '$stemない',
      '$stemて',
      '$stemた',
      '$stemよう',
      '$stemられる',
      '$stemれば',
      '$stemろ',
      '$wordな',
      '$stemられる',
      '$stemさせる',
      '$stemさせられる',
    ];
  }
  const rows = {
    'う': ['わ', 'い', 'え', 'お', 'って', 'った'],
    'く': ['か', 'き', 'け', 'こ', 'いて', 'いた'],
    'ぐ': ['が', 'ぎ', 'げ', 'ご', 'いで', 'いだ'],
    'す': ['さ', 'し', 'せ', 'そ', 'して', 'した'],
    'つ': ['た', 'ち', 'て', 'と', 'って', 'った'],
    'ぬ': ['な', 'に', 'ね', 'の', 'んで', 'んだ'],
    'ぶ': ['ば', 'び', 'べ', 'ぼ', 'んで', 'んだ'],
    'む': ['ま', 'み', 'め', 'も', 'んで', 'んだ'],
    'る': ['ら', 'り', 'れ', 'ろ', 'って', 'った'],
  };
  final row = rows[word.substring(word.length - 1)];
  if (group != 'godan' || row == null) {
    throw const FormatException(
      'Không nhận ra âm cuối nhóm I. Nhập dạng như 書く・読む・帰る.',
    );
  }
  final a = '$stem${row[0]}';
  final e = '$stem${row[2]}';
  final iku = word == '行く' || word == 'いく';
  return [
    word,
    '$aない',
    iku ? '$stemって' : '$stem${row[4]}',
    iku ? '$stemった' : '$stem${row[5]}',
    '$stem${row[3]}う',
    '$eる',
    '$eば',
    e,
    '$wordな',
    '$aれる',
    '$aせる',
    word.endsWith('す') ? '$aせられる' : '$aされる／$aせられる',
  ];
}
