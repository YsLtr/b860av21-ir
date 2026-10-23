#!/bin/sh
# SPDX-License-Identifier: GPL-2.0-or-later
set -eu
base=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd -P)
tmp=$(mktemp -d)
# Cleanup is restricted to the exact private directory just created.
trap 'rm -rf -- "$tmp"' EXIT
new_stage() {
    stage=$tmp/$1
    mkdir -p "$stage/etc" "$stage/sys/class/rc/rc7"
    printf 'DRV_NAME=meson-ir\nNAME=rc-empty\n' > "$stage/sys/class/rc/rc7/uevent"
}
run() { sh "$base/install.sh" --stage "$stage"; }
new_stage basic
printf '# retain\nother * other.toml\n' > "$stage/etc/rc_maps.cfg"
cp "$stage/etc/rc_maps.cfg" "$tmp/original"
run
cmp "$base/zte_b860av21.toml" "$stage/etc/rc_keymaps/zte_b860av21.toml"
cmp "$tmp/original" "$stage"/etc/b860av21-ir.backup.*/rc_maps.cfg
test -f "$stage"/etc/b860av21-ir.backup.*/zte_b860av21.toml.absent
run
set -- "$stage"/etc/b860av21-ir.backup.*
test "$#" = 1
test "$(grep -c '^meson-ir' "$stage/etc/rc_maps.cfg")" = 1
# Existing duplicate rows are normalized and an existing map is backed up.
printf 'meson-ir * zte_b860av21.toml\n' >> "$stage/etc/rc_maps.cfg"
printf 'old map\n' > "$stage/etc/rc_keymaps/zte_b860av21.toml"
run
test "$(grep -c '^meson-ir' "$stage/etc/rc_maps.cfg")" = 1
grep -l '^old map$' "$stage"/etc/b860av21-ir.backup.*/zte_b860av21.toml
for row in 'meson-ir * other.toml' '* * other.toml' '* rc-empty other.toml' 'MESON-IR * other.toml'; do
    printf '%s\n' "$row" > "$stage/etc/rc_maps.cfg"
    cp "$stage/etc/rc_maps.cfg" "$tmp/before"
    if run; then echo 'Conflict accepted!' >&2; exit 1; fi
    cmp "$tmp/before" "$stage/etc/rc_maps.cfg"
done
new_stage missing
printf 'DRV_NAME=other\nNAME=rc-empty\n' > "$stage/sys/class/rc/rc7/uevent"
if run; then exit 1; fi
test ! -e "$stage/etc/rc_maps.cfg"
new_stage multiple
mkdir "$stage/sys/class/rc/rc8"
cp "$stage/sys/class/rc/rc7/uevent" "$stage/sys/class/rc/rc8/uevent"
if run; then exit 1; fi
new_stage symlink
ln -s "$tmp/original" "$stage/etc/rc_maps.cfg"
if run; then exit 1; fi
new_stage writable
chmod 777 "$stage/etc"
if run; then exit 1; fi
new_stage locked
mkdir "$stage/etc/.b860av21-ir.lock"
if run; then exit 1; fi
if sh "$base/install.sh" --stage /; then exit 1; fi
printf 'PASS: staging, backup, idempotence, deduplication, conflicts, detection and trust guards\n'
