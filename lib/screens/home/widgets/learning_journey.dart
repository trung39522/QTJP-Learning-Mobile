import 'package:flutter/material.dart';

import '../../../core/theme/qtjp_colors.dart';
import '../models/learning_journey_item.dart';

class LearningJourney extends StatelessWidget {
  const LearningJourney({
    required this.items,
    required this.onItemTap,
    super.key,
  });

  final List<LearningJourneyItem> items;
  final ValueChanged<LearningJourneyItem> onItemTap;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 900;

        return Container(
          width: double.infinity,
          padding: EdgeInsets.all(isWide ? 28 : 18),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [context.qtjp.soft, context.qtjp.surface],
            ),
            border: Border.all(color: context.qtjp.border),
            borderRadius: BorderRadius.circular(24),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 50,
                    height: 50,
                    alignment: Alignment.center,
                    decoration: const BoxDecoration(
                      color: QTJPColors.navy,
                      shape: BoxShape.circle,
                    ),
                    child: const Text(
                      '富士',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'QTJP · HÀNH TRÌNH CHINH PHỤC',
                          style: TextStyle(
                            color: QTJPColors.red,
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.8,
                          ),
                        ),
                        SizedBox(height: 3),
                        Text(
                          'Từng bước lên đỉnh JLPT',
                          style: TextStyle(
                            color: context.qtjp.heading,
                            fontSize: 17,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 22),
              if (isWide)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: List.generate(items.length, (index) {
                    return Expanded(
                      child: Padding(
                        padding: EdgeInsets.only(
                          right: index == items.length - 1 ? 0 : 12,
                        ),
                        child: _WideJourneyStep(
                          item: items[index],
                          isLast: index == items.length - 1,
                          onTap: () => onItemTap(items[index]),
                        ),
                      ),
                    );
                  }),
                )
              else
                Column(
                  children: List.generate(items.length, (index) {
                    return _CompactJourneyStep(
                      item: items[index],
                      isLast: index == items.length - 1,
                      onTap: () => onItemTap(items[index]),
                    );
                  }),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _CompactJourneyStep extends StatelessWidget {
  const _CompactJourneyStep({
    required this.item,
    required this.isLast,
    required this.onTap,
  });

  final LearningJourneyItem item;
  final bool isLast;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 43,
            child: Column(
              children: [
                _JourneyNumber(number: item.number),
                if (!isLast)
                  Expanded(
                    child: Container(width: 2, color: const Color(0xFFB8D3E6)),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : 14),
              child: _JourneyCard(item: item, onTap: onTap),
            ),
          ),
        ],
      ),
    );
  }
}

class _WideJourneyStep extends StatelessWidget {
  const _WideJourneyStep({
    required this.item,
    required this.isLast,
    required this.onTap,
  });

  final LearningJourneyItem item;
  final bool isLast;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            _JourneyNumber(number: item.number),
            if (!isLast)
              const Expanded(
                child: Divider(color: Color(0xFFB8D3E6), thickness: 2),
              ),
          ],
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 245,
          child: _JourneyCard(
            item: item,
            onTap: onTap,
            expandDescription: true,
          ),
        ),
      ],
    );
  }
}

class _JourneyNumber extends StatelessWidget {
  const _JourneyNumber({required this.number});

  final String number;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 38,
      height: 38,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: QTJPColors.navy,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 3),
        boxShadow: const [BoxShadow(color: Color(0x2206275B), blurRadius: 10)],
      ),
      child: Text(
        number,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _JourneyCard extends StatelessWidget {
  const _JourneyCard({
    required this.item,
    required this.onTap,
    this.expandDescription = false,
  });

  final LearningJourneyItem item;
  final VoidCallback onTap;
  final bool expandDescription;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: context.qtjp.surface.withValues(alpha: 0.92),
      borderRadius: BorderRadius.circular(17),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 39,
                    height: 39,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: QTJPColors.red.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(11),
                    ),
                    child: Text(
                      item.symbol,
                      style: const TextStyle(
                        color: QTJPColors.red,
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      item.tag,
                      style: TextStyle(
                        color: context.qtjp.blue,
                        fontSize: 9,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                item.title,
                style: TextStyle(
                  color: context.qtjp.heading,
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 6),
              if (expandDescription)
                Expanded(child: _JourneyDescription(item.description))
              else
                _JourneyDescription(item.description),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      item.actionLabel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: context.qtjp.heading,
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  const Icon(
                    Icons.north_east_rounded,
                    color: QTJPColors.red,
                    size: 17,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _JourneyDescription extends StatelessWidget {
  const _JourneyDescription(this.description);

  final String description;

  @override
  Widget build(BuildContext context) {
    return Text(
      description,
      style: TextStyle(color: context.qtjp.muted, fontSize: 12, height: 1.5),
    );
  }
}
