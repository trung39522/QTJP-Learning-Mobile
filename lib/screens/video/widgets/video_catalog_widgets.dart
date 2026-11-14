import 'package:flutter/material.dart';

import '../../../core/network/api_client.dart';
import '../../../core/theme/qtjp_colors.dart';

class VideoUsageCard extends StatelessWidget {
  const VideoUsageCard({
    required this.usage,
    required this.loading,
    this.error,
    this.onRetry,
    this.onVip,
    super.key,
  });
  final Map<String, dynamic>? usage;
  final bool loading;
  final Object? error;
  final VoidCallback? onRetry, onVip;
  @override
  Widget build(BuildContext context) {
    final remaining = usage?['remaining'];
    final unlimited = remaining == -1 && usage?['dailyLimit'] == -1;
    final count = remaining is num && remaining.isFinite && remaining >= 0
        ? remaining.toInt()
        : null;
    final member = usage?['membership']?.toString().trim() ?? '';
    return VideoSurface(
      key: const ValueKey('video-usage-card'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: context.qtjp.soft,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.auto_awesome_rounded,
                  color: context.qtjp.heading,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Lượt phân tích AI',
                      style: TextStyle(
                        color: context.qtjp.muted,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 5),
                    if (loading && usage == null)
                      const Text('Đang tải lượt AI…')
                    else if (error != null)
                      Text(
                        error is ApiException
                            ? error.toString()
                            : 'Chưa tải được lượt AI.',
                        style: const TextStyle(
                          color: QTJPColors.red,
                          fontSize: 13,
                        ),
                      )
                    else
                      Text(
                        unlimited
                            ? 'Không giới hạn'
                            : count == null
                            ? 'Chưa có dữ liệu lượt AI'
                            : '$count lượt còn lại',
                        style: TextStyle(
                          color: context.qtjp.heading,
                          fontSize: 21,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    if (member.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          'Gói $member',
                          style: TextStyle(
                            color: context.qtjp.blue,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
          if (loading && usage == null)
            const Padding(
              padding: EdgeInsets.only(top: 12),
              child: LinearProgressIndicator(minHeight: 2),
            ),
          if (error != null && onRetry != null)
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                onPressed: onRetry,
                child: const Text('Thử tải lại lượt AI'),
              ),
            ),
          if (onVip != null)
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: onVip,
                icon: const Icon(Icons.workspace_premium_outlined, size: 18),
                label: const Text('Xem gói VIP và thanh toán'),
              ),
            ),
        ],
      ),
    );
  }
}

class VideoAnalysisCard extends StatelessWidget {
  const VideoAnalysisCard({
    required this.controller,
    required this.enabled,
    required this.onAnalyze,
    this.working,
    super.key,
  });
  final TextEditingController controller;
  final bool enabled;
  final VoidCallback? onAnalyze;
  final String? working;
  @override
  Widget build(BuildContext context) => VideoSurface(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Phân tích video bằng AI',
          style: TextStyle(
            color: context.qtjp.heading,
            fontSize: 18,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 7),
        Text(
          'Dán liên kết YouTube hoặc TikTok để học cùng phụ đề, từ vựng và ngữ pháp.',
          style: TextStyle(
            color: context.qtjp.muted,
            fontSize: 13,
            height: 1.5,
          ),
        ),
        const SizedBox(height: 16),
        ValueListenableBuilder<TextEditingValue>(
          valueListenable: controller,
          builder: (context, value, _) {
            final host =
                Uri.tryParse(value.text.trim())?.host.toLowerCase() ?? '';
            final source =
                host == 'youtu.be' ||
                    host == 'youtube.com' ||
                    host.endsWith('.youtube.com')
                ? 'YouTube'
                : host == 'tiktok.com' || host.endsWith('.tiktok.com')
                ? 'TikTok'
                : null;
            return TextField(
              key: const ValueKey('video-url'),
              controller: controller,
              enabled: enabled,
              autocorrect: false,
              keyboardType: TextInputType.url,
              textInputAction: TextInputAction.done,
              onSubmitted: onAnalyze == null ? null : (_) => onAnalyze!(),
              decoration: InputDecoration(
                labelText: 'Liên kết YouTube hoặc TikTok',
                hintText: 'https://…',
                prefixIcon: const Icon(Icons.link_rounded),
                suffixText: source,
                filled: true,
                fillColor: context.qtjp.soft,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: context.qtjp.border),
                ),
              ),
            );
          },
        ),
        const SizedBox(height: 12),
        FilledButton.icon(
          key: const ValueKey('video-analyze'),
          onPressed: onAnalyze,
          style: FilledButton.styleFrom(backgroundColor: QTJPColors.red),
          icon: const Icon(Icons.auto_awesome, size: 18),
          label: const Text('Phân tích bằng AI'),
        ),
        const SizedBox(height: 10),
        Text(
          working ?? 'Chỉ phân tích khi bạn yêu cầu. Hạn mức được kiểm tra bởi hệ thống.',
          style: TextStyle(
            color: working == null ? context.qtjp.muted : QTJPColors.navy,
            fontSize: 11,
            height: 1.5,
          ),
        ),
        if (working != null)
          const Padding(
            padding: EdgeInsets.only(top: 10),
            child: LinearProgressIndicator(minHeight: 2),
          ),
      ],
    ),
  );
}

