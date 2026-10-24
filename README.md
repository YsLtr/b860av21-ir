# B860AV2.1 红外遥控 keymap（主线 Linux / meson-ir）

本仓库提供中兴 B860AV2.1 配套遥控器（NEC 地址 `0x22`，观察到的 `factory_code` 为 `0xDD220001`）在主线 Linux 上的 31 个扫描码映射，以及一个范围明确、可审查、可回滚的安装脚本。它复用内核自带的 **meson-ir + rc-core + NEC 解码器**，自身只负责“扫描码 → Linux `KEY_*`”的整理与持久化。

## 一、来源

- 扫描码取自观察到的 Android 遥控配置 `system/etc/remote_dd22.conf` 中的事实性数据，观察到的 `factory_code` 为 `0xDD220001`。
- 标准 NEC 中 `0x22` 与 `0xDD` 是互补地址字节，因此本表采用主线扫描码形式 `(0x22 << 8) | command`，例如电源 `0x22dc`、上 `0x22ca`、OK `0x22ce`。
- 映射值使用 Linux `KEY_*`：HOME → `KEY_HOMEPAGE`，设置 → `KEY_SETUP`，OK → `KEY_ENTER`。应用如何响应这些事件由应用自身决定。
- 解码与输入链路由上游 Linux 内核和 v4l-utils 提供；本仓库只包含整理后的映射、安装脚本、隔离测试与文档。
- 原创脚本、配置整理与文档按 **GPL-2.0-or-later** 提供，见 [NOTICE](NOTICE) 与 [LICENSE](LICENSE)；事实性扫描码的整理基于观察记录。
- 参考环境：B860AV2.1、Armbian noble、aarch64、`6.12.37-ophub`，参考机已验证重启后加载 31 个映射。配套 WiFi 源码与板级供电适配见 [b860av21-wifi](https://github.com/YsLtr/b860av21-wifi)。

## 二、内容

| 文件 | 作用 |
|---|---|
| [zte_b860av21.toml](zte_b860av21.toml) | 单协议 `nec` keymap，31 个扫描码到 `KEY_*` 的映射 |
| [install.sh](install.sh) | 只读识别设备 + 安装持久化配置；`--stage DIR` 供隔离测试使用 |
| [tests/test.sh](tests/test.sh) | 无硬件回归测试，模拟 sysfs 与 `/etc` |
| [NOTICE](NOTICE)、[LICENSE](LICENSE) | 许可声明与 GPL v2 全文 |

映射内容：

| 功能 | 扫描码 | KEY_* | 功能 | 扫描码 | KEY_* |
|---|---|---|---|---|---|
| 电源 | `0x22dc` | `KEY_POWER` | 静音 | `0x229c` | `KEY_MUTE` |
| OK | `0x22ce` | `KEY_ENTER` | 上 | `0x22ca` | `KEY_UP` |
| 下 | `0x22d2` | `KEY_DOWN` | 左 | `0x2299` | `KEY_LEFT` |
| 右 | `0x22c1` | `KEY_RIGHT` | 返回 | `0x2295` | `KEY_BACK` |
| HOME | `0x2288` | `KEY_HOMEPAGE` | 设置 | `0x228d` | `KEY_SETUP` |
| 菜单 | `0x2282` | `KEY_MENU` | 音量+ | `0x2280` | `KEY_VOLUMEUP` |
| 音量− | `0x2281` | `KEY_VOLUMEDOWN` | 频道+ | `0x2285` | `KEY_CHANNELUP` |
| 频道− | `0x2286` | `KEY_CHANNELDOWN` | 红 | `0x22cd` | `KEY_RED` |
| 绿 | `0x2283` | `KEY_GREEN` | 黄 | `0x2291` | `KEY_YELLOW` |
| 蓝 | `0x22c3` | `KEY_BLUE` | 1 | `0x2292` | `KEY_1` |
| 2 | `0x2293` | `KEY_2` | 3 | `0x22cc` | `KEY_3` |
| 4 | `0x228e` | `KEY_4` | 5 | `0x228f` | `KEY_5` |
| 6 | `0x22c8` | `KEY_6` | 7 | `0x228a` | `KEY_7` |
| 8 | `0x228b` | `KEY_8` | 9 | `0x22c4` | `KEY_9` |
| 0 | `0x2287` | `KEY_0` | DEL | `0x22d0` | `KEY_BACKSPACE` |
| `#` / info | `0x22da` | `KEY_INFO` | | | |

## 三、作用

1. **翻译**：把遥控器的 NEC 扫描码转换为 Linux 输入事件，桌面、媒体中心与自建应用据此响应。
2. **持久化**：安装 `/etc/rc_keymaps/zte_b860av21.toml`，并在 `/etc/rc_maps.cfg` 增加一行 `meson-ir * zte_b860av21.toml`；发行版既有的 udev / ir-keytable 机制在开机时按表加载。
3. **限定范围**：安装器只改动这两个文件，运行中的键表、协议、服务与启动配置保持原状；让运行环境生效是使用者显式执行的一步。

## 四、使用方式

### 1. 只读确认设备

```sh
ir-keytable
for dev in /sys/class/rc/rc*; do
    [ -f "$dev/uevent" ] || continue
    printf '\n%s\n' "$dev"
    cat "$dev/uevent"
done
```

目标设备带 `DRV_NAME=meson-ir`；CEC 设备属于另一类设备。设备编号由枚举顺序决定，按当次 `uevent` 输出取实际名称，重启后重新确认。

### 2. 安装持久化文件

先获取源码（keymap 为纯配置文件，取得后即可使用），阅读并信任 [install.sh](install.sh) 与 [zte_b860av21.toml](zte_b860av21.toml) 之后执行：

```sh
git clone https://github.com/YsLtr/b860av21-ir.git
cd b860av21-ir
sudo sh ./install.sh --install
```

安装器依次执行：

- 要求 root，固定工具搜索路径，从 sysfs 识别唯一一个 `meson-ir` 设备；没有设备或存在多个设备时退出并提示人工检查。
- 检查目标路径：要求路径为普通文件、属主为当前用户、且组/其他用户无写权限；符号链接及其他情形会退出并提示。
- 检查 `/etc/rc_maps.cfg`：保留无关行，去重本项目的 `meson-ir * zte_b860av21.toml`；遇到其他 `meson-ir` 行，或会匹配本设备默认表名的通配驱动行（含 `* *`）时退出，交由人工核对冲突。
- 修改前建立私有备份目录 `/etc/b860av21-ir.backup.XXXXXXXX/`，保存原配置与原同名 keymap；原文件缺失时写入对应 `.absent` 标记。
- 安装 `/etc/rc_keymaps/zte_b860av21.toml` 并更新 `/etc/rc_maps.cfg`。重复运行保持幂等：内容完全一致时报告 `Already installed` 并沿用现有备份。
- 结束时打印实际设备名与下一步的 `-a` 命令。

安装器新增的规则只有这一行：

```text
meson-ir * zte_b860av21.toml
```

### 3. 明确加载并验证

这一步让配置对运行中的输入系统生效，用安装器打印的实际设备名替换下面示例中的 `rcN`：

```sh
RC=rcN
sudo ir-keytable -s "$RC" -r
sudo ir-keytable -s "$RC" -a /etc/rc_maps.cfg
sudo ir-keytable -s "$RC" -r
sudo ir-keytable -s "$RC" -t
```

首次加载前把 `-r` 的输出留作本机对照。加载后核对读回的扫描码与本表一致、NEC 协议已启用、输出无错误。在 `-t` 中先测方向、OK、返回等无破坏性按键，再逐个测数字、音量、彩色键，同时观察应用层行为；按下、释放与长按重复一并确认，最后测电源键，按 Ctrl-C 退出。

### 4. 开机自动加载

发行版既有的 udev / ir-keytable 规则会读取 `/etc/rc_maps.cfg`，安装器沿用这套机制，本身不创建服务。计划内重启后重新识别设备并用 `-r` 确认自动加载结果；需要时用第 3 节的 `-a` 命令显式加载。

### 5. 回滚

选择**需要恢复到的那一次安装前**的备份（重复安装会产生新备份，按时间与内容挑选），以 root shell 执行，先把 `B` 改成实际输出的备份目录：

```sh
sudo -s
B=/etc/b860av21-ir.backup.XXXXXXXX
ls -ld "$B" /etc/rc_maps.cfg /etc/rc_keymaps
ls -la "$B"
for name in rc_maps.cfg zte_b860av21.toml; do
    target=/etc/rc_maps.cfg
    [ "$name" != zte_b860av21.toml ] || target=/etc/rc_keymaps/zte_b860av21.toml
    if [ -f "$B/$name" ] && [ ! -L "$B/$name" ]; then
        cp -p -- "$B/$name" "$target" || break
    elif [ -f "$B/$name.absent" ]; then
        rm -f -- "$target" || break
    else
        printf 'Missing backup: %s; STOP\n' "$name" >&2
        break
    fi
done
exit
```

备份之后若还有其他人或软件包做的配置改动，把旧配置与这些改动人工合并后再落地。回滚只恢复文件；内存中的键表按第 3 节的命令重新加载，或在确认原持久化配置已恢复后安排计划内重启，让驱动与原加载机制重新初始化，再用 `-r` 验证。

### 6. 无硬件回归测试

```sh
sh -n install.sh
sh -n tests/test.sh
sh tests/test.sh
```

[测试脚本](tests/test.sh) 在 `mktemp` 创建的私有目录中模拟 sysfs 与 `/etc`，调用 `--stage`，覆盖首次安装、原文件备份、缺失标记、幂等、重复规则、冲突、缺失/多个设备、符号链接、权限异常与锁，普通用户即可运行。

## 五、边界、限制与禁止事项

本项目的适用范围与操作约束集中在本节。

### 能力与验证边界

- 本项目是配置与安装脚本：不新增内核驱动、不刷机、不改设备树/时钟/红外硬件时序、不提供 ROM。解码与输入链路由内核 meson-ir + rc-core 完成。
- 适配这份遥控器配置对应的硬件组合；B860 系列不同后缀、板卡、固件与遥控器配置不同，兼容性按实际硬件确认。
- 读回 keymap 并显示 31 个键，与 31 个键逐一实按测试是两件事；安装器测试属于软件测试，硬件结果按第 3 节自行记录。
- `KEY_POWER` 是运行中的输入事件；关机后唤醒由电源管理策略、待机供电、bootloader/固件唤醒码与硬件接线共同决定，桌面是否执行关机也由桌面策略决定。
- 开机自动加载取决于发行版既有 udev / ir-keytable 规则是否读取 `/etc/rc_maps.cfg`，各发行版集成方式不同；安装器不额外创建服务。
- 上游工具的部分写入错误不体现在进程退出码；`-r` 的输出是诊断文本，不是可直接交给 `-w` 的 TOML 备份。
- 回滚文件不会自动恢复内存中的键表；旧配置没有匹配本设备的行时，`-a` 可能保留当前表。安装前临时手工设置的内存映射无法由文件备份还原。
- 本项目非厂商官方项目，也不代表厂商背书；上游内核与 v4l-utils 保留各自的版权与许可，本项目的许可声明不替上游重新授权。

### 操作禁止项

- 不使用 `curl | sudo sh`：先完整阅读并信任 [install.sh](install.sh) 与 [zte_b860av21.toml](zte_b860av21.toml)，再授予 root 权限。
- 脚本与源文件放在自己控制、其他用户不会同时修改的目录，不在多人可写目录内提权运行；安装期间其他管理员、包管理器与配置工具暂缓修改 rc 配置。
- 备份只留在目标主机，不加入公开仓库，不上传日志、密码、地址或固件。
- 不假定 `rc0` / `rc1`，按 `uevent` 实际编号操作，占位符按安装器输出替换。
- 恢复时只使用本机、root 所有、已核对内容的备份；不把不可信备份当命令执行。
- 不盲目选最后一个备份；备份之后已有新改动时整文件恢复会覆盖这些改动，改为人工合并。
- 不把“文件已安装”当作“开机持久化已验证”，也不以退出码 0 或 `Wrote …` 文本作为写入成功的唯一依据。
- 验证电源键时保留未保存的数据；接收器没有事件时按接收器、协议、实际扫描码、遥控器型号的顺序排查，红外硬件时序保持原样。
- `--stage` 专用于隔离测试，不指向真实系统根目录或 bind mount。
- 若进程被强杀留下 `/etc/.b860av21-ir.lock`，先确认没有运行中的安装器并检查备份，再人工清理该锁目录。

## 六、上游参考

- [Linux 上游 meson-ir 驱动](https://github.com/torvalds/linux/blob/master/drivers/media/rc/meson-ir.c)
- [Linux rc-core 用户接口文档](https://docs.kernel.org/userspace-api/media/rc/intro.html)
- [v4l-utils 上游 ir-keytable 手册](https://github.com/gjasny/v4l-utils/blob/master/utils/keytable/ir-keytable.1.in)
- [v4l-utils keytable 实现与配置匹配逻辑](https://github.com/gjasny/v4l-utils/blob/master/utils/keytable/keytable.c)