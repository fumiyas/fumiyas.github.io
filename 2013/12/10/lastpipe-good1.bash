#!/bin/bash

typeset -a groups_wo_member

while IFS= read -r group; do
  groups_wo_member+=("$group")
done < <(getent group |sed -n 's#:.*[^:]$##p')

echo "${#groups_wo_member[*]}"
(IFS=,; echo "${groups_wo_member[*]:-NOT FOUND}")

