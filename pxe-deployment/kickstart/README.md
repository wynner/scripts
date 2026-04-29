# Kickstart Generator

This folder contains the dynamic ESXi kickstart generator and the host inventory it uses.

## Destructive Storage Warning

This kickstart is intended for vSAN nodes that do not have external shared storage attached during installation.

The generated install currently includes:

```text
clearpart --alldrives --overwritevmfs
```

That command can wipe every VMFS datastore visible to the ESXi installer. If the host can see Fibre Channel, iSCSI, FCoE, SAS-attached shared shelves, or any other external datastore, those datastores may be erased.

Do not use this unchanged on hosts with FC-connected datastores or other shared storage presented. Disconnect, mask, or unzone shared storage before imaging, or replace `--alldrives` with an explicit local disk target validated for the hardware.

## Files

```text
gen.php    PHP script that emits an ESXi kickstart file.
hosts.csv  Per-host inventory used by gen.php when iPXE passes a MAC address.
```

The normal boot flow is:

1. `autoexec.ipxe` calls `gen.php?mac=<host-mac>&ver=<esxi-version>`.
2. `gen.php` looks up the MAC address in `hosts.csv`.
3. `gen.php` emits a plain-text ESXi kickstart file with host-specific network, disk, and firstboot settings.

## gen.php

Edit `gen.php` for customer-wide defaults and post-install actions.

The current working flow is MAC-driven: iPXE passes `mac` and `ver`, then `gen.php` reads the matching row from `hosts.csv`. Query parameters can still be used for manual testing or overrides.

Customer values to change:

```php
$NTP    = "172.16.0.10";
$DNS    = "172.16.0.11,172.16.0.12";
$SSHKEY = '<customer-root-public-ssh-key>';
```

The checked-in script may contain a real lab SSH public key while testing. Replace it before publishing the project for reuse.

Defaults used when values are not supplied by `hosts.csv` or query parameters:

```php
$mask      = $_GET['mask']      ?? "255.255.255.0";
$gw        = $_GET['gw']        ?? "192.168.10.1";
$vlan      = $_GET['vlan']      ?? "10";
$nic       = $_GET['nic']       ?? "vmnic0";
$ver       = $_GET['ver']       ?? "9.0.0.0";
$firstdisk = $_GET['firstdisk'] ?? "local";
```

CSV lookup path:

```php
$csv = "/volume1/web/kickstart/hosts.csv";
```

Change this to the real path on the PXE web server. If `hosts.csv` sits beside `gen.php`, a portable option is:

```php
$csv = __DIR__ . "/hosts.csv";
```

CSV lookup mapping:

```php
// mac,hn,ip,mask,gw,vlan,nic,ver,firstdisk,nvmetier
$hn        = $r[1] ?: $hn;
$ip        = $r[2] ?: $ip;
$mask      = $r[3] ?: $mask;
$gw        = $r[4] ?: $gw;
$vlan      = $r[5] ?: $vlan;
$nic       = $r[6] ?: $nic;
$ver       = $r[7] ?: $ver;
$firstdisk = $r[8] ?: $firstdisk;
$nvme_model= $r[9] ?: "";
```

Kickstart install settings to review:

```text
clearpart --alldrives --overwritevmfs
install --firstdisk="<value from hosts.csv>" --overwritevmfs
network --bootproto=static ...
rootpw VMware1!VMware1!VMware1!
```

Before customer use, replace the sample root password with a customer-approved process. Also confirm the disk selection and `clearpart` targets are correct, because these commands erase disks. `--alldrives` is only appropriate when the host cannot see shared storage that must be preserved.

Firstboot settings to review:

```text
MANAGEMENT_VLAN=3
MANAGEMENT_VSWITCH_MTU=1500
vim-cmd hostsvc/enable_ssh
vim-cmd hostsvc/start_ssh
vim-cmd hostsvc/enable_esx_shell
vim-cmd hostsvc/start_esx_shell
esxcli network ip dns search add --domain=wynner.ie
```

Change the VLAN, MTU, DNS search domain, and shell/SSH policy to match the customer standard.

Optional or lab-specific settings to review before production use:

```text
NVMe memory tiering block
monitor_control.disable_apichv
nested-vsan-esa-mock-hw.vib install
CommunitySupported acceptance level
```

Remove these if the customer does not explicitly require them.

## hosts.csv

Edit `hosts.csv` for per-host settings.

Header:

```csv
mac,hn,ip,mask,gw,vlan,nic,ver,firstdisk,nvmetier
```

Columns:

```text
mac        Host MAC address used for lookup from iPXE.
hn         ESXi hostname or FQDN.
ip         Static management IP address.
mask       Management subnet mask.
gw         Management gateway.
vlan       VLAN ID used by the ESXi installer for the management network.
nic        Physical NIC used during install, for example vmnic0.
ver        ESXi version folder to boot, for example 9.0.0.100 or 8.0.3.0.
firstdisk  ESXi install target, for example local or a specific disk selector.
nvmetier   Optional NVMe model string for the memory tiering block.
```

Example:

```csv
mac,hn,ip,mask,gw,vlan,nic,ver,firstdisk,nvmetier
00-50-56-a9-5a-86,esx01.example.com,192.168.10.11,255.255.255.0,192.168.10.1,10,vmnic0,9.0.0.100,local,
```

Use one MAC address format consistently. The iPXE script is intended to pass lower-case, hyphen-separated MAC addresses, so use the same format in `hosts.csv` or normalize both sides in `gen.php`.

Only populate `nvmetier` when the customer wants the generated kickstart to configure NVMe memory tiering. The value should match the NVMe device model string shown by:

```text
esxcli storage core device list
```

## Testing

Test the generator before booting a host:

```text
http://<pxe-server>/kickstart/gen.php?mac=<mac-address>&ver=<esxi-version>
```

You can also test without `hosts.csv` by passing explicit values:

```text
http://<pxe-server>/kickstart/gen.php?hn=esx01.example.com&ip=192.168.10.11&mask=255.255.255.0&gw=192.168.10.1&vlan=10&nic=vmnic0&firstdisk=local&ver=9.0.1.0
```

Confirm the generated output contains the expected hostname, IP address, gateway, VLAN, DNS servers, install disk, and firstboot commands before using it to image hardware.

Also confirm the generated kickstart appears once. If `gen.php` contains multiple copied generator blocks, remove the obsolete block or keep duplicated defaults in sync before publishing.

## Security Notes

This generator emits unattended install instructions. Restrict access to the provisioning network and do not expose it to user networks or the internet.

Validate any values passed through query parameters before using this for production customer deployments. Query parameters and CSV values are inserted into the generated kickstart output.
