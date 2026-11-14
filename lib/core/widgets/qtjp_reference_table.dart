import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/qtjp_colors.dart';

/// A readable reference table with one horizontal scroll area on narrow phones.
class QTJPReferenceTable extends StatefulWidget {
  const QTJPReferenceTable({
    required this.headers,
    required this.rows,
    this.minWidth = 600,
    super.key,
  });
  final List<String> headers;
  final List<List<String>> rows;
  final double minWidth;
  @override
  State<QTJPReferenceTable> createState() => _QTJPReferenceTableState();
}

class _QTJPReferenceTableState extends State<QTJPReferenceTable> {
  final _scroll = ScrollController();
  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            border: Border.all(color: context.qtjp.border),
            borderRadius: BorderRadius.circular(14),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(13),
            child: Scrollbar(
              controller: _scroll,
              thumbVisibility: constraints.maxWidth < widget.minWidth,
              child: SingleChildScrollView(
                controller: _scroll,
                scrollDirection: Axis.horizontal,
                padding: EdgeInsets.only(
                  bottom: constraints.maxWidth < widget.minWidth ? 10 : 0,
                ),
                child: SizedBox(
                  width: math.max(constraints.maxWidth, widget.minWidth),
                  child: Table(
                    key: const ValueKey('qtjp-reference-table'),
                    defaultVerticalAlignment: TableCellVerticalAlignment.top,
                    columnWidths: {
                      0: FixedColumnWidth(
                        widget.headers.length == 3 ? 112 : 200,
                      ),
                    },
                    border: TableBorder.symmetric(
                      inside: BorderSide(color: context.qtjp.border, width: .7),
                    ),
                    children: [
                      TableRow(
                        decoration: const BoxDecoration(color: QTJPColors.navy),
                        children: [
                          for (final header in widget.headers)
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 14,
                              ),
                              child: Text(
                                header,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                        ],
                      ),
                      for (var i = 0; i < widget.rows.length; i++)
                        TableRow(
                          decoration: BoxDecoration(
                            color: i.isEven
                                ? context.qtjp.surface
                                : context.qtjp.soft,
                          ),
                          children: [
                            for (
                              var column = 0;
                              column < widget.headers.length;
                              column++
                            )
                              Padding(
                                padding: const EdgeInsets.all(14),
                                child: SelectableText(
                                  widget.rows[i][column],
                                  style: TextStyle(
                                    color: column == widget.headers.length - 1
                                        ? context.qtjp.blue
                                        : context.qtjp.heading,
                                    fontSize: column == 0 ? 13 : 16,
                                    height: 1.8,
                                    fontWeight: column == 0
                                        ? FontWeight.w700
                                        : FontWeight.w500,
                                  ),
                                ),
                              ),
                          ],
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
        if (constraints.maxWidth < widget.minWidth)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Row(
              children: [
                Icon(
                  Icons.swipe_left_alt_rounded,
                  size: 18,
                  color: context.qtjp.muted,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Vuốt ngang để xem đầy đủ bảng',
                    style: TextStyle(color: context.qtjp.muted, fontSize: 11),
                  ),
                ),
              ],
            ),
          ),
      ],
    ),
  );
}