class VideoLevelFilters extends StatelessWidget {
  const VideoLevelFilters({
    required this.level,
    required this.onSelected,
    super.key,
  });
  final String level;
  final ValueChanged<String>? onSelected;
  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    key: const ValueKey('video-level-filters'),
    scrollDirection: Axis.horizontal,
    child: Row(
      children: [
        for (final item in ['ALL', 'N5', 'N4', 'N3', 'N2', 'N1'])
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: SizedBox(
                width: 54,
                child: Text(
                  item == 'ALL' ? 'Tất cả' : item,
                  textAlign: TextAlign.center,
                ),
              ),
              selected: level == item,
              showCheckmark: false,
              selectedColor: QTJPColors.navy,
              backgroundColor: context.qtjp.surface,
              labelStyle: TextStyle(
                color: level == item ? Colors.white : context.qtjp.heading,
                fontWeight: FontWeight.w700,
                fontSize: 12,
              ),
              side: BorderSide(
                color: level == item ? QTJPColors.navy : context.qtjp.border,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              onSelected: onSelected == null ? null : (_) => onSelected!(item),
            ),
          ),
      ],
    ),
  );
}

class VideoSectionHeading extends StatelessWidget {
  const VideoSectionHeading(this.title, {this.description, super.key});
  final String title;
  final String? description;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 4, bottom: 14),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 4,
              height: 22,
              decoration: BoxDecoration(
                color: QTJPColors.red,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  color: context.qtjp.heading,
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
        if (description != null)
          Padding(
            padding: const EdgeInsets.only(top: 6, left: 14),
            child: Text(
              description!,
              style: TextStyle(
                color: context.qtjp.muted,
                fontSize: 12,
                height: 1.5,
              ),
            ),
          ),
      ],
    ),
  );
}

class VideoSurface extends StatelessWidget {
  const VideoSurface({required this.child, super.key});
  final Widget child;
  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 18),
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: context.qtjp.surface,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: context.qtjp.border),
      boxShadow: const [
        BoxShadow(
          color: Color(0x0606275B),
          blurRadius: 16,
          offset: Offset(0, 5),
        ),
      ],
    ),
    child: child,
  );
}

class VideoEmptyState extends StatelessWidget {
  const VideoEmptyState(this.message, {super.key});
  final String message;
  @override
  Widget build(BuildContext context) => VideoSurface(
    child: Column(
      children: [
        Icon(Icons.video_library_outlined, color: context.qtjp.blue, size: 32),
        const SizedBox(height: 10),
        Text(
          message,
          textAlign: TextAlign.center,
          style: TextStyle(color: context.qtjp.muted, height: 1.5),
        ),
      ],
    ),
  );
}

class VideoCardSkeleton extends StatelessWidget {
  const VideoCardSkeleton({super.key});
  @override
  Widget build(BuildContext context) => VideoSurface(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AspectRatio(
          aspectRatio: 16 / 9,
          child: ColoredBox(color: context.qtjp.soft),
        ),
        const SizedBox(height: 14),
        Container(height: 16, color: context.qtjp.soft),
        const SizedBox(height: 8),
        FractionallySizedBox(
          widthFactor: 0.6,
          alignment: Alignment.centerLeft,
          child: Container(height: 14, color: context.qtjp.soft),
        ),
      ],
    ),
  );
}
