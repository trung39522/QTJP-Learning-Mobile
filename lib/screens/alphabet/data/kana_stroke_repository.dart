import 'dart:convert';

import 'package:flutter/services.dart';

class StrokeNumber {
  const StrokeNumber(this.text, this.x, this.y);

  final String text;
  final double x;
  final double y;
}

class KanaGlyph {
  KanaGlyph({
    required this.character,
    required List<String> paths,
    required List<StrokeNumber> numbers,
  }) : paths = List.unmodifiable(paths),
       numbers = List.unmodifiable(numbers);

  final String character;
  final List<String> paths;
  final List<StrokeNumber> numbers;
}

abstract interface class KanaStrokeRepository {
  Future<List<KanaGlyph>> load(String text);
}

/// Offline subset of KanjiVG, pinned to r20250816. Never fetches at runtime.
class BundledKanaStrokeRepository implements KanaStrokeRepository {
  BundledKanaStrokeRepository({AssetBundle? bundle})
    : _bundle = bundle ?? rootBundle;

  final AssetBundle _bundle;
  Future<Map<String, dynamic>>? _catalogue;

  Future<Map<String, dynamic>> _readCatalogue() async {
    final json = jsonDecode(
      await _bundle.loadString('assets/alphabet/kana_strokes.json'),
    ) as Map<String, dynamic>;
    return json['characters'] as Map<String, dynamic>;
  }

  @override
  Future<List<KanaGlyph>> load(String text) async {
    if (text.isEmpty) throw const FormatException('Empty kana text.');
    try {
      final catalogue = await (_catalogue ??= _readCatalogue());
      return List.unmodifiable(
        text.runes.map((rune) {
          final character = String.fromCharCode(rune);
          final entry = catalogue[character] as Map<String, dynamic>?;
          if (entry == null) {
            throw FormatException('No stroke data for $character.');
          }
          final paths = List<String>.from(entry['paths'] as List);
          if (paths.isEmpty) {
            throw FormatException('No strokes for $character.');
          }
          return KanaGlyph(
            character: character,
            paths: paths,
            numbers: (entry['numbers'] as List)
                .map(
                  (number) => StrokeNumber(
                    number['text'] as String,
                    (number['x'] as num).toDouble(),
                    (number['y'] as num).toDouble(),
                  ),
                )
                .toList(),
          );
        }),
      );
    } catch (_) {
      _catalogue = null; // Permit an explicit retry after a failed asset load.
      rethrow;
    }
  }
}
