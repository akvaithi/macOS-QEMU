# The host, and what it forces

Verified on the box directly rather than assumed.

## Hardware / OS

| | |
|---|---|
| Box | ZimaCube, ZimaOS v1.7.0, kernel 6.18.9 |
| CPU | **AMD Ryzen 7 5700U** (Zen 2) — 8 cores / 16 threads |
| RAM | 14 GiB total, 5 GiB swapfile |
| GPU | AMD Lucienne iGPU (`1002:164c`) — the only GPU |
| Storage | `/DATA` on NVMe, ~220 GiB free |
| Virt | `svm` + `/dev/kvm` present, nested KVM on |

## What each fact forces

**AMD CPU.** macOS has no AMD support, so the guest CPU must be presented as
Intel (`vendor=GenuineIntel`). AVX2 is present, which macOS ≥ 13 requires.

**No usable GPU.** The Lucienne iGPU has no macOS driver and it is the host's
only GPU, so passthrough is off the table. The VM is headless with an
unaccelerated framebuffer — fine for iCloud and light desktop use, poor for
anything animated.

**8 physical cores.** Giving the guest 16 vCPUs boots, but the *installer*
livelocked (all vCPUs pegged, zero disk I/O) because the guest starves QEMU's
own I/O threads. **8 vCPU is the working number.** 10 GiB RAM is fine.

**Read-only root.** `/` is a squashfs system image; `/etc` is an overlay on a
separate 85 MiB partition. No `pip`, no `dmg2img`, no compiler, no kernel
headers. Nothing can be installed — but QEMU 10.2, libvirt, `qemu-nbd`,
`mkfs.vfat` and `nbd` are already present, and `qemu-img` reads DMG natively,
so nothing needed installing.

Because there is no compiler or kernel headers and `/usr` is read-only,
**VMware Workstation is not installable here** — it must build `vmmon`/`vmnet`
against the running kernel.

## A misleading signal to ignore

`virsh domcapabilities` reports `Skylake-Client` as `usable='no'` on this host,
because the Ryzen lacks `pcid`, `erms` and `invpcid`. **It boots fine anyway** —
QEMU warns and drops those bits. Do not let that report push you to a different
CPU model.

Also: QEMU prints the missing-feature warning **once per vCPU**, so the warning
count equals the vCPU count. It is not a reboot loop.

## Why systemd, not libvirt

libvirt is present and works, but it rewrites device topology — it relocated the
NIC behind an auto-created `pcie-root-port`, which makes macOS treat it as
removable rather than built-in, and produced a guest that landed in Setup
Assistant's "connect a mouse" screen instead of Recovery. Rather than override
libvirt device-by-device, the VM runs the proven raw QEMU command line under a
systemd unit.
