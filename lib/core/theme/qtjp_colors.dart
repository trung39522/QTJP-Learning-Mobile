import 'package:flutter/material.dart';

/// Bảng màu nhận diện được đồng bộ từ trang chủ QTJP Learning.
abstract final class QTJPColors {
  static const navy = Color(0xFF06275B);
  static const navyDark = Color(0xFF031A40);
  static const blue = Color(0xFF3C7FBD);
  static const red = Color(0xFFF32F36);

  static const background = Color(0xFFF8FAFC);
  static const softBlue = Color(0xFFF4F8FC);
  static const text = Color(0xFF172033);
  static const muted = Color(0xFF64748B);
  static const border = Color(0xFFE2E8F0);
  static const surface = Colors.white;
}

@immutable
class QTJPColorPalette extends ThemeExtension<QTJPColorPalette> {
  const QTJPColorPalette({
    required this.heading,
    required this.surface,
    required this.soft,
    required this.border,
    required this.muted,
    required this.blue,
    required this.pink,
  });
  final Color heading, surface, soft, border, muted, blue, pink;
  static const light = QTJPColorPalette(
    heading: QTJPColors.navy,
    surface: Colors.white,
    soft: QTJPColors.softBlue,
    border: QTJPColors.border,
    muted: QTJPColors.muted,
    blue: QTJPColors.blue,
    pink: Color(0xFFFFF1F2),
  );
  static const dark = QTJPColorPalette(
    heading: Color(0xFFE5EDFC),
    surface: Color(0xFF142033),
    soft: Color(0xFF1B2B43),
    border: Color(0xFF30425A),
    muted: Color(0xFFACBAD0),
    blue: Color(0xFF8CBFF1),
    pink: Color(0xFF35212B),
  );
  @override
  QTJPColorPalette copyWith({
    Color? heading,
    Color? surface,
    Color? soft,
    Color? border,
    Color? muted,
    Color? blue,
    Color? pink,
  }) => QTJPColorPalette(
    heading: heading ?? this.heading,
    surface: surface ?? this.surface,
    soft: soft ?? this.soft,
    border: border ?? this.border,
    muted: muted ?? this.muted,
    blue: blue ?? this.blue,
    pink: pink ?? this.pink,
  );
  @override
  QTJPColorPalette lerp(covariant QTJPColorPalette? other, double t) {
    if (other == null) return this;
    return QTJPColorPalette(
      heading: Color.lerp(heading, other.heading, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      soft: Color.lerp(soft, other.soft, t)!,
      border: Color.lerp(border, other.border, t)!,
      muted: Color.lerp(muted, other.muted, t)!,
      blue: Color.lerp(blue, other.blue, t)!,
      pink: Color.lerp(pink, other.pink, t)!,
    );
  }
}

extension QTJPThemedColors on BuildContext {
  QTJPColorPalette get qtjp =>
      Theme.of(this).extension<QTJPColorPalette>() ??
      (Theme.of(this).brightness == Brightness.dark
          ? QTJPColorPalette.dark
          : QTJPColorPalette.light);
}
