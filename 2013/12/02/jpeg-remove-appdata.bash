#!/bin/bash
## or
#!/bin/ksh
## or
#!/bin/zsh
##
## JPEG: Remove application-specific data (e.g., EXIF)
## Copyright (c) 2013 SATOH Fumiyasu @ OSS Technology Corp., Japan
##
## License: GNU General Public Licenser version 3
##

## For zsh
builtin emulate -R ksh 2>/dev/null

set -u

pdie() {
  echo "$0: ERROR: $1" 1>&2
  exit ${2-1}
}

pdie_eof() {
  pdie "Bad JPEG data: $1: EOF"
}

pdie_marker() {
  pdie "Bad JPEG data: Invalid marker"
}

jpeg_file="$1"; shift

od -vtx1 "$jpeg_file" \
  |while read x data; do for hex in $data; do echo $hex; done; done \
  |{
    read marker1 || pdie_eof 'Reading marker 1'
    [[ $marker1 = ff ]] || pdie_marker
    read marker2 || pdie_eof 'Reading marker 2'

    if [[ $marker2 != d8 ]]; then ## SOI (Start Of Image)
      pdie "Bad JPEG data: No 'Start Of Image' marker found"
    fi
    echo $marker1 $marker2

    while :; do
      read marker1 || pdie_eof 'Reading marker 1'
      [[ $marker1 = ff ]] || pdie_marker
      read marker2 || pdie_eof 'Reading marker 2'

      case "$marker2" in
      e?)
	## APP0 (Application specific, e.g., EXIF)
	skip="set"
	;;
      *)
	## Others
	skip=""
	echo $marker1 $marker2
	if [[ $marker2 = da ]]; then
	  ## SOS (Start Of Scan)
	  cat
	  break
	fi
	;;
      esac

      read size1 || pdie_eof 'Reading size 1'
      read size2 || pdie_eof 'Reading size 2'
      [[ -n $skip ]] || echo $size1 $size2

      size_hex="$size1$size2"
      size=$((16#$size_hex))
      let size-=2

      while [[ $size -gt 0 ]]; do
	read hex || pdie_eof 'Reading data'
	[[ -n $skip ]] || echo $hex
	let size--
      done
    done
  } \
  |while read hex; do
    printf "\\x${hex// /\\x}"
  done \
;
