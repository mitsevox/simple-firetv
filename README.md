# Simple FireTV

A calmer Fire TV: debloat scripts and a minimal Flutter launcher, built on an Insignia Fire TV
(AFTDCT31, Fire OS 7.7.1.7).

- **`debloat/`**: removes or disables Amazon's ad, tracking and promo packages over ADB.
  `removed.log`, `disabled.log` and `restricted.log` record what was changed on the TV, and
  `restore.sh` undoes all of it.
- **`launcher/`**: a Flutter home screen (wallpaper, clock, weather, glass dock of white logos,
  and a Spotify now-playing strip), styled after [CleanFrame](https://github.com/nthnclrk/CleanFrame).
  Its accessibility service sends the Home button here instead of Amazon's home screen.

## Build and install

Turn on ADB debugging on the TV (Settings → My Fire TV → Developer options) and set `TV` to its
address. The scripts in `debloat/` and `launcher/tool/` read the same variable.

```sh
export TV=192.168.50.76:5555
cd launcher
flutter build apk --release --target-platform android-arm
adb connect $TV
adb -s $TV install -r build/app/outputs/flutter-apk/app-release.apk
```

The Home redirect is an accessibility service, the dock orders itself by usage stats, and the
now-playing strip reads Spotify's media session through a notification listener. Turn all three on
once after the first install:

```sh
adb -s $TV shell settings put secure enabled_accessibility_services com.lucas.tv_home/com.lucas.tv_home.HomeRedirectService
adb -s $TV shell settings put secure accessibility_enabled 1
adb -s $TV shell appops set com.lucas.tv_home GET_USAGE_STATS allow
adb -s $TV shell cmd notification allow_listener com.lucas.tv_home/com.lucas.tv_home.MediaListener
```

Don't switch the service off and on to pick up changes: done repeatedly, it stops binding until
the TV reboots. Reinstalling is enough for code changes; a changed `home_redirect.xml` takes
effect after the next reboot.

Home lands here after Android's ~5 s post-Home delay (covered by the wallpaper). Two other
buttons are quicker because they don't trigger that delay: Recent apps (~1 s) and Live TV (~2 s,
after Amazon's guide shows its loading screen). Live TV no longer opens the guide.

The weather under the clock is for the spot set as `weatherLocation` in
`launcher/lib/weather.dart` (null hides it).

## Now playing

Above the dock, Spotify's current track runs the full dock width with progress and controls while
it plays, and shrinks to half width, centred, when paused or stopped (keeping the last track). It
only sees what plays on the TV itself. The strip resizes 1.5 s after the state changes: resizing
while Spotify starts playback measured 20–60 ms frames on the TV, against ~14 ms once it settles,
which is what the dock's own animations take. Spotify isn't on the dock any more; it's still in All
apps, and selecting the track opens it.

On the home screen the remote's play/pause, fast-forward and rewind buttons control Spotify too
(pause/play, next, previous), wherever focus is; otherwise Fire OS sends them to another player.

## Logos

`launcher/tool/marks.py` crops each SVG in `launcher/assets/icons` to its ink and lays it out by
kind (wordmarks on a shared baseline and x-height, symbols by silhouette area), plus per-logo
optical nudges in `NUDGES`, writing `assets/marks/` and `lib/mark_sizes.dart`. `launcher/tool/check_marks.py`
measures the result from a real TV screenshot (see its docstring for the check build).

Wallpapers are from Unsplash, logos from Simple Icons (CC0) and Custom Brand Icons (MIT), and the
font is Manrope (OFL); licenses are alongside them in `launcher/assets`.

The code is MIT licensed (see `LICENSE`); the bundled assets keep their own licenses.
