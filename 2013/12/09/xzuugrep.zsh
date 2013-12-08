#!/bin/zsh

if [[ -z ${XZUUGREP+set} ]]; then
  export XZUUGREP="set"
  export ENV="$0";
  exec -a /bin/sh /bin/zsh /usr/bin/xzgrep "$@"
  exit 1
fi

xz() {
  typeset -a arg
  arg=("$@")

  shift $(($# - 1))
  read -r line <"$1"

  case "$line" in
  begin\ [0-7][0-7][0-7]\ *)
    uudecode -o - "$1"
    ;;
  *)
    command xz "${arg[@]}"
    ;;
  esac
}

alias /usr/bin/xz=xz

