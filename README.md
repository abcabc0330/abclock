# abclock

gtklock 5.0.0 的锁屏小补丁 + 统一入口包装器：**北京时间、三行布局、英文缩写 + 中文星期**。

名字来自 `ab` + `clock`，与上游 `jovanlanik/gtklock` 无关；上游代码保持原样，本仓库只提供补丁与打包脚本。

## 解决的问题

| 现象 | 原因 |
|---|---|
| `date-format=%a %A` 得到 `一 星期一` | `LC_TIME=zh_CN.utf8` 下 `%a`（abday）本身就是中文「一」，拿不到 `Fri` |
| 直接敲 `gtklock` 显示的是系统本地时间 | 时区只在锁屏脚本里 `export TZ`，换个入口就丢 |
| 同一秒内秒针看起来滞后最多 1 秒 | 上游 `g_timeout_add(1000, …)` 每秒才刷新一次 |
| 用 `%3f`/`%.3f` 想看毫秒得到空白 | GLib 只认 `%f`（6 位微秒），宽度修饰符一律返回 NULL |

## 补丁做了什么

`patch/gtklock-v5.0.0-clock.patch`（约 30 行，仅动 `src/gtklock.c`）：

1. **新增 `%ea` 格式符** —— 输出英文三字母星期（`Mon`…），直接由 `g_date_time_get_day_of_week()` 取，不依赖 locale，因此可以和 `%A`（`星期一`）组合成 `Mon 星期一`。
2. **时钟刷新 1000ms → 100ms** —— 只把「秒」的显示滞后压到 0.1s 以内，屏幕上**不显示毫秒**。
3. 时间与日期统一走新增的 `format_datetime_custom()`，其余格式符仍交给 `g_date_time_format()`，行为与上游一致。

## 包装器做了什么

`bin/gtklock` 是自定位的 POSIX sh 脚本，`exec` 后端二进制前固定：

```sh
export TZ=Asia/Shanghai
export LC_TIME=zh_CN.utf8
exec .../gtklock-bin -x <layout.xml> "$@"
```

因此 `$mod+Escape`、`swayidle`、`swaymsg exec gtklock`、终端里直接敲 `gtklock`、乃至 bash 哈希缓存里存着的 `/usr/bin/gtklock`，都会落到同一个入口。可用 `ABCLOCK_TZ` / `ABCLOCK_LC_TIME` / `ABCLOCK_LAYOUT` / `ABCLOCK_BIN` 覆盖。

布局优先用 `~/.config/gtklock/layout.xml`，没有则回退到系统共享的 `/usr/share/abclock/layout.xml`（AUR 包安装的是后者）。

`share/layout.xml` 在默认布局外只增加一个空行标签，使时间落在第 2 行、日期第 3 行；上游所有控件 id（`clock-label`、`date-label`、`input-field`、`unlock-button`、`message-revealer` 等）与信号原样保留。

## 依赖

Arch：

```sh
sudo pacman -S --needed gtk3 gtk-session-lock pam meson ninja git
```

其他发行版需等价包：GTK3 开发头文件、[gtk-session-lock](https://github.com/cuadrade/gtk-session-lock) 0.2+、pam 头文件。

PAM 服务名在源码里写死为 `gtklock`，因此 `/etc/pam.d/gtklock` 必须存在（发行版装 gtklock 包即会提供）。

## 安装

### AUR（推荐，系统级）

```sh
yay -S abclock        # 或 paru -S abclock
```

包把后端装到 `/usr/libexec/abclock/gtklock-bin`、包装器装到 `/usr/bin/gtklock`（另有 `/usr/bin/abclock` 同名别名）、布局装到 `/usr/share/abclock/layout.xml`，并 `provides=('gtklock') conflicts=('gtklock')` —— 它会取代发行版的 gtklock（`/etc/pam.d/gtklock` 由本包提供）。

### 脚本（用户级，不碰系统）

```sh
git clone https://github.com/abcabc0330/abclock
cd abclock
./install.sh                     # 默认装到 ~/.local
```

装出来的东西：

```
~/.local/bin/gtklock                      包装器
~/.local/libexec/abclock/gtklock-bin      补丁版 gtklock
~/.config/gtklock/layout.xml              三行布局
```

然后在 `~/.config/gtklock/config.ini` 的 `[main]` 段写：

```ini
time-format=%H:%M:%S
date-format=%Y-%m-%d %ea %A
```

背景、主题、样式参考 `share/config.ini.example` 与 `share/style.css.example`。

### 让所有路径都生效（可选但推荐）

bash 的命令哈希、绝对路径 `/usr/bin/gtklock`、`swaymsg exec` 都可能绕过 `~/.local/bin`：

```sh
sudo PREFIX=/usr/local ./install.sh
sudo ln -sf /usr/local/bin/gtklock /usr/bin/gtklock
```

（先备份发行版原二进制，例如 `mv /usr/bin/gtklock /usr/bin/gtklock.stock`。注意升级 gtklock 包会覆盖该符号链接。）

## 验证

锁屏后连续抓两帧，确认时间与系统北京时间一致、日期为 `Mon 星期一`、无毫秒：

```sh
export XDG_RUNTIME_DIR=/run/user/1000 WAYLAND_DISPLAY=wayland-1
gtklock >/tmp/gk.log 2>&1 &
sleep 2
TZ=Asia/Shanghai date '+%T'; grim /tmp/a.png
pkill -USR1 -x gtklock          # gtklock 的解锁信号，回到会话
```

## 卸载

```sh
./uninstall.sh                 # 删包装器/后端/layout，保留你自己的 config.ini 与 style.css
```

## 与上游的关系

- 上游：<https://github.com/jovanlanik/gtklock>（GPL-3.0），本仓库不重新分发其源码，安装时按 tag 克隆后打补丁。
- 补丁只针对 `v5.0.0`；上游若改动 `src/gtklock.c` 的时钟函数，`git apply` 会失败而不是静默套错。

## License

GPL-3.0，见 [LICENSE](LICENSE)。

## 隐形密码框（看不到输入、回车即校验）

`style.css.example` 默认把输入框、`Password:` 标签、`Unlock` 按钮和提示条设成 `opacity: 0`；
控件仍然存在并可聚焦，所以直接打字 + 回车照常走 PAM 校验，屏幕上不会显示任何字符或提示。

不需要这个行为时，删掉样式末尾那段 `opacity: 0` 规则即可。

## 密码校验

包会把 `/etc/pam.d/gtklock` 覆盖成独立严格栈（`auth required pam_unix.so`），
不再 `include login`。原因：本机 `system-auth` 里 `pam_unix` 失败后有一条
`auth optional pam_permit.so` 兜底，`include` 会让锁屏接受**任意密码**。

自检：

```sh
printf 'wrong\n' | pamtester gtklock "$USER" authenticate   # 应失败
```
