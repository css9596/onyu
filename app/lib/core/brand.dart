import 'package:flutter/material.dart';

/// Brand colors derived from the sunset wordmark icon.
/// Source of truth for any place that needs a hardcoded brand hex
/// outside of Material's `ColorScheme`.
class BrandColors {
  const BrandColors._();

  static const peach = Color(0xFFFFC9A8);
  static const coral = Color(0xFFFF8870);
  static const magenta = Color(0xFFA04CB8);
  static const indigo = Color(0xFF3D2A8E);
  static const inkDark = Color(0xFF1F1340);
  static const cream = Color(0xFFFAF6F0);

  /// Material 3 seed — the gradient's mid-magenta. Generates the rest
  /// of the palette via `ColorScheme.fromSeed`.
  static const seed = magenta;
}
