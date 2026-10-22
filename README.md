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

The Home redirect is an accessibility service. Turn it on once after the first install:

```sh
adb -s 192.168.50.76:5555 shell settings put secure enabled_accessibility_services com.lucas.tv_home/com.lucas.tv_home.HomeRedirectService
adb -s 192.168.50.76:5555 shell settings put secure accessibility_enabled 1
```

## Logos

`launcher/tool/marks.py` crops each SVG in `launcher/assets/icons` to its ink and sizes every logo
by one rule, writing `assets/marks/` and `lib/mark_sizes.dart`. `launcher/tool/check_marks.py`
measures the result from a real TV screenshot (see its docstring for the check build).

Wallpapers are from Unsplash, logos from Simple Icons (CC0) and Custom Brand Icons (MIT), and the
font is Manrope (OFL); licenses are alongside them in `launcher/assets`.
