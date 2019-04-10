#!/bin/bash

shopt -s lastpipe || exit $?

typeset -a groups_wo_member

getent group \
  |sed -n 's#:.*[^:]$##p' \
  |while IFS= read -r group; do
    groups_wo_member+=("$group")
  done \
;

echo "${#groups_wo_member[*]}"
(IFS=,; echo "${groups_wo_member[*]:-NOT FOUND}")

