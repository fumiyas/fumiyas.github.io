#!/bin/zsh

set -u
emulate -R ksh

sudo renice -10 $$ >/dev/null

time2sec() {
  local time="$1"; shift
  local sep="${1-:}"

  local min="${time%%[:m]*}"
  local sec="${time##*[:m]}"
  if [[ $sec = $time ]]; then
    echo "$time"
  else
    let 'sec+=min*60'
    echo "$sec"
  fi
}

time_normalize() {
  local line

  while IFS= read -r line; do
    case "$line" in
    *\ total)
      local real user system
      real="${line%% total}"
      real="${real##* }"
      user="${line%%s user *}"
      user="${user##* }"
      system="${line%%s system *}"
      system="${system##* }"
      echo "$(time2sec $real) $(time2sec $user) $(time2sec $system)"
      ;;
    real\	*|user\	*|sys\	*)
      local minsec
      minsec="${line%s}"
      echo -n "$(time2sec "${minsec##*	}") "
      ;;
    *)
      if [[ -n $line ]]; then
	echo "$line" 1>&2
      fi
      ;;
    esac
  done
}

shells=(bash ksh zsh)

tput setaf 3
echo -n '|'
for shell in "${shells[@]}"; do
  printf ' %-14s |' "$shell"
done
echo
tput sgr0

typeset -A real
typeset -A user
typeset -A sys

cat sh-benchmark-scripts.sh \
|while read -r script; do
  if [[ -z ${script##\#*} ]]; then
    test_name="${script#* }"
    continue
  fi

  echo -n '|'
  for shell in "${shells[@]}"; do
    shell_path="/bin/${shell}"
    if [[ $shell = 'zsh' ]]; then
      shell_name="/bin/ksh"
    else
      shell_name="$shell_path"
    fi
    env - "$shell_path" -c "$script" "$shell_name" 2>&1 \
      |time_normalize \
      |read real[$shell] user[$shell] sys[$shell] \
    ;

    if [[ ${real[${shells[0]}]} -gt 0.0 ]]; then
      ratio=$(printf '%6.1f' $((real[$shell] / real[${shells[0]}] * 100)))
    else
      ratio=$(printf '%6s' -)
    fi
    printf '%6.2f (%s) |' "${real[$shell]}" "$ratio"
    ;
  done
  tput setaf 4
  echo " $test_name"
  tput sgr0
done

