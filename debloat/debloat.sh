#!/bin/bash
# Removes packages in remove-list.txt for user 0 and logs successes to removed.log.
TV="${TV:-192.168.50.76:5555}"
cd "$(dirname "$0")"
while read -r pkg; do
  [ -z "$pkg" ] && continue
  out=$(adb -s "$TV" shell pm uninstall -k --user 0 "$pkg" < /dev/null 2>&1 | tr -d '\r')
  echo "$pkg: $out"
  [ "$out" = "Success" ] && echo "$pkg" >> removed.log
done < remove-list.txt
