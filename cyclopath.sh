#!/bin/sh
printf '\033c\033]0;%s\a' Cyclopath Journey
base_path="$(dirname "$(realpath "$0")")"
"$base_path/cyclopath.x86_64" "$@"
