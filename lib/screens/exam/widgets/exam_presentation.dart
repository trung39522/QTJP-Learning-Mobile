import 'package:flutter/material.dart';

import '../../../core/network/api_client.dart';
import '../../../core/theme/qtjp_colors.dart';

class ExamCatalogCard extends StatelessWidget {
  const ExamCatalogCard({required this.exam, required this.onTap, super.key});
  final Map<String, dynamic> exam;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) {
    final continuing = exam['progress'] != null;
    return Card(
      margin: const EdgeInsets.only(top: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: context.qtjp.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        key: ValueKey('exam-${exam['id']}'),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: QTJPColors.navy,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      jsonText(exam, 'level'),
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      continuing ? 'Đang làm' : 'ĐỀ THI JLPT',
                      style: TextStyle(
                        color: continuing ? QTJPColors.red : context.qtjp.muted,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  Icon(
                    Icons.arrow_forward_rounded,
                    color: context.qtjp.blue,
                    size: 20,
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Text(
                jsonText(exam, 'title'),
                style: TextStyle(
                  color: context.qtjp.heading,
                  fontSize: 19,
                  fontWeight: FontWeight.w800,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 16,
                runSpacing: 8,
                children: [
                  _metric(
                    context,
                    Icons.quiz_outlined,
                    '${exam['totalQuestions']} câu',
                  ),
                  _metric(
                    context,
                    Icons.schedule_rounded,
                    '${((exam['totalDurationSeconds'] as num? ?? 0) / 60).ceil()} phút',
                  ),
                ],
              ),
              const Divider(height: 28),
              Text(
                continuing ? 'Tiếp tục bài đang làm →' : 'Xem đề & bắt đầu →',
                style: TextStyle(
                  color: context.qtjp.blue,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _metric(BuildContext context, IconData icon, String text) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(icon, size: 17, color: context.qtjp.muted),
      const SizedBox(width: 6),
      Text(text, style: TextStyle(color: context.qtjp.muted, fontSize: 13)),
    ],
  );
}

class ExamSectionCard extends StatelessWidget {
  const ExamSectionCard({
    required this.section,
    required this.index,
    super.key,
  });
  final Map<String, dynamic> section;
  final int index;
  @override
  Widget build(BuildContext context) => Card(
    margin: const EdgeInsets.only(bottom: 10),
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: context.qtjp.soft,
            child: Text(
              '$index',
              style: TextStyle(
                color: context.qtjp.heading,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  jsonText(section, 'name'),
                  style: TextStyle(
                    color: context.qtjp.heading,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '${((section['durationSeconds'] as num? ?? 0) / 60).ceil()} phút · ${section['totalQuestions']} câu',
                  style: TextStyle(color: context.qtjp.muted, fontSize: 13),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

class ExamBreakCard extends StatelessWidget {
  const ExamBreakCard({
    required this.state,
    required this.remaining,
    required this.onNext,
    super.key,
  });
  final Map<String, dynamic> state;
  final String remaining;
  final VoidCallback? onNext;
  @override
  Widget build(BuildContext context) => Card(
    key: const ValueKey('exam-break-card'),
    clipBehavior: Clip.antiAlias,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(24),
      side: BorderSide(color: context.qtjp.border),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const ColoredBox(
          color: QTJPColors.navy,
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            child: Text(
              'QTJP LEARNING  ·  休憩時間',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: 1,
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(22),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                width: 72,
                height: 72,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: context.qtjp.soft,
                ),
                child: Icon(
                  Icons.coffee_outlined,
                  size: 40,
                  color: context.qtjp.blue,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Giờ nghỉ giữa các phần',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: context.qtjp.heading,
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  height: 1.3,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Thư giãn một chút, chuẩn bị cho phần thi tiếp theo.',
                textAlign: TextAlign.center,
                style: TextStyle(color: context.qtjp.muted, height: 1.6),
              ),
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: context.qtjp.soft,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Column(
                  children: [
                    Text(
                      'THỜI GIAN CÒN LẠI',
                      style: TextStyle(
                        color: context.qtjp.muted,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Semantics(
                      label: 'Thời gian nghỉ còn lại: $remaining',
                      child: ExcludeSemantics(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            remaining,
                            key: const ValueKey('exam-break-countdown'),
                            style: TextStyle(
                              color: context.qtjp.heading,
                              fontSize: 44,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 3,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'SẮP BẮT ĐẦU',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: context.qtjp.blue,
                  fontWeight: FontWeight.w800,
                  fontSize: 11,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                jsonText(state, 'sectionName'),
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: context.qtjp.heading,
                  fontSize: 19,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: onNext,
                child: const Text(
                  'Bắt đầu phần tiếp theo',
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                state['audioUrl'] is String &&
                        (state['audioUrl'] as String).isNotEmpty
                    ? 'Kiểm tra âm lượng trước khi bắt đầu phần nghe.'
                    : 'Bạn có thể bắt đầu sớm. Hệ thống chuyển phần khi hết giờ nghỉ.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: context.qtjp.muted,
                  fontSize: 12,
                  height: 1.6,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}
