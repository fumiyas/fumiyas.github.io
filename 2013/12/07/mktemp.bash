#!/bin/bash
# or
#!/bin/ksh
#!/bin/zsh

if [[ -n $ZSH_VERSION ]]; then
  emulate -R ksh
  set -o BSD_ECHO
  set -o BRACE_CCL
  suffix_seeds=({0-9} {a-z} {A-Z})
else
  suffix_seeds=({0..9} {a..z} {A..Z})
fi

set -u

pdie() {
  echo "$0: ERROR: $1"
  exit 1
}

template="${1-/tmp/tmp.XXXXXXXXXX}"

temp_dir="${template%/*}"
if [[ $temp_dir = $template ]]; then
  temp_dir="."
fi

if [[ ! -d $temp_dir ]]; then
  pdie "No such temporary directory: $temp_dir"
fi
if [[ ! -w $temp_dir ]]; then
  pdie "No write permission on temporary directory: $temp_dir"
fi

prefix="$template"
x_num=0

while [[ -n $prefix ]] && [[ ${prefix%X} != $prefix ]]; do
  let x_num++
  prefix="${prefix%X}"
done

if [[ $x_num -lt 3 ]]; then
  pdie "Too few X's in template: $template"
fi

suffix_seeds_num="${#suffix_seeds[@]}"
let try='x_num * 10'

while [[ $try -gt 0 ]]; do
  let try--

  temp_file="$prefix"
  for (( x=x_num; x >0; x-- )); do
    temp_file+="${suffix_seeds[$(($RANDOM % $suffix_seeds_num))]}"
  done

  error=$(umask 0077; set -o noclobber; : 2>&1 >"$temp_file")
  if [[ $? -eq 0 ]]; then
    echo "$temp_file"
    exit 0
  fi
done

pdie "${error#*: }"

