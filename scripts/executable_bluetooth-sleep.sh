#!/bin/bash

# https://unix.stackexchange.com/questions/539762/how-do-i-suspend-sleep-while-bluetooth-is-active

# Disable bluetooth given first argument "start"
# Re-enable bluetooth given first argument "stop"
# Expects vendor and product as 2nd and 3rd arguments

set -eu

usage() {
  script_name=${0##*/}
  printf '%s: de-authorise bluetooth during sleep/suspend\n' "$script_name" >&2
  printf 'Usage: %s (start|stop) <vendor> <product>\n' "$script_name" >&2
  exit 1
}

case "${1:-}" in
  start) value=0 ;;
  stop)  value=1 ;;
  *)     usage   ;;
esac

[ $# -ne 3 ] && usage
vendor=$2
product=$3

shopt -s nullglob
for dir in /sys/bus/usb/devices/*; do
  if [[ -L "$dir" && -f $dir/idVendor && -f $dir/idProduct &&
        $(cat "$dir/idVendor")  == "$vendor" &&
        $(cat "$dir/idProduct") == "$product" ]]; then
    echo "$value" > "$dir/authorized"
    echo "echo $value > $dir/authorized"
  fi
done
