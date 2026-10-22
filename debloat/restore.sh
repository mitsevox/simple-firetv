#!/bin/bash
# Undoes the debloat: reinstalls packages in removed.log and re-enables those in disabled.log.
TV="${TV:-192.168.50.76:5555}"
cd "$(dirname "$0")"
s(){ adb -s "$TV" shell "$@" </dev/null 2>&1 | tr -d '\r'; }
[ -f removed.log ] && sort -u removed.log | while read -r p; do echo "$p: $(s cmd package install-existing "$p")"; done
[ -f disabled.log ] && sort -u disabled.log | while read -r p; do echo "$p: $(s pm enable --user 0 "$p")"; done
[ -f restricted.log ] && sort -u restricted.log | while read -r p; do echo "$p: $(s cmd appops set "$p" RUN_IN_BACKGROUND allow)"; done
