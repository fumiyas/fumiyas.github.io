#!/bin/sh
##
## Unwrap wrapped-lines in LDIF data (pure shell version)
## Copyright (c) 2015 SATOH Fumiyasu @ OSS Technology Corp.
##               <http://www.OSSTech.co.jp/>
##
## License: GNU General Public License version 3
##

unset chunk

while IFS= read -r line; do
  case "$line" in
  ' '*)
    chunk="$chunk${line# }"
    ;;
  *)
    [ -n "${chunk+set}" ] && printf '%s\n' "$chunk"
    chunk="$line"
    ;;
  esac
done

[[ -n $chunk ]] && printf '%s\n' "$chunk"
 
