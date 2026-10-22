# Notes for working on this project

See README.md for what's here and how to build. The TV is an Insignia AFTDCT31 (Fire OS 7.7.1.7,
32-bit ARM) at `192.168.50.76:5555`; `launcher/tool/tv.sh` has adb helpers (`s`, `top`, `shot`).

## Testing on the TV

- Verify changes on the real TV (screenshots, `dumpsys`), and say plainly what was simulated with
  `adb shell input` versus pressed on the real remote: simulated keys skip some paths.
- Check the screen before sending key sequences. Blind sequences land in the wrong place.
- Never switch the accessibility service off and on to reload it. Repeated toggling stops it
  binding until a reboot, and right after a toggle Amazon's launcher sends it no events until the
  next screen change. Reinstall for code changes; a changed `home_redirect.xml` loads only after
  `adb reboot`. Check binding with `dumpsys accessibility`.
- The logcat buffer fills in minutes. To capture remote presses, record live to a file
  (`adb logcat | grep --line-buffered ...`); Amazon's `CallbackBaseManager_KeyPress` lines log
  every real key.
- Only D-pad, select and media keys reach accessibility key filtering; Fire OS takes Home, Alexa,
  Live TV, Settings, Recent apps and the app buttons first.
- If `adb connect` says "No route to host" while ping works, `adb kill-server` and retry.
- Release builds keep R8 off (it breaks shared_preferences).

## Design

- Ask before making visual design decisions; Lucas gives references and feedback first.
- Keep solutions simple; offer ambitious ones rather than shipping them unasked.
- Logo sizing: `launcher/tool/marks.py` (by kind, plus `NUDGES` from Lucas's review, applied
  literally), checked with `tool/check_marks.py` on a `--dart-define=MARK_CHECK=true` build.
