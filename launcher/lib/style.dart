
import 'package:flutter/animation.dart';
import 'package:flutter/painting.dart';

// Design tokens from CleanFrame's style.css. Everything is laid out on a 1920×1080 canvas.

const ink = Color(0xFFF4F4F1);
const solid = Color(0xFFF3F3EF);
const solidInk = Color(0xFF141618);

const ease = Cubic(.2, .7, .2, 1);
const moveDuration = Duration(milliseconds: 180);
const fadeDuration = Duration(milliseconds: 120);
/// Overridable with --dart-define=WALLPAPER_FADE_MS=6000 to inspect the crossfade frame by frame.
const wallpaperFadeDuration = Duration(milliseconds: int.fromEnvironment('WALLPAPER_FADE_MS', defaultValue: 700));

const softShadow = [Shadow(offset: Offset(0, 1), blurRadius: 3, color: Color(0x38000000))];

/// Manrope is a variable font, so the weight is set through its `wght` axis as well.
TextStyle type(double size, {int weight = 500, double spacing = 0, Color color = ink, List<Shadow>? shadows}) =>
    TextStyle(
      fontFamily: 'Manrope',
      fontSize: size,
      fontWeight: FontWeight.values[weight ~/ 100 - 1],
      fontVariations: [FontVariation('wght', weight.toDouble())],
      letterSpacing: spacing,
      color: color,
      shadows: shadows,
    );

/// The frosted highlight behind the focused item.
const plate32 = BoxDecoration(
  borderRadius: BorderRadius.all(Radius.circular(32)),
  gradient: LinearGradient(
    begin: Alignment(-0.18, -1),
    end: Alignment(0.18, 1),
    colors: [Color(0x4DFFFFFF), Color(0x29FFFFFF), Color(0x38FFFFFF)],
    stops: [0, .58, 1],
  ),
);
