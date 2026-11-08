#!/usr/bin/env bash
# abclock 卸载：删除包装器与后端二进制；用户自己的 config.ini / style.css 不动。
set -euo pipefail

PREFIX=${PREFIX:-$HOME/.local}
CONFIG_DIR=${XDG_CONFIG_HOME:-$HOME/.config}/gtklock

rm -f "$PREFIX/bin/gtklock"
rm -rf "$PREFIX/libexec/abclock"
rm -f "$CONFIG_DIR/layout.xml"

cat <<EOF
已删除：
  $PREFIX/bin/gtklock
  $PREFIX/libexec/abclock/
  $CONFIG_DIR/layout.xml

若曾把 /usr/bin/gtklock 指向包装器，恢复系统二进制：
  rm /usr/bin/gtklock && mv /usr/bin/gtklock.stock /usr/bin/gtklock
EOF