# TFTP Boot Files

This folder contains the iPXE script used after UEFI network boot.

Track in Git:

- `autoexec.ipxe`
- `README.md`

Do not track generated or downloaded EFI binaries or old copied iPXE scripts.

`autoexec.ipxe` currently contains the working ESXi imaging menu. Before reuse, update the hard-coded PXE HTTP server address in the `base`, `base9`, and `ks` URLs:

```ipxe
set base http://172.16.0.11/esxi/${ver}
set ks http://172.16.0.11/kickstart/gen.php?mac=${mac}&ver=${ver}
set base9 http://172.16.0.11/esxi/${ver9}
```

Add or remove menu entries so they match the ESXi version folders that exist under `../esxi/`.

At deployment time, place `ipxe.efi` in this folder. Customers can obtain iPXE from the official iPXE project or build their own UEFI binary with any required embedded chainload script.

Official project:

```text
https://ipxe.org/
```

Download and build guidance:

```text
https://ipxe.org/download
```

Expected runtime file:

```text
ipxe.efi
```
