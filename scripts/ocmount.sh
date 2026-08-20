#!/bin/sh
# ocmount.sh mount|umount
set -e
case "$1" in
 mount)
  modprobe nbd max_part=8 2>/dev/null || true
  qemu-nbd --disconnect /dev/nbd0 >/dev/null 2>&1 || true
  sleep 1
  qemu-nbd --connect=/dev/nbd0 /DATA/VM/macos/OpenCore.qcow2
  sleep 2
  mkdir -p /DATA/VM/ocmount
  mount /dev/nbd0p1 /DATA/VM/ocmount
  echo "mounted" ;;
 umount)
  sync
  umount /DATA/VM/ocmount 2>/dev/null || true
  qemu-nbd --disconnect /dev/nbd0 >/dev/null 2>&1 || true
  echo "unmounted" ;;
esac
