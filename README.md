# firetv-clean

A cleaner Insignia Fire TV (AFTDCT31, Fire OS 7.7.1.7).

- **`debloat/`**: removes or disables Amazon's ad, tracking and promo packages over ADB.
  `removed.log`, `disabled.log` and `restricted.log` record what was changed on the TV, and
  `restore.sh` undoes all of it.
- **`launcher/`**: a Flutter home screen (wallpaper, clock, weather, glass dock of white logos),
  styled after [CleanFrame](https://github.com/nthnclrk/CleanFrame). Its accessibility service sends
  the Home button here instead of Amazon's home screen.

## Build and install

```sh
cd launcher
flutter build apk --release --target-platform android-arm
adb connect 192.168.50.76:5555
adb -s 192.168.50.76:5555 install -r build/app/outputs/flutter-apk/app-release.apk
```

The Home redirect is an accessibility service, and the dock orders itself by usage stats. Turn
both on once after the first install:

```sh
adb -s 192.168.50.76:5555 shell settings put secure enabled_accessibility_services com.lucas.tv_home/com.lucas.tv_home.HomeRedirectService
adb -s 192.168.50.76:5555 shell settings put secure accessibility_enabled 1
adb -s 192.168.50.76:5555 shell appops set com.lucas.tv_home GET_USAGE_STATS allow
```

Don't switch the service off and on to pick up changes: done repeatedly, it stops binding until
the TV reboots. Reinstalling is enough for code changes; a changed `home_redirect.xml` takes
effect after the next reboot.

Home lands here after Android's ~5 s post-Home delay (covered by the wallpaper). Two other
buttons are quicker because they don't trigger that delay: Recent apps (~1 s) and Live TV (~2 s,
after Amazon's guide shows its loading screen). Live TV no longer opens the guide.

## Logos

`launcher/tool/marks.py` crops each SVG in `launcher/assets/icons` to its ink and lays it out by
kind (wordmarks on a shared baseline and x-height, symbols by silhouette area), plus per-logo
optical nudges in `NUDGES`, writing `assets/marks/` and `lib/mark_sizes.dart`. `launcher/tool/check_marks.py`
measures the result from a real TV screenshot (see its docstring for the check build).

Wallpapers are from Unsplash, logos from Simple Icons (CC0) and Custom Brand Icons (MIT), and the
font is Manrope (OFL); licenses are alongside them in `launcher/assets`.
