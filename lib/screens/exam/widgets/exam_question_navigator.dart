import 'package:flutter/material.dart';

import '../../../core/theme/qtjp_colors.dart';

class ExamQuestionNavigator extends StatelessWidget {
  const ExamQuestionNavigator({
    required this.questions,
    required this.current,
    required this.onSelected,
    required this.onClose,
    this.enabled = true,
    super.key,
  });
  final List<Map<String, dynamic>> questions;
  final int current;
  final ValueChanged<int> onSelected;
  final VoidCallback onClose;
  final bool enabled;
  @override
  Widget build(BuildContext context) => Drawer(
    width: (MediaQuery.sizeOf(context).width * .8).clamp(220.0, 280.0),
    backgroundColor: context.qtjp.surface,
    child: SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 8, 0),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Danh sách câu hỏi',
                    style: TextStyle(
                      color: context.qtjp.heading,
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Ẩn danh sách câu hỏi',
                  onPressed: onClose,
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Text(
              '${questions.where((q) => q['selectedOption'] != null).length}/${questions.length} câu đã trả lời',
              style: TextStyle(color: context.qtjp.muted),
            ),
          ),
          const Divider(),
          Expanded(
            child: GridView.builder(
              padding: const EdgeInsets.all(16),
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 62,
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
              ),
              itemCount: questions.length,
              itemBuilder: (context, index) {
                final question = questions[index];
                final answered = question['selectedOption'] != null;
                final marked = question['markedForReview'] == true;
                final selected = current == index;
                return Semantics(
                  selected: selected,
                  label:
                      'Câu ${index + 1}, ${answered ? 'đã trả lời' : 'chưa trả lời'}${marked ? ', đánh dấu xem lại' : ''}',
                  child: Material(
                    color: marked
                        ? const Color(0xFFFFE082)
                        : answered
                        ? const Color(0xFF21845B)
                        : context.qtjp.surface,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(
                        color: selected
                            ? context.qtjp.heading
                            : context.qtjp.border,
                        width: selected ? 3 : 1,
                      ),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: InkWell(
                      key: ValueKey('exam-question-$index'),
                      onTap: enabled ? () => onSelected(index) : null,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          Text(
                            '${index + 1}',
                            style: TextStyle(
                              color: marked
                                  ? const Color(0xFF553E00)
                                  : answered
                                  ? Colors.white
                                  : context.qtjp.heading,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          if (marked)
                            const Positioned(
                              right: 2,
                              top: 2,
                              child: Icon(
                                Icons.star_rounded,
                                size: 12,
                                color: Color(0xFF795500),
                              ),
                            ),
                          if (answered)
                            Positioned(
                              right: 2,
                              bottom: 2,
                              child: Icon(
                                Icons.check_rounded,
                                size: 12,
                                color: marked
                                    ? const Color(0xFF553E00)
                                    : Colors.white,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              '🟢 Đã trả lời   🟡 Đánh dấu\nViền đậm: câu đang xem',
              style: TextStyle(
                color: context.qtjp.muted,
                fontSize: 12,
                height: 1.7,
              ),
            ),
          ),
        ],
      ),
    ),
  );
}
