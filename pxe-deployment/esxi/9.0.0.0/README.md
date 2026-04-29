# ESXi 9.0.0.0 Installer Payload

This folder contains the tracked `boot.cfg` template for ESXi 9.0.0.0.

Do not track Broadcom-owned ESXi binaries, VIBs, or ISO payload files in Git.

At deployment time, customers must copy the installer files from their own licensed ESXi 9.0.0.0 ISO into this folder. The folder must contain `mboot.efi` and every module referenced by `boot.cfg`.

Customers should obtain ESXi installation media from the Broadcom Support Portal using their own entitlement.

Broadcom Support Portal:

```text
https://support.broadcom.com/
```

Broadcom ESXi download guidance:

```text
https://knowledge.broadcom.com/external/article/372545/download-esxi-patch-and-the-isos-for-lat.html
```

Expected runtime files include:

```text
mboot.efi
*.b00
*.v00
*.v01
*.t00
*.tgz
*.gz
```
