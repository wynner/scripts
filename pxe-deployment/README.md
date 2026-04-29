# ESXi PXE Imaging Framework

This project provides a publishable iPXE and kickstart framework for imaging ESXi hosts from a customer-owned PXE server. It is intended as a starting point that customers adapt to their own network, ESXi media, host naming, IP addressing, and build standards.

The published project should include the scripts, templates, sample inventory, and documentation. It should not include Broadcom-owned ESXi binaries, VIBs, ISO payload files, or installer artifacts. Customers must supply those files from their own licensed ESXi installation media.

## Destructive Storage Warning

This project is written for imaging vSAN nodes that do not have external shared storage attached during installation.

The generated kickstart currently uses:

```text
clearpart --alldrives --overwritevmfs
```

That command can wipe every VMFS datastore visible to the installer. If the host can see Fibre Channel, iSCSI, FCoE, SAS-attached shared shelves, or any other external datastore during install, those datastores may be erased.

Do not use this kickstart unchanged on hosts with FC-connected datastores or other shared storage presented. Disconnect, mask, or unzone shared storage before imaging, or replace `--alldrives` with an explicit local disk selection that has been validated for the target hardware.

The workflow is:

1. A physical host boots using UEFI PXE.
2. DHCP/TFTP delivers `ipxe.efi`.
3. iPXE runs `tftpboot/autoexec.ipxe` and presents an ESXi version menu.
4. iPXE loads the selected ESXi `mboot.efi` and `boot.cfg` over HTTP. The customer supplies `mboot.efi` from their own ESXi ISO.
5. ESXi installer retrieves a generated kickstart file from `kickstart/gen.php`.
6. `gen.php` maps the host MAC address to `hosts.csv` and emits host-specific install settings.

## Runtime Folder Layout

After a customer copies their own ESXi media into place, the PXE server runtime layout should look like this:

```text
pxe-deployment/
  tftpboot/
    ipxe.efi
    autoexec.ipxe
  esxi/
    8.0.3.0/
      boot.cfg
      mboot.efi
      <ESXi installer payload files copied from ISO>
    9.0.0.0/
      boot.cfg
      mboot.efi
      <ESXi installer payload files copied from ISO>
    9.0.0.100/
      boot.cfg
      mboot.efi
      <ESXi installer payload files copied from ISO>
    9.0.1.0/
      boot.cfg
      mboot.efi
      <ESXi installer payload files copied from ISO>
  kickstart/
    gen.php
    hosts.csv
```

The published repository is not a complete ESXi media mirror. Each `boot.cfg` references many ESXi payload files, and customers must copy the full payload from their licensed ESXi ISO into the matching version folder before booting hosts.

## Requirements

- UEFI-capable servers configured to boot from PXE.
- A DHCP service that can point hosts to the PXE boot loader.
- A TFTP service for `tftpboot/ipxe.efi`.
- An HTTP server with PHP support for the ESXi files and kickstart generator.
- Customer-owned ESXi installation media for each version offered in the menu.
- A management network that can reach the PXE HTTP server during installation.

For a small lab, TFTP, HTTP, and PHP can run on the same server. For customer production use, place the service on a restricted provisioning network.

## Deploying To A PXE Server

Use `pxe-deployment` as the HTTP document root, or copy its contents to the web server document root after the customer has added their own ESXi media.

Example HTTP paths expected by the current files:

```text
http://<pxe-server>/esxi/9.0.1.0/boot.cfg
http://<pxe-server>/esxi/9.0.1.0/mboot.efi
http://<pxe-server>/kickstart/gen.php
```

Use `pxe-deployment/tftpboot` as the TFTP root, or copy its contents to the TFTP root.

Example TFTP files:

```text
ipxe.efi
autoexec.ipxe
```

Your DHCP and iPXE flow must chain to `autoexec.ipxe` after `ipxe.efi` starts. Common options are:

- Build or use an `ipxe.efi` with an embedded script that chains `http://<pxe-server>/tftpboot/autoexec.ipxe`.
- Use DHCP user-class logic so normal PXE clients receive `ipxe.efi`, and iPXE clients receive the `autoexec.ipxe` script.
- Chain the script manually from the iPXE shell while testing.

## Preparing ESXi Media

For each ESXi version you want to offer:

1. Create a folder under `esxi/` using the version string used in `autoexec.ipxe`.
2. Mount or extract the matching customer-owned ESXi ISO.
3. Copy `mboot.efi` and the installer payload into the version folder.
4. Ensure every module listed in `boot.cfg` exists in that same version folder.
5. Update `boot.cfg` so `prefix` points at the HTTP URL for that version.

Example:

```text
prefix=http://<pxe-server>/esxi/9.0.1.0
```

Do not enable a menu entry until its version folder has the full ESXi payload. If only `mboot.efi` and `boot.cfg` are present, the installer will start loading and then fail when the referenced modules cannot be fetched.

## Configure The iPXE Menu

Edit `tftpboot/autoexec.ipxe` for the customer environment.

Update the hard-coded HTTP server IP or DNS name in the ESXi payload and kickstart URLs:

```ipxe
set base http://<pxe-server-ip-or-name>/esxi/${ver}
set ks http://<pxe-server-ip-or-name>/kickstart/gen.php?mac=${mac}&ver=${ver}
```

Add, remove, or rename menu items to match the ESXi versions the customer wants to deploy:

```ipxe
item esx9010 ESXi 9.0.1.0
```

Each menu entry should set a version variable that maps to an existing `esxi/<version>/` folder:

