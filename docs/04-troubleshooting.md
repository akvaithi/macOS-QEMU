# Troubleshooting: symptoms, causes, dead ends

A catalogue of everything that went wrong during the build, so it does not have
to be rediscovered.

## Networking

**No network interface at all in macOS (`ifconfig -l` shows only `lo0 gif0 stf0 XHC1`).**
The NIC model has no driver. **Sequoia ships `AppleVirtIO.kext` but no Intel
8254x and no vmxnet3 driver.** Use `virtio-net-pci`.

> Widely-cited advice to switch to `e1000-82545em` to fix "error connecting to
> the Apple ID Server" is from ~2020 and is **wrong for Sequoia** — it yields
> zero interfaces. Verify with `ifconfig -l` before trusting any NIC advice.
> Check what drivers exist:
> `ls /System/Library/Extensions | grep -iE 'ethernet|vmxnet|8254|virtio'`

**Guest must appear as built-in `en0`.** Pin the NIC to `bus=pcie.0,addr=0x3`
and set the matching `built-in` DeviceProperty. Under libvirt this is *not*
enough — libvirt relocates it behind a `pcie-root-port`.

**SLIRP vs macvtap.** The build now uses macvtap on `eth0`, so the guest holds a
real DHCP lease on the LAN. This was done while chasing the iCloud failure; it
was **not** the cause (QEMU user-mode networking reached Apple fine), but it is
closer to real hardware and gives the guest a directly reachable address.
Trade-off: **macvtap isolates host↔guest by design**, so the host cannot SSH to
the guest; reach it over the LAN instead. Previous SLIRP config is preserved as
`run-macos.sh.slirp.bak` on the box.

## Boot

**Late-boot kernel panic** (all daemons start, then panic). Caused by SMBIOS
`iMacPro1,1`. Use `iMac19,1`.

**Installer livelock** — all vCPUs pegged, zero disk I/O, frozen progress bar.
Caused by 16 vCPUs on an 8-core host. Use 8. Confirm with:

```bash
P=$(pgrep -f '[q]emu-system-x86_64'|head -1)
A=$(awk '{print $14+$15}' /proc/$P/stat); sleep 15
B=$(awk '{print $14+$15}' /proc/$P/stat); echo $((B-A))   # ~12000 = all pegged
awk '/^write_bytes:/{print $2}' /proc/$P/io               # unchanging = no progress
```

**Boot hangs at the Apple logo after CPU changes.** Removing `-hypervisor` or
setting `kvm=off` breaks TSC calibration. Keep
`kvm=on,vendor=GenuineIntel,+invtsc,vmware-cpuid-freq=on`.

**Drops to the OpenCore picker instead of booting.** A hard `systemctl stop`
killed QEMU before the default-boot flag flushed to NVRAM. Select `macOS`,
<kbd>Ctrl</kbd>+<kbd>Enter</kbd>. Prevent by shutting down from inside macOS.

**`virsh undefine --nvram` deletes `OVMF_VARS.fd`** — that file *is* the guest's
NVRAM. Losing it loses iCloud/boot state.

## iCloud

See [`03-icloud-vm-detection.md`](03-icloud-vm-detection.md). Ruled out along the
way, each with evidence — do not re-chase these:

| Suspected | Verdict |
|---|---|
| Serial/MLB invalid or duplicate | No. Cycled once; `ADIProvisioningStart` returns HTTP 200. |
| Accounts DB has stale iCloud record | No. Rows are stock `Holiday Calendar` + local `iTunes Store`. |
| Keychain residue | No. Only `com.apple.kerberos.kdc`, `com.apple.systemdefault`. |
| Serial port ranked above Ethernet | No. `scutil` showed `PrimaryInterface : en0` already. |
| Clock skew | No. Guest matched host to the second. |
| Network/APNs blocked | No. Apple endpoints 200, APNs 5223 open, IPv6 fine. |
| Stale `apsd` token | Real, and worth clearing — but not sufficient alone. |

## Host-side gotchas

**`pkill -f <pattern>` matches the invoking shell's own command line** on this
box and will kill your SSH session mid-script. Kill by pidfile instead.

**`setsid` does not exist on macOS** — use `nohup … & disown` to detach a
background `log stream` in the guest.

**TCC blocks SSH from user data** (`~/Library/Accounts`) even with `sudo`, until
`/usr/libexec/sshd-keygen-wrapper` has Full Disk Access.

## Driving the guest headlessly

QMP over `/run/macos-qmp.sock` (see `scripts/`):

```bash
python3 qmp.py shot /tmp/s.ppm          # screenshot
python3 combo.py right ret              # keys, e.g. the OpenCore picker
python3 combo.py shift+meta_l+t         # ⇧⌘T — opens Terminal in Recovery
```

Mouse clicks via `input-send-event` need **move first, then click** — the first
click only positions the pointer. Arrow keys do not drive the Recovery chooser
list; click it instead.
