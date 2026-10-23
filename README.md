# B860AV2.1 红外遥控 keymap（主线 Linux / meson-ir）

本项目复用 Linux 已有的 **meson-ir + rc-core + NEC 解码器**，提供 ZTE B860AV2.1 配套 **NEC 地址 `0x22` / DD22** 遥控器的 31 个扫描码映射，以及保守的安装方法。**不是新内核驱动，不刷机，不修改设备树、时钟或红外硬件时序，也不提供 ROM。**

仅面向这份遥控器配置对应的硬件组合。B860 系列不同后缀、板卡、固件及遥控器可能不同，不能据此宣称兼容所有 B860 型号。

参考环境：B860AV2.1、Armbian noble、aarch64、`6.12.37-ophub`；参考机已验证重启后加载 31 个映射。安装器通过 Linux 临时目录隔离测试，发布过程未重写真实键表。配套 WiFi 源码与板级供电适配见 [b860av21-wifi](https://github.com/YsLtr/b860av21-wifi)。

## 来源、范围与验证边界

- [keymap](<zte_b860av21.toml>) 根据观察到的 Android 遥控配置 `system/etc/remote_dd22.conf` 中的事实性扫描码整理；观察到的 `factory_code` 为 `0xDD220001`。没有重新分发整份厂商配置、厂商驱动、ROM 或其他专有二进制。
- 标准 NEC 中 `0x22` 与 `0xDD` 为互补地址字节。本表采用主线扫描码形式 `(0x22 << 8) | command`，而不是直接把 `0xDD220001` 当作主线扫描码。例如电源为 `0x22dc`，上为 `0x22ca`，OK 为 `0x22ce`。
- 表中使用 Linux `KEY_*`，不是 Android keycode 数值。HOME 使用 `KEY_HOMEPAGE`；设置使用 `KEY_SETUP`；OK 使用 `KEY_ENTER`。应用如何响应这些事件取决于应用自身。
- **读回 keymap / 显示写入 31 个键，不等于这 31 个按键均已逐一实按测试。** 本仓库的安装器测试也不等于硬件测试。应按下方步骤记录您自己的逐键结果。
- **`KEY_POWER` 只是运行中 Linux 输入事件，不保证关机后唤醒，甚至不保证桌面执行关机。** 电源管理策略、待机供电、bootloader/固件的唤醒码和硬件接线共同决定休眠/关机唤醒。不要为了验证电源键丢失未保存的数据。

## 前提与安全约定

1. 已运行适配本机的主线/主线系 Linux，设备树已启用接收器，能看到 `meson-ir` rc 设备。没有设备时先排查内核、设备树与接线；本项目不自动更改它们。
2. 安装发行版的 `ir-keytable`（通常来自 v4l-utils；Debian/Ubuntu 可安装 `ir-keytable`），要求支持 TOML keymap。安装脚本需要 `/bin/sh`、awk、grep、sed 和 GNU coreutils（含 `stat`、`install`、`mktemp`）。
3. **先完整阅读并信任 [安装脚本](<install.sh>) 和 [keymap](<zte_b860av21.toml>)，再授予 root 权限。** 不使用 `curl | sudo sh`。脚本和源文件需置于自己控制、不会被其他用户同时修改的目录；不要在多人可写目录内提权运行。脚本不下载或执行 keymap 内容。
4. 保留 SSH/串口或键盘作为回退通道。安装期间不要让其他管理员、包管理器或配置工具同时修改 rc 配置。
5. 备份可能含您原有的私有配置。**备份只留在目标主机，不加入公开仓库，不上传日志、密码、地址或固件。**

## 1. 只读确认设备

```sh
ir-keytable
for dev in /sys/class/rc/rc*; do
    [ -f "$dev/uevent" ] || continue
    printf '\n%s\n' "$dev"
    cat "$dev/uevent"
done
```

寻找 `DRV_NAME=meson-ir`。CEC 设备不是目标。编号由枚举顺序决定，不要假定 `rc0` 或 `rc1`；重启后也可能改变。

## 2. 安装持久化文件（不立即加载）

先获取源码（IR 映射无需编译内核），阅读并信任安装脚本后再执行：

```sh
git clone https://github.com/YsLtr/b860av21-ir.git
cd b860av21-ir
sudo sh ./install.sh --install
```

脚本将：

- 要求 root，固定工具搜索路径，从 sysfs 自动识别唯一一个 `meson-ir`；没有设备或多个设备时拒绝猜测。
- 拒绝目标路径中的符号链接、非普通目标文件、非当前用户所有或组/其他用户可写的目标路径。
- 检查 `/etc/rc_maps.cfg`。保留不相关行，去重本项目的 `meson-ir * zte_b860av21.toml`；遇到其他 `meson-ir` 行，或会匹配本设备默认表名的通配驱动行（包括 `* *`），**直接退出，不静默覆盖**。先人工检查冲突再决定如何处理。
- 在修改前建立私有 `/etc/b860av21-ir.backup.XXXXXXXX/`，保存原配置与原同名 keymap；原文件不存在则写入对应 `.absent` 标记。
- 安装 `/etc/rc_keymaps/zte_b860av21.toml`，更新 `/etc/rc_maps.cfg`。内容完全一致时不再备份或修改。重复运行不会追加重复行。
- **只安装文件，不执行 `ir-keytable`、不改当前协议/键表、不重启、不安装服务。** 两个文件分别替换，不是跨文件事务；失败时保留备份并提示人工恢复。若进程被强杀留下 `/etc/.b860av21-ir.lock`，确认没有运行中的安装器并检查备份后，再人工清理该锁目录。

本项目不附带整个发行版默认 rc_maps 配置，避免覆盖其他设备规则。新增的规则仅为：

```text
meson-ir * zte_b860av21.toml
```

## 3. 明确加载并验证

这一步才会改变运行中键表。用安装器打印的实际设备名替换下面的 `rcN`；不要原样复制占位符。

```sh
RC=rcN
sudo ir-keytable -s "$RC" -r
sudo ir-keytable -s "$RC" -a /etc/rc_maps.cfg
sudo ir-keytable -s "$RC" -r
sudo ir-keytable -s "$RC" -t
```

加载前先记录旧键表和启用协议（仅留本机）。`-r` 的输出是诊断文本，**不是可直接交给 `-w` 的 TOML 备份**。`-a` 根据配置加载并清除旧表；加载后检查输出有无错误、NEC 是否启用，以及读回扫描码与本表是否一致。上游工具某些写入错误不一定体现在进程退出码，不能只看退出码或“Wrote …”。

在 `-t` 中先测试方向、OK、返回等无破坏性按键，再逐个测试数字、音量、彩色键等；同时确认应用层行为。注意按下、释放与长按重复，最后谨慎测试电源。按 Ctrl-C 退出。若没有事件，依次检查接收器、协议、实际扫描码和遥控器型号，不先修改硬件时序。

### 开机自动加载

能否开机自动加载依赖发行版现有的 udev / ir-keytable 规则是否读取 `/etc/rc_maps.cfg`。本安装器不保证所有发行版都有这项集成，也不额外创建服务。检查发行版规则，计划内重启后重新识别设备并用 `-r` 验证。若未自动加载，先使用上述明确的 `-a` 命令；不要误把“文件已安装”当作“开机持久化已验证”。

## 4. 回滚

选择**需要恢复到的那一次安装前**备份，不要盲目选最后一个：重复安装后的新备份可能已经是本项目版本。恢复整个旧配置会覆盖备份之后您或软件包做的修改；如已有后续改动，请人工合并，不执行整文件恢复。保留回退连接。

以 root shell 执行下面片段，首先将 `B` 改成实际输出的备份目录。只使用本机可信、root 所有的备份，先检查内容；不要把不可信备份当命令执行。

```sh
sudo -s
B=/etc/b860av21-ir.backup.XXXXXXXX
# 必须先检查 B 是预期备份、无符号链接，目标路径也未被他人替换。
ls -ld "$B" /etc/rc_maps.cfg /etc/rc_keymaps
ls -la "$B"
# 核对完成后执行；若有后续配置变化，请停止并人工合并。
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

回滚文件不会自动恢复当前内存中的键表和协议。如果旧配置确实能匹配这个设备，可重新识别设备后执行 `sudo ir-keytable -s rcN -a /etc/rc_maps.cfg`；若旧配置没有匹配行，`-a` 可能保留当前表，**不能当作恢复成功**。此时请使用已知可信的旧 keymap 显式加载，或在确认原持久化配置已恢复后安排重启，让驱动/原加载机制重新初始化，再验证 `-r`。安装前临时手工设置的内存映射无法靠文件备份还原。

## 无硬件回归测试

```sh
sh -n install.sh
sh -n tests/test.sh
sh tests/test.sh
```

[测试脚本](<tests/test.sh>) 在 `mktemp` 创建的私有目录模拟 sysfs 与 `/etc`，调用 `--stage`，不写真实 `/etc`、`/sys` 或输入设备。覆盖首次安装、原文件备份、缺失标记、幂等、重复规则、冲突、缺失/多个设备、符号链接、不可信权限与锁。无需 root。`--stage` 仅用于这种隔离测试，不是硬件验证，也不要把它指向真实系统根目录或 bind mount。

## 许可与上游

本项目原创脚本、配置整理与文档按 **GPL-2.0-or-later** 提供，详见 [许可声明](<NOTICE>) 与 [GPL v2 全文](<LICENSE>)。事实性扫描码的整理不主张获得厂商 ROM 或完整配置的再分发权。上游 Linux 内核和 v4l-utils 没有被打包进本仓库，分别保留自己的版权与许可；本项目的许可声明不替上游重新授权。本项目非厂商官方项目，也不代表厂商背书。

- [Linux 上游 meson-ir 驱动](https://github.com/torvalds/linux/blob/master/drivers/media/rc/meson-ir.c)
- [Linux rc-core 用户接口文档](https://docs.kernel.org/userspace-api/media/rc/intro.html)
- [v4l-utils 上游 ir-keytable 手册](https://github.com/gjasny/v4l-utils/blob/master/utils/keytable/ir-keytable.1.in)
- [v4l-utils keytable 实现与配置匹配逻辑](https://github.com/gjasny/v4l-utils/blob/master/utils/keytable/keytable.c)
