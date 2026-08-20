# Security notes

**Keep this repository private.**

## What is in here

- The machine identity in `config/smbios.txt`: serial, MLB, SystemUUID, ROM/MAC.
  These are not passwords, but they are the device fingerprint now bound to a
  real Apple Account. Anyone with them could impersonate this machine to Apple.
  They are committed because without them the VM is not recoverable — regenerating
  them means re-doing the iCloud association from scratch.

## What is deliberately NOT in here

- **No passwords.** Not the box login, not the macOS account, not any token.
  Secrets live in the macOS Keychain and are read at the moment of use:

  ```bash
  security find-generic-password -s spotiflac-deploy -w   # ZimaOS box login
  security find-generic-password -s macos-vm-login -w     # macOS guest account
  ```

## Known exposure to fix

- The QEMU VNC console is bound to `0.0.0.0:5900` with **no authentication**,
  by explicit choice, so it is reachable by anything on the LAN. Anyone who can
  reach that port has full console control of a machine signed into iCloud.
  To close it, change `-vnc 0.0.0.0:0` back to `-vnc 127.0.0.1:0` in
  `config/run-macos.sh` and reach it over an SSH tunnel instead.
- The macOS account password is short and numeric. Worth lengthening given the
  above.
