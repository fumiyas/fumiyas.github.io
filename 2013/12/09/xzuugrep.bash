#!/bin/bash

if [[ -z $XZUUGREP ]]; then
  export XZUUGREP="set"
  export BASH_ENV="$0";
  exec xzgrep "$@"
  exit 1
fi

xz() {
  local arg=("$@")

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

