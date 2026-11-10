import '../../core/network/api_client.dart';

class DigitalExamQuestion {
  const DigitalExamQuestion(this.mondai, this.question);
  final Map<String, dynamic> mondai, question;
  List<Map<String, dynamic>> get readingGroups {
    final layout = mondai['reading_layout'];
    if (layout == null) return const [];
    final groups = jsonObjects(jsonObject(layout)['groups'] ?? []);
    final number = question['number'];
    final matching = groups
        .where((g) => (g['question_numbers'] as List? ?? []).contains(number))
        .toList();
    // Shared passages can legitimately omit question_numbers. Never substitute
    // the first unrelated passage for a missing per-question group.
    if (matching.isNotEmpty) return matching;
    return jsonObject(layout)['mode'] == 'shared' ? groups : const [];
  }
}

DigitalExamQuestion? matchDigitalQuestion(
  Map<String, dynamic> document,
  Map<String, dynamic> backend,
) {
  final matches = <DigitalExamQuestion>[];
  for (final section in jsonObjects(document['sections'] ?? [])) {
    final title = jsonText(section, 'title');
    final listening = title.contains('聴解');
    final compatible = switch (backend['category']) {
      'LISTENING' => listening,
      'VOCAB' => !listening && (title.contains('文字') || title.contains('語彙')),
      'GRAMMAR' => !listening && title.contains('文法'),
      'READING' => !listening && title.contains('読解'),
      _ => false,
    };
    if (!compatible) continue;
    for (final mondai in jsonObjects(section['mondai'] ?? [])) {
      if (mondai['number'] != backend['problemNo']) continue;
      for (final question in jsonObjects(mondai['questions'] ?? [])) {
        if (question['number'] == backend['questionNo'] &&
            (question['sub_question_no'] ?? 0) ==
                (backend['subQuestionNo'] ?? 0)) {
          matches.add(DigitalExamQuestion(mondai, question));
        }
      }
    }
  }
  return matches.length == 1 ? matches.single : null;
}
