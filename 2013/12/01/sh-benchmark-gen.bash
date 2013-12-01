#!/bin/bash

set -u

wget -q -O - http://mywiki.wooledge.org/BashBenchmark \
|while read -r line; do
  [[ -z $line ]] && continue
  [[ -z ${line##*\{1..10*0\}*} ]] || continue
  line="${line##*<tt>}"
  line="${line%%</tt>*}"
  line="${line//&nbsp;/ }"
  line="${line//&gt;/>}"
  line="${line//&lt;/<}"
  line="${line/time /time (}"
  line="$line)"
  [[ -z ${line##*sh -c \':\' *} ]] && continue
  #n="${line##*\{1..}"
  #n="${n%%\}*}"
  #line="${line//\{1..10*0\}/\"\$@\"}"
  #echo -n "set -- {1..$n}; "
  echo "$line"
done \
;

