import 'package:flutter/material.dart';

import '../../core/theme/qtjp_colors.dart';
import '../profile/models/account_presentation.dart';
import 'vip_repository.dart';

class VipHero extends StatelessWidget {
  const VipHero({required this.user, required this.onChoose, super.key});
  final Map<String, dynamic>? user;
  final VoidCallback onChoose;

  @override
  Widget build(BuildContext context) {
    final account = AccountPresentation(user);
    final vip = account.vipAt(DateTime.now());
    final expiry = DateTime.tryParse(user?['vipExpiresAt']?.toString() ?? '')
        ?.toLocal();
    final date = expiry == null
        ? '—'
        : '${expiry.day.toString().padLeft(2, '0')}/${expiry.month.toString().padLeft(2, '0')}/${expiry.year}';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            gradient: const LinearGradient(
              colors: [Color(0xFF041B40), Color(0xFF0B376D)],
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'QTJP LEARNING PREMIUM',
                style: TextStyle(
                  color: Color(0xFFFFD45A),
                  fontSize: 11,
                  letterSpacing: 1.3,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 14),
              const Text(
                'Nâng cấp hành trình học với VIP',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  height: 1.18,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 14),
              const Text(
                'Mở rộng trải nghiệm AI và flashcard cá nhân, duy trì nhịp học theo lộ trình JLPT của bạn.',
                style: TextStyle(
                  color: Color(0xFFCBD9E9),
                  fontSize: 13,
                  height: 1.6,
                ),
              ),
              const SizedBox(height: 18),
              FilledButton(
                onPressed: onChoose,
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFFFFD45A),
                  foregroundColor: const Color(0xFF3C2C00),
                ),
                child: Text(vip ? 'Gia hạn VIP' : 'Chọn gói VIP'),
              ),
              const SizedBox(height: 14),
              const Text(
                '✓ VNPAY   ·   ✓ Kích hoạt tự động\n✓ Gia hạn cộng dồn',
                style: TextStyle(
                  color: Color(0xFFCBD9E9),
                  fontSize: 11,
                  height: 1.8,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: context.qtjp.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: vip ? const Color(0xFFE3BD52) : context.qtjp.border,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.workspace_premium_rounded,
                    color: Color(0xFFBB8E14),
                    size: 30,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      account.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: context.qtjp.heading,
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  Text(
                    vip ? 'VIP' : 'FREE',
                    style: const TextStyle(
                      color: Color(0xFFAA7E0C),
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Text(
                vip ? 'VIP đang hoạt động' : 'Tài khoản miễn phí',
                style: TextStyle(
                  color: context.qtjp.heading,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                vip ? 'Hiệu lực đến: $date' : 'Chọn gói phù hợp để bắt đầu.',
                style: TextStyle(color: context.qtjp.muted, fontSize: 12),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class VipBenefits extends StatelessWidget {
  const VipBenefits({super.key});
  static const items = [
    (
      Icons.rate_review_outlined,
      'AI Sensei không giới hạn',
      'FREE: 3 lượt chấm bài viết mỗi ngày.',
    ),
    (
      Icons.edit_note_rounded,
      'Tạo đề luyện viết không giới hạn',
      'FREE: 1 lượt tạo đề mỗi ngày.',
    ),
    (
      Icons.style_outlined,
      'Flashcard cá nhân không giới hạn',
      'FREE: tối đa 3 bộ cá nhân.',
    ),
  ];
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      const SizedBox(height: 24),
      Text(
        'Quyền lợi VIP',
        style: TextStyle(
          color: context.qtjp.heading,
          fontSize: 21,
          fontWeight: FontWeight.w800,
        ),
      ),
      const SizedBox(height: 12),
      for (final (icon, title, detail) in items)
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: context.qtjp.blue, size: 22),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: context.qtjp.heading,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      detail,
                      style: TextStyle(color: context.qtjp.muted, fontSize: 11),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
    ],
  );
}

class VipPlanCard extends StatelessWidget {
  const VipPlanCard({
    required this.plan,
    required this.onChoose,
    required this.renew,
    super.key,
  });
  final VipPlan plan;
  final VoidCallback? onChoose;
  final bool renew;
  @override
  Widget build(BuildContext context) {
    final popular = plan.months == 3;
    return Container(
      margin: const EdgeInsets.only(top: 14),
      decoration: BoxDecoration(
        color: context.qtjp.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: popular ? const Color(0xFFD8AF39) : context.qtjp.border,
          width: popular ? 1.5 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: .035),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (popular) ...[
              const Text(
                '★ PHỔ BIẾN NHẤT',
                style: TextStyle(
                  color: Color(0xFFAD7F00),
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1,
                ),
              ),
              const SizedBox(height: 12),
            ],
            Text(
              'VIP ${plan.months} tháng',
              style: TextStyle(
                color: context.qtjp.heading,
                fontSize: 20,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              vipMoney(plan.listedAmount),
              style: TextStyle(
                color: context.qtjp.heading,
                fontSize: 29,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              switch (plan.months) {
                1 => 'Trải nghiệm đầy đủ các tính năng VIP.',
                3 => 'Một lộ trình ôn luyện JLPT liên tục.',
                6 => 'Cân bằng chi phí và thời gian học.',
                _ => 'Đồng hành cùng kế hoạch học dài hạn.',
              },
              style: TextStyle(
                color: context.qtjp.muted,
                fontSize: 12,
                height: 1.5,
              ),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Divider(),
            ),
            for (final text in [
              'AI chấm bài và tạo đề không giới hạn',
              'Flashcard cá nhân không giới hạn',
              'Gia hạn cộng dồn thời gian VIP',
            ])
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.check_circle_outline,
                      size: 16,
                      color: Color(0xFF2E9464),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        text,
                        style: TextStyle(
                          color: context.qtjp.heading,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 10),
            FilledButton(
              key: ValueKey('vip-plan-${plan.months}'),
              onPressed: onChoose,
              style: FilledButton.styleFrom(
                backgroundColor: popular
                    ? const Color(0xFFFFD45A)
                    : const Color(0xFF06275B),
                foregroundColor: popular
                    ? const Color(0xFF3C2C00)
                    : Colors.white,
              ),
              child: Text(
                renew
                    ? 'Gia hạn ${plan.months} tháng'
                    : 'Chọn gói ${plan.months} tháng',
              ),
            ),
          ],
        ),
      ),
    );
  }
}
