#!/usr/bin/env bash
# abclock 安装脚本：取上游 gtklock 指定 tag，打补丁，编译，装包装器与布局。
set -euo pipefail

PREFIX=${PREFIX:-$HOME/.local}
GTKLOCK_TAG=${GTKLOCK_TAG:-v5.0.0}
GTKLOCK_REPO=${GTKLOCK_REPO:-https://github.com/jovanlanik/gtklock}
CONFIG_DIR=${XDG_CONFIG_HOME:-$HOME/.config}/gtklock

here=$(cd "$(dirname -- "$0")" && pwd)
patch_file="$here/patch/gtklock-$GTKLOCK_TAG-clock.patch"

if [ ! -f "$patch_file" ]; then
	echo "找不到补丁 $patch_file（只针对 $GTKLOCK_TAG）" >&2
	exit 1
fi

for tool in git meson ninja pkg-config; do
	command -v "$tool" >/dev/null || { echo "缺少依赖：$tool" >&2; exit 1; }
done

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

echo "==> 克隆 $GTKLOCK_REPO ($GTKLOCK_TAG)"
git clone -q --depth 1 --branch "$GTKLOCK_TAG" "$GTKLOCK_REPO" "$tmp/src"

echo "==> 应用补丁 $(basename "$patch_file")"
git -C "$tmp/src" apply "$patch_file"

echo "==> 编译"
meson setup "$tmp/src/build" "$tmp/src" --prefix=/usr >/dev/null
ninja -C "$tmp/src/build" >/dev/null

echo "==> 安装到 $PREFIX"
install -Dm755 "$tmp/src/build/gtklock" "$PREFIX/libexec/abclock/gtklock-bin"
install -Dm755 "$here/bin/gtklock" "$PREFIX/bin/gtklock"
install -Dm644 "$here/share/layout.xml" "$CONFIG_DIR/layout.xml"

cat <<EOF

完成：
  $PREFIX/bin/gtklock                    包装器（时区 + LC_TIME + -x layout）
  $PREFIX/libexec/abclock/gtklock-bin    打过补丁的 gtklock
  $CONFIG_DIR/layout.xml                 三行布局（空行 / 时间 / 日期）

还需要在 $CONFIG_DIR/config.ini 的 [main] 段设置格式（已存在则替换）：

  time-format=%H:%M:%S
  date-format=%Y-%m-%d %ea %A

想让任意路径的 gtklock 都走包装器（含 /usr/bin/gtklock、bash 命令哈希），
以 root 再执行一次：

  PREFIX=/usr/local ./install.sh
  ln -sf /usr/local/bin/gtklock /usr/bin/gtklock
EOF