# Building it from scratch

Assumes the box state in [`01-host-and-constraints.md`](01-host-and-constraints.md).
All paths on the host; everything under `/DATA` because `/` is read-only.

## 1. Assets

```bash
git clone --depth 1 https://github.com/kholia/OSX-KVM.git /DATA/VM/osx-kvm
mkdir -p /DATA/VM/macos && cd /DATA/VM/macos

# Sequoia recovery. fetch-macOS-v2.py is stdlib-only, so no pip needed.
python3 /DATA/VM/osx-kvm/fetch-macOS-v2.py -s sequoia

# dmg2img is absent; qemu-img reads DMG natively.
qemu-img convert -p -f dmg -O raw BaseSystem.dmg BaseSystem.img
qemu-img create -f qcow2 mac_hdd_ng.img 128G

cp /DATA/VM/osx-kvm/OpenCore/OpenCore.qcow2 .
cp /DATA/VM/osx-kvm/OVMF_CODE_4M.fd .
cp /DATA/VM/osx-kvm/OVMF_VARS-1920x1080.fd OVMF_VARS.fd
```

`ignore_msrs` is required:

```bash
echo 1 > /sys/module/kvm/parameters/ignore_msrs
echo "options kvm ignore_msrs=1" > /etc/modprobe.d/kvm-osx.conf
```

## 2. Machine identity

Generate with Acidanthera's `macserial` (ships in the OpenCorePkg release):

```bash
macserial.linux -m iMac19,1 -g -n 1     # -> SERIAL | MLB
macserial.linux -i <SERIAL>             # verify it decodes as iMac19,1
macserial.linux --verify <MLB>          # verify checksum
```

**Keep the model `iMac19,1`.** It is what OSX-KVM ships and is known-good here.
Switching to `iMacPro1,1` produced a late-boot kernel panic. iCloud needs a
*valid, unique* SMBIOS — not a specific model.

Pick a MAC under an Apple OUI; `ROM` must equal that MAC with colons stripped.

## 3. Patch OpenCore

Mount the EFI (`scripts/ocmount.sh mount`) and edit `EFI/OC/config.plist`:

- `PlatformInfo > Generic`: `SystemProductName`, `SystemSerialNumber`, `MLB`,
  `SystemUUID`, `ROM`
- `DeviceProperties > Add > PciRoot(0x0)/Pci(0x3,0x0)` → `built-in = <01>`
  (must match the NIC's PCI address so macOS sees en0 as internal)
- `NVRAM > Add > 4D1FDA02-38C7-4A6A-9CC6-4BCCA8B30102` → `ROM` (data), `MLB` (string),
  and list both under `NVRAM > Delete` so OpenCore rewrites them every boot.

> `PlatformInfo > UpdateNVRAM` was already `true` yet OpenCore still did not
> inject ROM/MLB into NVRAM. Writing them explicitly under `NVRAM > Add` is what
> actually worked. Verify in the guest with
> `nvram 4D1FDA02-38C7-4A6A-9CC6-4BCCA8B30102:ROM`.

Also required for iCloud on Sequoia — see
[`03-icloud-vm-detection.md`](03-icloud-vm-detection.md):

- Update `Lilu.kext` to ≥ 1.7.2
- Add `VMHide.kext` to `EFI/OC/Kexts` and to `Kernel > Add` (after Lilu)

## 4. Install

Deploy `config/run-macos.sh` and `config/macos-vm.service`, then:

```bash
systemctl enable --now macos-vm.service
```

At the OpenCore picker choose **macOS Base System**, then in Recovery:

```bash
diskutil list physical                    # find the 137.4 GB disk
diskutil eraseDisk APFS macOS GPT disk0
```

Then "Reinstall macOS Sequoia" (downloads ~15 GB). It reboots mid-way; pick the
**macOS Installer** entry to resume. Afterwards:

```bash
touch /DATA/VM/macos/.install-done        # detaches the installer media
```

Pin the default boot entry: at the picker, select `macOS` and press
<kbd>Ctrl</kbd>+<kbd>Enter</kbd>.

## 5. Guest setup

Enable remote access from inside macOS (`systemsetup -setremotelogin` fails
without Full Disk Access; use launchctl):

```bash
sudo launchctl enable system/com.apple.ssh
sudo launchctl load -w /System/Library/LaunchDaemons/ssh.plist
sudo launchctl enable system/com.apple.screensharing
sudo launchctl load -w /System/Library/LaunchDaemons/com.apple.screensharing.plist
```

To let an SSH session read TCC-protected paths (`~/Library/Accounts`, etc.),
add `/usr/libexec/sshd-keygen-wrapper` to System Settings → Privacy & Security →
Full Disk Access.

## Verifying the iCloud prerequisites

Run these in the guest *before* attempting sign-in:

```bash
ifconfig -l | tr ' ' '\n' | grep en0        # en0 must exist
networksetup -listallhardwareports          # en0 must be "Ethernet"
nvram 4D1FDA02-38C7-4A6A-9CC6-4BCCA8B30102:ROM   # must return a value
nvram 4D1FDA02-38C7-4A6A-9CC6-4BCCA8B30102:MLB
sysctl kern.hv_vmm_present                  # MUST be 0
```
