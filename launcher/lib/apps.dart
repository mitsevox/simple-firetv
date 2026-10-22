import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppInfo {
  const AppInfo({required this.package, required this.label, required this.icon});

  final String package;
  final String label;
  final Uint8List icon;
}

/// Installed apps, plus which ones are on the dock and in what order.
class AppStore extends ChangeNotifier {
  static const _channel = MethodChannel('tv_home/apps');
  static const _pinnedKey = 'pinned';

  /// Used until the dock is customized; apps that aren't installed are skipped.
  static const _defaultDock = [
    'org.jellyfin.androidtv',
    'com.netflix.ninja',
    'com.amazon.firetv.youtube',
    'com.disney.disneyplus',
    'com.hbo.hbonow',
    'com.hulu.plus',
    'com.amazon.avod',
    'com.peacock.peacockfiretv',
    'com.cbs.ott',
    'com.spotify.tv.android',
  ];

  List<AppInfo> all = [];
  List<String> _pinned = [];

  List<AppInfo> get dock {
    final byPackage = {for (final app in all) app.package: app};
    return [for (final pkg in _pinned) ?byPackage[pkg]];
  }

  bool isPinned(String pkg) => _pinned.contains(pkg);

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = await _channel.invokeListMethod<Map<Object?, Object?>>('list') ?? [];
    all = [
      for (final m in raw)
        AppInfo(
          package: m['package'] as String,
          label: m['label'] as String,
          icon: m['icon'] as Uint8List,
        ),
    ]..sort((a, b) => a.label.toLowerCase().compareTo(b.label.toLowerCase()));
    _pinned = prefs.getStringList(_pinnedKey) ?? List.of(_defaultDock);
    notifyListeners();
  }

  Future<void> togglePin(String pkg) async {
    if (isPinned(pkg)) {
      _pinned.remove(pkg);
    } else {
      _pinned.add(pkg);
    }
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_pinnedKey, _pinned);
  }

  static Future<void> launch(String pkg) => _channel.invokeMethod('launch', {'package': pkg});

  /// Opens one Fire OS settings screen, by its activity name in com.amazon.tv.settings.v2.
  static Future<void> openSettingsPage(String activity) =>
      _channel.invokeMethod('openSettingsPage', {'activity': activity});

  /// Opens Amazon's full Settings, which lives inside its home screen, so the Home redirect holds
  /// off while it opens.
  static Future<void> openFireSettings() => _channel.invokeMethod('openFireSettings');

  /// Opens Amazon's home screen and pauses the Home redirect for 5 minutes.
  static Future<void> openFireHome() => _channel.invokeMethod('openFireHome');
}
