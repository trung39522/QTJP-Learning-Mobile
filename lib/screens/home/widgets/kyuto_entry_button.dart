import 'package:flutter/material.dart';

import '../../../core/theme/qtjp_colors.dart';

class KyutoEntryButton extends StatelessWidget {
  const KyutoEntryButton({required this.onPressed, super.key});

  static const avatarAsset = 'assets/mascot/kyuto_avatar.webp';

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Mở Kyuto, trợ lý AI QTJP',
      child: Material(
        color: const Color(0xFFFFF7FA),
        elevation: 7,
        shadowColor: const Color(0x3DC03970),
        borderRadius: BorderRadius.circular(999),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onPressed,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(6, 6, 15, 6),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircleAvatar(
                  radius: 23,
                  backgroundColor: Color(0xFFFFEAF3),
                  backgroundImage: AssetImage(avatarAsset),
                ),
                const SizedBox(width: 9),
                const Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Kyuto AI',
                      style: TextStyle(
                        color: Color(0xFF91345E),
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    Text(
                      'Trợ lý học tập',
                      style: TextStyle(
                        color: QTJPColors.muted,
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class KyutoPreviewSheet extends StatelessWidget {
  const KyutoPreviewSheet({required this.onActionSelected, super.key});

  final ValueChanged<String> onActionSelected;

  static const _quickActions = [
    ('辞', 'Tra từ vựng'),
    ('文', 'Giải thích ngữ pháp'),
    ('試', 'Luyện đề JLPT'),
    ('進', 'Xem tiến độ'),
  ];

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        20,
        4,
        20,
        24 + MediaQuery.viewPaddingOf(context).bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              CircleAvatar(
                radius: 31,
                backgroundColor: Color(0xFFFFEAF3),
                backgroundImage: AssetImage(KyutoEntryButton.avatarAsset),
              ),
              SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Kyuto · Trợ lý AI QTJP',
                      style: TextStyle(
                        color: QTJPColors.navyDark,
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    SizedBox(height: 3),
                    Text(
                      'キュートと一緒に勉強しましょう！',
                      style: TextStyle(
                        color: Color(0xFFB43B6D),
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF7FA),
              border: Border.all(color: const Color(0xFFF2DAE4)),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Text(
              'こんにちは！ Mình là Kyuto. Mình có thể giúp bạn tra từ, '
              'giải thích ngữ pháp, luyện JLPT và theo dõi hành trình học tập.',
              style: TextStyle(
                color: QTJPColors.text,
                fontSize: 14,
                height: 1.55,
              ),
            ),
          ),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: () => onActionSelected('Trò chuyện với Kyuto'),
              icon: const Icon(Icons.chat_bubble_outline),
              label: const Text('Trò chuyện với Kyuto'),
            ),
          ),
          const SizedBox(height: 18),
          const Text(
            'Bạn muốn làm gì?',
            style: TextStyle(
              color: QTJPColors.navy,
              fontSize: 15,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 10),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _quickActions.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisExtent: 58,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
            ),
            itemBuilder: (context, index) {
              final action = _quickActions[index];
              return OutlinedButton(
                onPressed: () => onActionSelected(action.$2),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  alignment: Alignment.centerLeft,
                ),
                child: Row(
                  children: [
                    Text(
                      action.$1,
                      style: const TextStyle(
                        color: Color(0xFFB43B6D),
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        action.$2,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 11),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: 16),
          const Text(
            'Đăng nhập bằng tài khoản QTJP để trò chuyện với Kyuto. Các mục tra cứu có thể mở từ lối tắt phía trên.',
            style: TextStyle(
              color: QTJPColors.muted,
              fontSize: 11,
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }
}
