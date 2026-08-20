# macOS 15 Sequoia on ZimaOS (QEMU/KVM + OpenCore)

Runs macOS Sequoia as a headless VM on the ZimaCube box, with a working
iCloud/Apple Account sign-in.

The host is **AMD (Ryzen 7 5700U)**, which macOS has never supported natively,
so this is a QEMU/KVM + OpenCore build with the CPU presented as an Intel part.

## Current state

| | |
|---|---|
| Guest OS | macOS 15 Sequoia (15.7.9) |
| SMBIOS | `iMac19,1` (board `Mac-AA95B1DDAB278B95`) |
| Resources | 8 vCPU (4c × 2t), 10 GiB RAM, 128 GiB qcow2 |
| Networking | macvtap on `eth0` — guest holds a real DHCP lease on the LAN |
| Console | QEMU VNC on `<host>:5900` — **no auth, LAN-exposed by choice** |
| Autostart | `macos-vm.service` (systemd), enabled |
| iCloud | Signed in: Apple ID, iCloud, CloudKit, Find My, IDMS |

## Layout on the host

Everything lives in `/DATA/VM/macos/`:

```
run-macos.sh      launcher (this repo: config/run-macos.sh)
OpenCore.qcow2    OpenCore EFI (booted with snapshot=on, so it stays pristine)
OVMF_CODE_4M.fd   UEFI firmware (read-only)
OVMF_VARS.fd      NVRAM — PERSISTENT. iCloud/boot state lives here. Never reset it.
mac_hdd_ng.img    the macOS disk
smbios.txt        the generated machine identity
.install-done     marker; its presence detaches the installer media
```

## Operating it

```bash
systemctl status macos-vm.service
systemctl restart macos-vm.service
journalctl -u macos-vm.service -n 50
```

Shut the guest down **from inside macOS** (Apple menu → Shut Down) rather than
stopping the unit — a hard stop can lose the OpenCore default-boot flag from
NVRAM and drop you at the picker on next boot. If that happens, select `macOS`
and press <kbd>Ctrl</kbd>+<kbd>Enter</kbd> to re-pin it.

## Docs

- [`docs/01-host-and-constraints.md`](docs/01-host-and-constraints.md) — the box, and what it forces
- [`docs/02-build.md`](docs/02-build.md) — how it was built, reproducibly
- [`docs/03-icloud-vm-detection.md`](docs/03-icloud-vm-detection.md) — **the iCloud fix; read this first if iCloud breaks**
- [`docs/04-troubleshooting.md`](docs/04-troubleshooting.md) — dead ends and their signatures

## Credit

Built on [kholia/OSX-KVM](https://github.com/kholia/OSX-KVM),
[Acidanthera OpenCorePkg](https://github.com/acidanthera/OpenCorePkg) / Lilu,
and [Carnations-Botanica/VMHide](https://github.com/Carnations-Botanica/VMHide).
