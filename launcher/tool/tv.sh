# Helpers for driving the TV in tests, sourced by hand: s (adb shell), top (foreground activity),
# shot <file> (screenshot to PNG). Set TV to the TV's adb address if it isn't the default.
T="${TV:-192.168.50.76:5555}"
s(){ adb -s $T shell "$@" </dev/null 2>&1 | tr -d '\r' | grep -v 'Init wrapper'; }
top(){ s dumpsys activity activities | grep -m1 mResumedActivity | grep -oE 'u0 [^ ]+'; }
shot(){ adb -s $T exec-out screencap -p > /tmp/_tv.raw; python3 -c "
import sys;d=open('/tmp/_tv.raw','rb').read(); open(sys.argv[1],'wb').write(d[d.find(b'\x89PNG'):])" "$1"; }
