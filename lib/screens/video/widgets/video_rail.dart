import 'dart:math' as math;

import 'package:flutter/material.dart';

/// One independently swipeable section. Cards and images are built on demand.
class VideoRail extends StatelessWidget {
  const VideoRail({
    required this.storageKey,
    required this.itemCount,
    required this.itemBuilder,
    super.key,
  });

  final String storageKey;
  final int itemCount;
  final IndexedWidgetBuilder itemBuilder;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final width = math.min(336.0, constraints.maxWidth * .84);
      final scale = math.max(
        1.0,
        MediaQuery.textScalerOf(context).scale(17) / 17,
      );
      return SizedBox(
        height: width * 9 / 16 + 110 * scale + 66,
        child: ListView.separated(
          key: PageStorageKey(storageKey),
          scrollDirection: Axis.horizontal,
          itemCount: itemCount,
          itemBuilder: (context, index) =>
              SizedBox(width: width, child: itemBuilder(context, index)),
          separatorBuilder: (_, _) => const SizedBox(width: 14),
        ),
      );
    },
  );
}
