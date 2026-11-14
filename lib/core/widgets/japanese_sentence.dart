import 'package:flutter/material.dart';

import '../theme/qtjp_colors.dart';

/// Displays only readings supplied by the API, retaining the original sentence
/// if segmented data is absent or does not match it.
class JapaneseSentence extends StatelessWidget {
  const JapaneseSentence({
    required this.text,
    required this.segments,
    this.centered = false,
    this.foregroundColor,
    this.readingColor,
    this.fontSize = 18,
    super.key,
  });
  final String text;
  final List<Map<String, dynamic>> segments;
  final bool centered;
  final Color? foregroundColor, readingColor;
  final double fontSize;
  @override
  Widget build(BuildContext context) {
    final valid =
        segments.isNotEmpty &&
        segments.every((s) => s['text'] is String) &&
        segments.map((s) => s['text'] as String).join() == text;
    if (!valid) {
      return Text(
        text,
        textAlign: centered ? TextAlign.center : TextAlign.start,
        style: TextStyle(
          fontSize: fontSize,
          height: 1.6,
          color: foregroundColor,
        ),
      );
    }
    return Semantics(
      label: text,
      child: ExcludeSemantics(
        child: Wrap(
          alignment: centered ? WrapAlignment.center : WrapAlignment.start,
          crossAxisAlignment: WrapCrossAlignment.end,
          runSpacing: 8,
          children: [
            for (final segment in segments)
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    segment['reading'] is String
                        ? segment['reading'] as String
                        : '',
                    style: TextStyle(
                      fontSize: 10,
                      height: 1.3,
                      color: readingColor ?? context.qtjp.blue,
                    ),
                  ),
                  Text(
                    segment['text'] as String,
                    style: TextStyle(
                      fontSize: fontSize,
                      height: 1.5,
                      color: foregroundColor,
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
