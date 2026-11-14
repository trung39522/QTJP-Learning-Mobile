import 'dart:convert';

import 'package:flutter/material.dart';

import '../../core/network/api_client.dart';
import 'digital_exam.dart';
import 'exam_repository.dart';

class ExamQuestionView extends StatelessWidget {
  const ExamQuestionView({
    required this.question,
    required this.repository,
    this.document,
    this.documentUrl,
    this.onAnswer,
    this.enabled = true,
    this.review = false,
    super.key,
  });
  final Map<String, dynamic> question;
  final ExamRepository repository;
  final Map<String, dynamic>? document;
  final String? documentUrl;
  final ValueChanged<int?>? onAnswer;
  final bool enabled, review;

  Widget _text(Object? value, {bool emphasized = false}) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: review
        ? SelectableText(
            value?.toString() ?? '',
            style: TextStyle(
              fontSize: 18,
              height: 1.7,
              fontWeight: emphasized ? FontWeight.w800 : FontWeight.normal,
            ),
          )
        : Text(
            value?.toString() ?? '',
            style: TextStyle(
              fontSize: 18,
              height: 1.7,
              fontWeight: emphasized ? FontWeight.w800 : FontWeight.normal,
            ),
          ),
  );

  Widget _image(Object? value) {
    if (value == null || value == '') return const SizedBox.shrink();
    final data = value is Map<String, dynamic> ? value : {'file': value};
    try {
      final embedded = data['data_url'] ?? data['dataUrl'];
      final Widget image;
      if (embedded is String &&
          embedded.startsWith('data:image/') &&
          embedded.length < 12000000) {
        image = Image.memory(
          base64Decode(embedded.substring(embedded.indexOf(',') + 1)),
          errorBuilder: (_, _, _) => const Text('Không đọc được hình đề thi.'),
        );
      } else {
        final uri = repository.asset(
          jsonText(data, 'file'),
          relativeTo: documentUrl,
        );
        image = Image.network(
          uri.toString(),
          errorBuilder: (_, _, _) => const Text(
            'Không tải được hình. Kiểm tra kết nối rồi mở lại câu này.',
          ),
        );
      }
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: InteractiveViewer(minScale: 1, maxScale: 4, child: image),
      );
    } catch (_) {
      return const Text('Hình đề thi có địa chỉ hoặc dữ liệu không hợp lệ.');
    }
  }

  Widget _table(Map<String, dynamic> table) {
    final rows = table['rows'] as List? ?? [];
    final width = rows.fold<int>(
      0,
      (count, row) => row is List && row.length > count ? row.length : count,
    );
    if (width == 0) return const SizedBox.shrink();
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Table(
        defaultColumnWidth: const FixedColumnWidth(150),
        border: TableBorder.all(color: Colors.black26),
        children: [
          for (final row in rows.whereType<List>())
            TableRow(
              children: [
                for (var index = 0; index < width; index++)
                  Padding(
                    padding: const EdgeInsets.all(8),
                    child: Text(
                      index < row.length ? '${row[index] ?? ''}' : '',
                      style: const TextStyle(height: 1.6),
                    ),
                  ),
              ],
            ),
        ],
      ),
    );
  }

  List<Widget> _reading(Map<String, dynamic> group) {
    final tables = jsonObjects(group['native_tables'] ?? []);
    final items = jsonObjects(group['content_items'] ?? []);
    if (items.isNotEmpty) {
      return [
        for (final item in items)
          if (item['type'] == 'table' &&
              item['table_index'] is int &&
              (item['table_index'] as int) >= 0 &&
              (item['table_index'] as int) < tables.length)
            _table(tables[item['table_index'] as int])
          else if (item['type'] == 'line')
            _text(item['text']),
      ];
    }
    return [
      for (final line
          in (group['lines'] as List? ?? group['body_lines'] as List? ?? []))
        _text(line is Map ? line['text'] : line),
      for (final table in tables) _table(table),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final match = document == null
        ? null
        : matchDigitalQuestion(document!, question);
    final source = match?.question;
    final sourceChoices = jsonObjects(source?['choices'] ?? []);
    final choices = sourceChoices.isNotEmpty
        ? sourceChoices
              .map(
                (c) => {
                  'optionNo': c['number'],
                  'text': c['text'],
                  'imageUrl': c['imageUrl'],
                },
              )
              .toList()
        : jsonObjects(question['choices'] ?? []);
    final passage = question['passage'] == null
        ? null
        : jsonObject(question['passage']);
    final groups = match?.readingGroups ?? [];
    final text = source?['text'] ?? question[review ? 'questionText' : 'text'];
    final images =
        source?['images'] as List? ??
        (source?['image'] == null ? [] : [source!['image']]);
    final prompt = text?.toString().trim() ?? '';
    final hasPassage =
        passage != null &&
        (jsonText(passage, 'text').trim().isNotEmpty ||
            jsonText(passage, 'imageUrl').isNotEmpty);
    final hasSharedContent =
        groups.isNotEmpty ||
        hasPassage ||
        (match?.mondai['content_blocks'] as List? ?? []).isNotEmpty ||
        (match?.mondai['images'] as List? ?? []).isNotEmpty;
    final missing =
        question['category'] != 'LISTENING' &&
        ((prompt.isEmpty || prompt == 'Câu ${question['questionNo']}') &&
                !hasSharedContent &&
                images.isEmpty &&
                jsonText(question, 'imageUrl').isEmpty ||
            question['category'] == 'READING' &&
                !hasSharedContent &&
                images.isEmpty &&
                jsonText(question, 'imageUrl').isEmpty);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (match != null) _text(match.mondai['instruction']),
        for (final group in groups) ..._reading(group),
        if (groups.isEmpty && passage != null) ...[
          _text(passage['title']),
          _text(passage['text']),
          _image(passage['imageUrl']),
        ],
        if (groups.isEmpty && match != null)
          for (final block in jsonObjects(match.mondai['content_blocks'] ?? []))
            _text(block['text']),
        if (match != null)
          for (final image in match.mondai['images'] as List? ?? [])
            _image(image),
        _text(text, emphasized: true),
        for (final image in images) _image(image),
        if (images.isEmpty) _image(question['imageUrl']),
        if (missing)
          const Text(
            'Chưa tải được nội dung số hóa của câu này. Tải lại tài liệu trước khi trả lời.',
          ),
        for (final choice in choices)
          Card(
            child: ListTile(
              key: ValueKey('exam-option-${choice['optionNo']}'),
              leading: Icon(
                question['selectedOption'] == choice['optionNo']
                    ? Icons.radio_button_checked
                    : Icons.radio_button_off,
              ),
              title: Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Text(
                  '${choice['optionNo']}. ${choice['text'] ?? ''}',
                  style: const TextStyle(fontSize: 18, height: 1.7),
                ),
              ),
              subtitle: choice['imageUrl'] == null
                  ? null
                  : _image(choice['imageUrl']),
              selected: question['selectedOption'] == choice['optionNo'],
              onTap: !enabled || missing || review || choice['optionNo'] is! int
                  ? null
                  : () => onAnswer?.call(choice['optionNo'] as int),
            ),
          ),
        if (!review && question['selectedOption'] != null)
          TextButton(
            onPressed: enabled ? () => onAnswer?.call(null) : null,
            child: const Text('Bỏ chọn đáp án'),
          ),
        if (review) ...[
          _text(
            'Bạn chọn: ${question['selectedOption'] ?? 'Chưa trả lời'} · Đáp án đúng: ${question['correctOption'] ?? '—'}',
          ),
          _text(question['explanation']),
        ],
      ],
    );
  }
}
