import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/theme/qtjp_colors.dart';
import '../models/video_presentation.dart';

class VideoCard extends StatelessWidget {
  const VideoCard({
    required this.video,
    required this.onWatch,
    this.onAnalyze,
    this.preset = true,
    this.compact = false,
    super.key,
  });
  final VideoPresentation video;
  final VoidCallback? onWatch, onAnalyze;
  final bool preset;
  final bool compact;

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 18),
    decoration: BoxDecoration(
      color: context.qtjp.surface,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: context.qtjp.border),
      boxShadow: const [
        BoxShadow(
          color: Color(0x0806275B),
          blurRadius: 16,
          offset: Offset(0, 6),
        ),
      ],
    ),
    child: Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(20),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            onTap: onWatch,
            child: Stack(
              alignment: Alignment.center,
              children: [
                VideoThumbnail(video: video),
                IgnorePointer(
                  child: Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: QTJPColors.navy.withValues(alpha: 0.82),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.8),
                      ),
                    ),
                    child: const Icon(
                      Icons.play_arrow_rounded,
                      color: Colors.white,
                      size: 30,
                    ),
                  ),
                ),
                if (video.level.isNotEmpty)
                  Positioned(
                    left: 12,
                    bottom: 12,
                    child: _Tag(video.level, navy: true),
                  ),
                Positioned(right: 12, top: 12, child: _Tag(video.sourceLabel)),
              ],
            ),
          ),
          if (compact)
            Expanded(child: _details(context))
          else
            _details(context),
        ],
      ),
    ),
  );

  Widget _details(BuildContext context) => Padding(
    padding: const EdgeInsets.all(16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          video.title,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: context.qtjp.heading,
            fontSize: 17,
            height: 1.35,
            fontWeight: FontWeight.w800,
          ),
        ),
        if (video.description.trim().isNotEmpty) ...[
          const SizedBox(height: 7),
          Text(
            video.description,
            maxLines: compact ? 1 : 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: context.qtjp.muted,
              fontSize: 13,
              height: 1.5,
            ),
          ),
        ],
        if (compact) const Spacer() else const SizedBox(height: 14),
        if (compact)
          SizedBox(
            height:
                44 *
                math.max(1.0, MediaQuery.textScalerOf(context).scale(14) / 14),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    key: ValueKey(
                      preset
                          ? 'video-preview-${video.data['id']}'
                          : 'video-history-${video.data['id']}',
                    ),
                    onPressed: onWatch,
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                    ),
                    child: const Text(
                      'Xem video',
                      maxLines: 2,
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
                if (preset) ...[
                  const SizedBox(width: 8),
                  Expanded(
                    child: FilledButton(
                      key: ValueKey('video-preset-${video.data['id']}'),
                      onPressed: onAnalyze,
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                      ),
                      child: const Text(
                        'Phân tích AI',
                        maxLines: 2,
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          )
        else
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                key: ValueKey(
                  preset
                      ? 'video-preview-${video.data['id']}'
                      : 'video-history-${video.data['id']}',
                ),
                onPressed: onWatch,
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(0, 42),
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                ),
                icon: const Icon(Icons.play_circle_outline_rounded, size: 19),
                label: const Text('Xem video'),
              ),
              if (preset)
                FilledButton.icon(
                  key: ValueKey('video-preset-${video.data['id']}'),
                  onPressed: onAnalyze,
                  style: FilledButton.styleFrom(
                    backgroundColor: QTJPColors.red,
                    minimumSize: const Size(0, 42),
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                  ),
                  icon: const Icon(Icons.auto_awesome, size: 16),
                  label: const Text('Phân tích AI'),
                ),
            ],
          ),
      ],
    ),
  );
}

class VideoThumbnail extends StatelessWidget {
  const VideoThumbnail({required this.video, super.key});
  final VideoPresentation video;
  @override
  Widget build(BuildContext context) => AspectRatio(
    aspectRatio: 16 / 9,
    child: LayoutBuilder(
      builder: (context, constraints) {
        final url = video.thumbnail;
        if (url == null) return _fallback(context);
        return Image.network(
          url,
          key: ValueKey('thumbnail-${video.data['id']}'),
          fit: BoxFit.cover,
          cacheWidth: math.min(
            960,
            (constraints.maxWidth * MediaQuery.devicePixelRatioOf(context))
                .ceil(),
          ),
          filterQuality: FilterQuality.low,
          semanticLabel: 'Ảnh video ${video.title}',
          errorBuilder: (_, _, _) => _fallback(context),
          loadingBuilder: (_, child, progress) =>
              progress == null ? child : ColoredBox(color: context.qtjp.soft),
        );
      },
    ),
  );

  Widget _fallback(BuildContext context) => DecoratedBox(
    key: ValueKey('thumbnail-fallback-${video.data['id']}'),
    decoration: BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [context.qtjp.soft, context.qtjp.surface],
      ),
    ),
    child: const Center(
      child: Icon(
        Icons.ondemand_video_rounded,
        color: Color(0x553C7FBD),
        size: 68,
      ),
    ),
  );
}

class _Tag extends StatelessWidget {
  const _Tag(this.label, {this.navy = false});
  final String label;
  final bool navy;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    decoration: BoxDecoration(
      color: navy ? QTJPColors.navy : Colors.white.withValues(alpha: 0.95),
      borderRadius: BorderRadius.circular(8),
    ),
    child: Text(
      label,
      style: TextStyle(
        color: navy ? Colors.white : QTJPColors.navy,
        fontSize: 11,
        fontWeight: FontWeight.w800,
      ),
    ),
  );
}