```ipxe
set ver9 9.0.1.0
```

The current menu passes the host MAC and ESXi version to the kickstart generator:

```ipxe
set ks http://${host}/kickstart/gen.php?mac=${mac}&ver=${ver9}
```

## Configure Host Inventory

The `kickstart/hosts.csv` file provides per-host install settings. Keep one row per server.

Columns:

```csv
mac,hn,ip,mask,gw,vlan,nic,ver,firstdisk,nvmetier
```

Column meaning:

```text
mac        Host MAC address used for lookup.
hn         ESXi hostname or FQDN.
ip         Static management IP address.
mask       Management subnet mask.
gw         Management default gateway.
vlan       Management VLAN ID used during installation.
nic        Physical NIC used for the management network, for example vmnic0.
ver        ESXi version folder to boot, for example 9.0.0.100 or 8.0.3.0.
firstdisk  ESXi install target, for example local or a specific disk selector.
nvmetier   Optional NVMe model string used for memory tiering configuration.
```

Example:

```csv
mac,hn,ip,mask,gw,vlan,nic,ver,firstdisk,nvmetier
00-50-56-a9-5a-86,esx01.example.com,192.168.10.11,255.255.255.0,192.168.10.1,10,vmnic0,9.0.0.100,local,
```

Use one MAC format consistently. The current iPXE script is intended to send lower-case, hyphen-separated MAC addresses, so use that format in `hosts.csv`.

## Configure Kickstart Generation

Edit `kickstart/gen.php` before customer use.

At minimum, replace these customer-specific values:

```php
$NTP    = "<customer-ntp-server>";
$DNS    = "<customer-dns-server-1>,<customer-dns-server-2>";
$SSHKEY = "<customer-root-public-ssh-key>";
```

Also review and adjust:

- Default gateway, subnet mask, VLAN, and management NIC defaults.
- Root password handling.
- Management VLAN and vSwitch MTU.
- DNS search domain.
- Datastore naming convention.
- Optional NVMe memory tiering behavior.
- Optional VIB installation block.
- Whether SSH and ESXi shell should be enabled after installation.

For production use, do not leave the sample `rootpw` value in place. Use a customer-approved password process, preferably unique per deployment batch or host.

The current generator can also be called with explicit query parameters for testing:

```text
http://<pxe-server>/kickstart/gen.php?hn=esx01.example.com&ip=192.168.10.11&mask=255.255.255.0&gw=192.168.10.1&vlan=10&nic=vmnic0&firstdisk=local&ver=9.0.1.0
```

In normal customer use, prefer MAC-based lookup from `hosts.csv` so host settings are controlled in one inventory file.

## Recommended Customer Workflow

1. Build a PXE server on an isolated provisioning VLAN.
2. Download or clone the publishable framework files.
3. Copy each customer-approved ESXi ISO payload into `esxi/<version>/`.
4. Publish `pxe-deployment` through HTTP/PHP and `tftpboot` through TFTP.
5. Update each `boot.cfg` `prefix` value to the customer PXE server URL.
6. Update `autoexec.ipxe` with the PXE server address and desired ESXi menu entries.
7. Update `hosts.csv` with the customer's host MAC addresses and static management details.
8. Update `gen.php` for customer NTP, DNS, SSH key, password, VLAN, MTU, and post-install settings.
9. Test `gen.php` in a browser or with `curl` for at least one host before booting hardware.
10. Boot one non-production host first and confirm networking, disk selection, datastore naming, and firstboot tasks.
11. Image the remaining hosts in batches.

## Validation Checklist

Before recommending the deployment to a customer, verify:

- DHCP points UEFI clients at `ipxe.efi`.
- iPXE can reach the HTTP server.
- The iPXE menu loads and each menu item maps to an existing `esxi/<version>/` folder.
- Every `boot.cfg` module file exists in its version folder.
- `gen.php` returns a complete kickstart for each MAC address in scope.
- Hostname, IP, gateway, VLAN, DNS, and NTP values are customer-specific.
- The ESXi install target is correct and will not erase the wrong disk.
- Root password and SSH key handling meet the customer's security requirements.
- Optional lab-only commands are removed or approved.
- The PXE and kickstart endpoints are not exposed outside the provisioning network.

## Security Notes

Treat the PXE service as sensitive infrastructure. It can install and configure bare-metal hosts without further confirmation.

Recommended controls:

- Restrict access to the provisioning VLAN.
- Limit HTTP and TFTP access to known build networks.
- Remove sample passwords and sample domains.
- Do not expose `gen.php` to user networks or the internet.
- Validate all customer input if `gen.php` is used with query parameters.
- Keep `hosts.csv` under change control.
- Disable or remove SSH/ESXi shell enablement if it is not required after imaging.
- Remove any lab-only VIB installation steps before customer production use unless explicitly required.

## Troubleshooting

If the host does not receive `ipxe.efi`, check DHCP options, DHCP policies, and TFTP reachability.

If the iPXE menu does not load, confirm that `autoexec.ipxe` is being chained after iPXE starts and that the HTTP URL is reachable.

If ESXi starts loading but fails during module download, check the `boot.cfg` `prefix` value and confirm all referenced module files exist under the selected version folder.

If kickstart generation returns `Missing hn/ip/mask/gw`, check that the host MAC address format matches `hosts.csv`, or test with explicit query parameters.

If the host installs but firstboot settings are missing, review `/var/log/hostd.log`, `/var/log/esxupdate.log`, and the ESXi installer logs on the deployed host.
