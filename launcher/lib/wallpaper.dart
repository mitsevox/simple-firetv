import 'dart:async';
import 'dart:convert';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'style.dart';

class WallpaperInfo {
  const WallpaperInfo({required this.id, required this.credit, required this.light});

  final String id;
  final String credit;

  /// Light photos need a stronger veil behind the dock to keep it readable.
  final bool light;

  String get asset => 'assets/wallpapers/$id.jpg';
}

/// One wallpaper, ready to draw: the photo cropped to the screen, and a blurred copy cropped
/// identically for the glass. Both are made before the frame is published, so the photo and the
/// glass always change together.
class WallpaperFrame {
  const WallpaperFrame({required this.info, required this.photo, required this.blurred});

  final WallpaperInfo info;
  final ui.Image photo;
  final ui.Image blurred;

  void dispose() {
    photo.dispose();
    blurred.dispose();
  }
}

/// The bundled Unsplash photos. Blurring once per photo instead of every frame keeps the 32-bit
/// Fire TV chip smooth.
class WallpaperStore extends ChangeNotifier {
  static const _indexKey = 'wallpaper';
  static const _channel = MethodChannel('tv_home/apps');
  static const _screen = Size(1920, 1080);
  static const _blurSize = Size(480, 270);

  List<WallpaperInfo> all = [];
  int _index = 0;
  WallpaperFrame? frame;

  Future<void> load() async {
    final sources = jsonDecode(await rootBundle.loadString('assets/wallpapers/SOURCES.json')) as List;
    all = [
      for (final s in sources.cast<Map<String, dynamic>>())
        WallpaperInfo(id: s['id'] as String, credit: s['credit'] as String, light: s['tone'] == 'light'),
    ];
    final prefs = await SharedPreferences.getInstance();
    _index = (prefs.getInt(_indexKey) ?? 0) % all.length;
    await _show();
  }

  Future<void> next() async {
    if (all.isEmpty) return;
    _index = (_index + 1) % all.length;
    await _show();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_indexKey, _index);
  }

  Future<void> _show() async {
    final info = all[_index];
    final data = await rootBundle.load(info.asset);
    final codec = await ui.instantiateImageCodec(data.buffer.asUint8List());
    final source = (await codec.getNextFrame()).image;

    // Same crop for both, matching BoxFit.cover on a 1920×1080 screen.
    final crop = applyBoxFit(
      BoxFit.cover,
      Size(source.width.toDouble(), source.height.toDouble()),
      _screen,
    ).source;
    final cropRect = Alignment.center.inscribe(crop, Offset.zero & Size(source.width.toDouble(), source.height.toDouble()));
    final photo = await _draw(source, cropRect, _screen);
    final blurred = await _draw(
      source,
      cropRect,
      _blurSize,
      ui.ImageFilter.blur(sigmaX: 12, sigmaY: 12, tileMode: TileMode.clamp),
    );
    source.dispose();

    final previous = frame;
    frame = WallpaperFrame(info: info, photo: photo, blurred: blurred);
    notifyListeners();
    // The outgoing frame is still on screen until its crossfade finishes.
    if (previous != null) Timer(wallpaperFadeOut, previous.dispose);

    // The Home redirect shows this photo while Android holds back our launch after a Home press.
    await _channel.invokeMethod('wallpaperChanged', {'asset': info.asset});
  }

  // Long enough for the outgoing frame to finish fading out.
  static final wallpaperFadeOut = wallpaperFadeDuration * 3;

  static Future<ui.Image> _draw(ui.Image source, Rect crop, Size size, [ui.ImageFilter? filter]) {
    final recorder = ui.PictureRecorder();
    Canvas(recorder).drawImageRect(
      source,
      crop,
      Offset.zero & size,
      Paint()
        ..filterQuality = FilterQuality.medium
        ..imageFilter = filter,
    );
    return recorder.endRecording().toImage(size.width.toInt(), size.height.toInt());
  }
}
