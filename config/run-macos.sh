#!/bin/sh
# macOS 15 Sequoia VM on ZimaOS - proven configuration.
# Derived from kholia/OSX-KVM OpenCore-Boot.sh, verified booting on this AMD host.
#   SMBIOS: iMac19,1 with unique serial/MLB/UUID/ROM  (see smbios.txt)
#   NIC:    virtio-net-pci on pcie.0 slot 0x3 (Sequoia has AppleVirtIO; no Intel 8254x driver) -> macOS sees built-in en0 (iCloud requirement)
#   NVRAM:  OVMF_VARS.fd is PERSISTENT - never reset it, iCloud/NVRAM state lives there.
M=/DATA/VM/macos
GUEST_MAC=00:16:cb:bc:33:e8
UPLINK=eth0

# Real kernel networking on the LAN via macvtap (replaces QEMU user-mode/SLIRP).
ip link del macvtap0 2>/dev/null || true
ip link add link "$UPLINK" name macvtap0 type macvtap mode bridge
ip link set macvtap0 address "$GUEST_MAC" up
IFIDX=$(cat /sys/class/net/macvtap0/ifindex)
exec 3<>/dev/tap$IFIDX


INSTALL_MEDIA=""
if [ -f "$M/BaseSystem.img" ] && [ ! -f "$M/.install-done" ]; then
  INSTALL_MEDIA="-device ide-hd,bus=sata.3,drive=InstallMedia -drive id=InstallMedia,if=none,file=$M/BaseSystem.img,format=raw"
fi

# shellcheck disable=SC2086
exec qemu-system-x86_64 \
  -enable-kvm -m 10240 \
  -cpu Skylake-Client,-hle,-rtm,kvm=on,vendor=GenuineIntel,+invtsc,vmware-cpuid-freq=on,+ssse3,+sse4.2,+popcnt,+avx,+aes,+xsave,+xsaveopt,check \
  -machine q35 \
  -smp 8,cores=4,sockets=1,threads=2 \
  -device qemu-xhci,id=xhci \
  -device usb-kbd,bus=xhci.0 -device usb-tablet,bus=xhci.0 \
  -device isa-applesmc,osk="ourhardworkbythesewordsguardedpleasedontsteal(c)AppleComputerInc" \
  -drive if=pflash,format=raw,readonly=on,file="$M/OVMF_CODE_4M.fd" \
  -drive if=pflash,format=raw,file="$M/OVMF_VARS.fd" \
  -smbios type=2 \
  -device ich9-ahci,id=sata \
  -drive id=OpenCoreBoot,if=none,snapshot=on,format=qcow2,file="$M/OpenCore.qcow2" \
  -device ide-hd,bus=sata.2,drive=OpenCoreBoot \
  $INSTALL_MEDIA \
  -drive id=MacHDD,if=none,file="$M/mac_hdd_ng.img",format=qcow2 \
  -device ide-hd,bus=sata.4,drive=MacHDD \
  -netdev tap,id=net0,fd=3 \
  -device virtio-net-pci,netdev=net0,id=net0,mac=00:16:cb:bc:33:e8,bus=pcie.0,addr=0x3 \
  -device vmware-svga \
  -display none -vnc 0.0.0.0:0 \
  -monitor none -qmp unix:/run/macos-qmp.sock,server,nowait
