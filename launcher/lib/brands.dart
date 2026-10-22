import 'mark_sizes.dart';

/// White marks, keyed by Fire TV package name. Apps without one fall back to their installed icon.
/// assets/marks holds copies of assets/icons cropped to their ink by tool/marks.py, which also
/// works out each one's layout.
class Brand {
  const Brand(this.icon, this.name);

  final String icon;
  final String name;

  String get asset => 'assets/marks/$icon.svg';

  ({double width, double height, double dy}) get layout => markLayouts[icon]!;
}

const brands = <String, Brand>{
  'com.netflix.ninja': Brand('netflix', 'Netflix'),
  'com.amazon.firetv.youtube': Brand('youtube', 'YouTube'),
  'com.disney.disneyplus': Brand('disneyplus', 'Disney+'),
  'com.hbo.hbonow': Brand('hbomax', 'HBO Max'),
  'com.amazon.avod': Brand('primevideo', 'Prime Video'),
  'com.spotify.tv.android': Brand('spotify', 'Spotify'),
  'org.jellyfin.androidtv': Brand('jellyfin', 'Jellyfin'),
  'com.cbs.ott': Brand('paramountplus', 'Paramount+'),
  'com.tubitv': Brand('tubi', 'Tubi'),
  'com.tubitv.ott': Brand('tubi', 'Tubi'),
  'com.apple.atve.amazon.appletv': Brand('appletv', 'Apple TV'),
  'com.stremio.one': Brand('stremio', 'Stremio'),
  'com.hulu.plus': Brand('hulu', 'Hulu'),
  'com.peacock.peacockfiretv': Brand('peacock', 'Peacock'),
  'com.apple.airplay.amazon.airplay': Brand('airplay', 'AirPlay'),
};

String displayName(String pkg, String label) => brands[pkg]?.name ?? label;
