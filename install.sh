#!/bin/sh
# SPDX-License-Identifier: GPL-2.0-or-later
set -eu
PATH=/usr/sbin:/usr/bin:/sbin:/bin
export PATH
umask 077
fail() { printf '%s\n' "Error: $*" >&2; exit 1; }
base=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd -P)
root=
case "$#:$*" in
    1:--install) [ "$(id -u)" = 0 ] || fail 'Installation requires root.' ;;
    2:--stage\ *)
        root=$2
        case "$root" in /*) ;; *) fail 'Stage must be an absolute directory.' ;; esac
        [ -d "$root" ] && [ ! -L "$root" ] || fail 'Invalid stage directory.'
        root=$(CDPATH= cd -- "$root" && pwd -P)
        [ "$root" != / ] || fail 'Refusing / as stage.'
        [ "$(stat -c %u "$root")" = "$(id -u)" ] || fail 'Stage must be owned by you.'
        ;;
    *) fail 'Review and trust this checkout first. Usage: sh install.sh --install | --stage DIRECTORY' ;;
esac
src=$base/zte_b860av21.toml
[ -f "$src" ] && [ ! -L "$src" ] || fail 'Keymap must be a regular non-symlink file.'
# Never source/evaluate configuration or sysfs contents as shell code.
rc=
table=
for dev in "$root"/sys/class/rc/rc*; do
    [ -f "$dev/uevent" ] || continue
    grep -qx 'DRV_NAME=meson-ir' "$dev/uevent" || continue
    [ -z "$rc" ] || fail 'Multiple meson-ir devices: inspect manually; no changes made.'
    rc=${dev##*/}
    table=$(sed -n 's/^NAME=//p' "$dev/uevent")
done
[ -n "$rc" ] && [ -n "$table" ] || fail 'Exactly one meson-ir device with NAME is required.'
case "$rc" in rc*[!0-9]*|rc) fail 'Invalid rc device name.' ;; esac
etc=$root/etc
maps=$etc/rc_keymaps
cfg=$etc/rc_maps.cfg
map=$maps/zte_b860av21.toml
# Refuse symlinks and writable/untrusted destination ancestors (GNU stat).
trusted() {
    p=$1
    while :; do
        [ ! -L "$p" ] || fail "Symlink destination: $p"
        if [ -e "$p" ]; then
            [ "$(stat -c %u "$p")" = "$(id -u)" ] || fail "Untrusted owner: $p"
            mode=$(stat -c %a "$p")
            [ "$((0$mode & 022))" = 0 ] || fail "Group/other writable destination: $p"
        fi
        [ "$p" = "${root:-/}" ] && break
        p=$(dirname -- "$p")
    done
}
[ -d "$etc" ] || fail 'etc directory must already exist.'
trusted "$cfg"
trusted "$map"
[ ! -e "$cfg" ] || [ -f "$cfg" ] || fail 'rc_maps.cfg is not a regular file.'
[ ! -e "$map" ] || [ -f "$map" ] || fail 'Destination keymap is not a regular file.'
lock=$etc/.b860av21-ir.lock
mkdir -- "$lock" || fail 'Installer lock exists; do not run concurrently.'
backup=
cleanup() {
    status=${1:-$?}
    trap - EXIT
    rmdir -- "$lock" || :
    if [ "$status" != 0 ] && [ -n "$backup" ]; then
        printf 'Installation incomplete. Restore backup using README: %s\n' "$backup" >&2
    fi
    exit "$status"
}
trap cleanup EXIT
trap 'exit 1' HUP INT TERM
# Keep all unrelated rows. Refuse competing driver/table matches, including
# wildcard-driver rows matching the detected default table, in any order.
input=$cfg
[ -e "$cfg" ] || input=/dev/null
new=$lock/rc_maps.cfg
trap 'status=$?; rm -f -- "$new"; cleanup "$status"' EXIT
awk -v table="$table" '
    /^[[:space:]]*#/ || NF == 0 { print; next }
    tolower($1) == "meson-ir" {
        if ($2 == "*" && $3 == "zte_b860av21.toml" && (NF == 3 || $4 ~ /^#/)) next
        conflict = 1; next
    }
    $1 == "*" && ($2 == "*" || tolower($2) == tolower(table)) { conflict = 1 }
    { print }
    END {
        if (conflict) exit 2
        print "meson-ir\t*\tzte_b860av21.toml"
    }
' "$input" > "$new" || fail 'Conflicting rc_maps.cfg rows; reconcile manually, then retry.'
if [ -f "$cfg" ] && [ -f "$map" ] && cmp -s "$new" "$cfg" && cmp -s "$src" "$map"; then
    printf 'Already installed; device: %s. No files changed.\n' "$rc"
    exit 0
fi
backup=$(mktemp -d "$etc/b860av21-ir.backup.XXXXXXXX")
for name in rc_maps.cfg zte_b860av21.toml; do
    old=$cfg
    [ "$name" != zte_b860av21.toml ] || old=$map
    if [ -f "$old" ]; then
        cp -p -- "$old" "$backup/$name"
    else
        : > "$backup/$name.absent"
    fi
done
printf 'Backup (keep private): %s\n' "$backup"
mkdir -p -- "$maps"
chmod 644 "$new"
# Files are replaced separately, not as one transaction; backups survive errors.
install -m 644 -- "$src" "$backup/new-keymap"
mv -- "$backup/new-keymap" "$map"
mv -- "$new" "$cfg"
printf 'Installed files only; device: %s. No live keytable was changed.\n' "$rc"
printf 'Next: sudo ir-keytable -s %s -a /etc/rc_maps.cfg\n' "$rc"
