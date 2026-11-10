import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qtjp_mobile/screens/alphabet/data/kana_stroke_repository.dart';

Future<void> prepareKanaAssets(WidgetTester tester) async {
  await tester.runAsync(
    () => rootBundle.loadString('assets/alphabet/kana_strokes.json'),
  );
}

/// Let real asset decoding finish before advancing the animation's fake clock.
Future<void> settleKanaDetail(WidgetTester tester) async {
  await tester.pump();
  final loader = tester.widget<FutureBuilder<List<KanaGlyph>>>(
    find.byType(FutureBuilder<List<KanaGlyph>>),
  );
  await tester.runAsync(
    () => loader.future!.timeout(const Duration(seconds: 10)),
  );
  await tester.pumpAndSettle();
}
