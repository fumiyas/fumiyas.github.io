#!/bin/sh
# or
#!/bin/bash
#!/bin/ksh
#!/bin/zsh

if [ -n "${BASH_VERSION-}" ]; then
  sh_name='bash'
  sh_ver_major="${BASH_VERSINFO[0]}"
  sh_ver_minor="${BASH_VERSINFO[1]}"
  sh_ver_micro="${BASH_VERSINFO[2]}"
  sh_ver="$sh_ver_major.$sh_ver_minor.$sh_ver_micro"
  sh_ver_number=$(printf '%d%03d%03d' "$sh_ver_major" "$sh_ver_minor" "$sh_ver_micro")
  sh_mode="${BASH##*/}"
elif [ -n "${ZSH_VERSION-}" ]; then
  sh_name="zsh"
  sh_ver="$ZSH_VERSION"
  sh_mode=$(emulate)
  sh_ver_major="${ZSH_VERSION%%.*}"
  sh_ver_minor="${ZSH_VERSION%.*}"
  sh_ver_minor="${sh_ver_minor#*.}"
  sh_ver_micro="${ZSH_VERSION##*.}"
  sh_ver_number=$(printf '%d%03d%03d' "$sh_ver_major" "$sh_ver_minor" "$sh_ver_micro")
elif [ -n "${RANDOM-}" ]; then
  sh_name="ksh"
  if PATH= type builtin >/dev/null 2>&1; then
    sh_ver="93"
  else
    sh_ver="88"
  fi
  sh_ver_marjo="$sh_ver"
  sh_ver_int="$sh_ver"
else
  sh_name="sh"
fi

echo "Name: $sh_name"
echo "Version: ${sh_ver--}"
[ -n "$sh_ver_number" ] && echo "  Number: $sh_ver_number"
[ -n "$sh_ver_major" ] && echo "  Major: $sh_ver_major"
[ -n "$sh_ver_minor" ] && echo "  Minor: $sh_ver_minor"
[ -n "$sh_ver_micro" ] && echo "  Micro: $sh_ver_micro"
echo "Mode: ${sh_mode--}"

