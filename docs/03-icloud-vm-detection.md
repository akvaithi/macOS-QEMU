# iCloud on Sequoia: the VM-detection wall

**If iCloud sign-in breaks, read this before touching the SMBIOS.**

## Symptom

System Settings → Sign in with Apple Account fails with **"Verification Failed"**
or **"An unknown error occurred."**

The decisive diagnostic: **sign in at `appleid.apple.com` in Safari inside the
same VM.** If web sign-in *works* but System Settings fails, the account and the
network are fine and the failure is **device attestation**. Cycling the serial
will not help.

## Root cause

macOS 15 Sequoia checks `kern.hv_vmm_present`. If it sees a hypervisor, Apple's
DeviceCheck refuses to provision the device. From the guest log:

```
DCBAASigner.m:109  Cannot sign data, platform is not supported by DeviceIdentity.
  -> Error Domain=com.apple.devicecheck.error.baa Code=-10000
  -> Failed to fetch attestation headers: AKAuthenticationError Code=-7066
  -> Provisioning failed. No Anisette for you today! AKAnisetteError Code=-8008
  -> SRP authentication with server failed: AKAnisetteError Code=-8001
  -> Attempting to show login error: AKAuthenticationError Code=-7018
```

Note what precedes it: `ADIProvisioningStart succeeded!` with **HTTP 200**.
Apple *accepted* the SMBIOS identity and started provisioning, then rejected the
machine for being virtual. That is why serial/MLB/ROM changes are irrelevant here.

## The fix

**VMHide.kext + Lilu ≥ 1.7.0.** VMHide is a Lilu plugin that intercepts the
`hv_vmm_present` sysctl per-process.

```bash
# 1. Lilu: OSX-KVM ships 1.6.8; VMHide requires >= 1.7.0
curl -L -o Lilu.zip https://github.com/acidanthera/Lilu/releases/download/1.7.2/Lilu-1.7.2-RELEASE.zip

# 2. VMHide
curl -L -o VMHide.zip https://github.com/Carnations-Botanica/VMHide/releases/download/2.0.0/VMHide-2.0.0-RELEASE.zip
```

Replace `EFI/OC/Kexts/Lilu.kext`, add `VMHide.kext`, and append to
`Kernel > Add` **after** Lilu:

```
BundlePath     VMHide.kext
ExecutablePath Contents/MacOS/VMHide
PlistPath      Contents/Info.plist
Enabled        true
```

Verify after reboot:

```bash
sysctl kern.hv_vmm_present          # must be 0
sudo kmutil showloaded | grep -i vmhide
```

> If VMHide silently does nothing, check the kernel log — with an old Lilu it
> fails with `library kext as.vit9696.Lilu not compatible with requested version
> 1.7.0` and `kern.hv_vmm_present` stays `1`.

## What NOT to do

**Do not hide the hypervisor CPUID bit.** Adding `-hypervisor` (and/or
`kvm=off`) to the QEMU `-cpu` string *does* set `hv_vmm_present` to 0 — and
**hangs the boot**. macOS relies on that bit for TSC calibration; without it the
Apple logo progress bar stalls indefinitely at ~100% CPU. Tried and reverted.

The CPUID `VMM` flag remaining visible is fine. DeviceCheck reads the sysctl,
which is what VMHide intercepts.

## After any SMBIOS change

Stale state bound to the old identity must be cleared, or sign-in keeps failing:

```bash
sudo rm -f /Library/Preferences/com.apple.apsd.plist    # push token — the important one
rm -rf ~/Library/Caches/com.apple.appleaccountd* ~/Library/Caches/com.apple.iCloudHelper*
rm -f  ~/Library/Preferences/MobileMeAccounts.plist ~/Library/Preferences/com.apple.appleaccountd.plist
sudo reboot
```

Confirm `com.apple.apsd.plist` is regenerated *after* the reboot — that means
apsd re-registered under the new identity.

## Capturing the real error

macOS redacts sensitive log fields as `<private>`, and `log config --mode
'private_data:on'` is rejected on Sequoia (it needs a configuration profile).
Even so, the AuthKit error chain above is visible. Capture it live:

```bash
sudo log stream --style compact --level debug \
  --predicate 'process == "akd" OR process == "appleaccountd" OR subsystem == "com.apple.AuthKit"' \
  > /tmp/auth.txt
```

Then attempt the sign-in and grep for `devicecheck|attest|anisette|AKAuth`.
A successful attempt contains **zero** `AKAnisetteError` / `baa` hits.

## Verified working state

```
Apple ID | iCloud | CloudKit | Device Locator (Find My) | IDMS | Messages | Game Center
```
