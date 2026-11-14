import 'package:flutter/material.dart';

/// The website's AI introduction, adapted to a single-column paper scroll.
class HomeAiScroll extends StatefulWidget {
  const HomeAiScroll({required this.onFeaturePressed, super.key});
  final ValueChanged<String> onFeaturePressed;

  @override
  State<HomeAiScroll> createState() => _HomeAiScrollState();
}

class _HomeAiScrollState extends State<HomeAiScroll> {
  bool _open = false;

  static const _features = [
    (
      '作文',
      'Góp ý bài viết',
      'AI Sensei nhận xét ngữ pháp, từ vựng và cách diễn đạt trong bài viết của bạn.',
      'Khám phá luyện viết',
      'writing',
    ),
    (
      '題',
      'Gợi ý đề luyện viết',
      'Khám phá chủ đề mới để luyện diễn đạt tiếng Nhật mỗi ngày.',
      'Thử AI Sensei',
      'writing',
    ),
    (
      '映',
      'Phân tích video học',
      'Tìm hiểu từ vựng, ngữ pháp và kết nối nội dung nghe với kiến thức vừa học.',
      'Học qua video',
      'video',
    ),
  ];

  @override
  Widget build(BuildContext context) => Container(
    key: const ValueKey('home-ai-introduction'),
    width: double.infinity,
    padding: const EdgeInsets.fromLTRB(18, 26, 18, 24),
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(22),
      gradient: const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF123866), Color(0xFF061D40)],
      ),
    ),
    child: Column(
      children: [
        const Text(
          'AI TRONG QTJP LEARNING · 学びの巻物',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Color(0xFF83BBEE),
            fontSize: 10,
            fontWeight: FontWeight.w800,
            letterSpacing: 1,
          ),
        ),
        const SizedBox(height: 12),
        const Text(
          'Một người bạn đồng hành thông minh trên hành trình học tiếng Nhật',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.white,
            fontSize: 22,
            height: 1.35,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 12),
        const Text(
          'QTJP kết hợp AI với bài luyện viết và video học tiếng Nhật. Mở cuộn giấy để khám phá.',
          textAlign: TextAlign.center,
          style: TextStyle(color: Color(0xFFC0D5EC), fontSize: 13, height: 1.6),
        ),
        const SizedBox(height: 22),
        Material(
          color: const Color(0xFFFFF0CF),
          borderRadius: BorderRadius.circular(6),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            key: const ValueKey('home-ai-scroll-toggle'),
            onTap: () => setState(() => _open = !_open),
            child: IntrinsicHeight(
              child: Row(
                children: [
                  _rod(),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 16,
                      ),
                      child: Column(
                        children: [
                          const Text(
                            'AI の巻物',
                            style: TextStyle(
                              color: Color(0xFFB54336),
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(height: 7),
                          Text(
                            _open
                                ? 'Thu cuộn giấy lại'
                                : 'Mở cuộn giấy khám phá AI',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Color(0xFF06275B),
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            _open ? 'Chạm để đóng' : 'Chạm để mở cuộn giấy →',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Color(0xFF8D6948),
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  _rod(),
                ],
              ),
            ),
          ),
        ),
        AnimatedSize(
          duration: const Duration(milliseconds: 250),
          alignment: Alignment.topCenter,
          child: !_open
              ? const SizedBox(width: double.infinity)
              : Container(
                  key: const ValueKey('home-ai-scroll-content'),
                  margin: const EdgeInsets.only(top: 12),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF6E2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text(
                        'AI giúp bạn học như thế nào?',
                        style: TextStyle(
                          color: Color(0xFF06275B),
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      for (final (symbol, title, description, action, id)
                          in _features) ...[
                        const SizedBox(height: 18),
                        Text(
                          '$symbol  $title',
                          style: const TextStyle(
                            color: Color(0xFF06275B),
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          description,
                          style: const TextStyle(
                            color: Color(0xFF695A48),
                            fontSize: 12,
                            height: 1.6,
                          ),
                        ),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: TextButton(
                            onPressed: () => widget.onFeaturePressed(id),
                            style: TextButton.styleFrom(
                              foregroundColor: const Color(0xFFAD3438),
                              padding: EdgeInsets.zero,
                            ),
                            child: Text(
                              '$action ↗',
                              style: const TextStyle(fontSize: 12),
                            ),
                          ),
                        ),
                      ],
                      const Divider(color: Color(0xFFE6D7B4)),
                      const Text(
                        '一歩ずつ、成長しよう\nCùng QTJP tiến bộ từng bước.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Color(0xFF8D6948),
                          fontSize: 11,
                          height: 1.6,
                        ),
                      ),
                    ],
                  ),
                ),
        ),
      ],
    ),
  );

  Widget _rod() => Container(
    width: 10,
    decoration: const BoxDecoration(
      gradient: LinearGradient(
        colors: [Color(0xFF78502D), Color(0xFFCFA56F), Color(0xFF926137)],
      ),
    ),
  );
}
