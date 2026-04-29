<?php
header("Content-Type: text/plain");

// Constants you don’t want to repeat per host
$NTP    = "172.16.0.10";
$DNS    = "172.16.0.11,172.16.0.12";
$SSHKEY = '<INSERT YOUR PUBLIC SSH KEY HERE>';

// Accept GET params (set your default values here)
$hn        = $_GET['hn']        ?? null;
$ip        = $_GET['ip']        ?? null;
$mask      = $_GET['mask']      ?? "255.255.255.0";
$gw        = $_GET['gw']        ?? "192.168.10.1";
$vlan      = $_GET['vlan']      ?? "10";
$nic       = $_GET['nic']       ?? "vmnic0";
$ver       = $_GET['ver']       ?? "9.0.100.0";
$firstdisk = $_GET['firstdisk'] ?? "local";
$mac       = strtolower($_GET['mac'] ?? "");

// CSV lookup if MAC provided
// CSV columns: 0 mac, 1 hn, 2 ip, 3 mask, 4 gw, 5 vlan, 6 nic, 7 firstdisk, 8 nvme_model
$nvme_model = "";
if ((!$hn || !$ip) && $mac) {
  $csv = "/volume1/web/kickstart/hosts.csv";
  if (($fh = @fopen($csv, "r")) !== false) {
    while (($r = fgetcsv($fh)) !== false) {
      if (!isset($r[0])) continue;
      if (strtolower(trim($r[0])) === "mac") continue; // ignore the CSV header row
      if (strtolower(trim($r[0])) === $mac) {
        $r = array_map('trim', array_pad($r, 10, ""));
        // mac,hn,ip,mask,gw,vlan,nic,firstdisk,nvmetier
        $hn        = $r[1] ?: $hn;
        $ip        = $r[2] ?: $ip;
        $mask      = $r[3] ?: $mask;
        $gw        = $r[4] ?: $gw;
        $vlan      = $r[5] ?: $vlan;
        $nic       = $r[6] ?: $nic;
        $firstdisk = $r[7] ?: $firstdisk;
        $nvme_model= $r[8] ?: "";     // e.g. "Samsung SSD 990 PRO 2TB" or empty
        break;
      }
    }
    fclose($fh);
  }
}

if (!$hn || !$ip || !$mask || !$gw) {
  http_response_code(400);
  echo "# Missing hn/ip/mask/gw (pass as query or map MAC in hosts.csv)\n";
  exit;
}

// Short hostname for datastore naming
$short = strtolower(explode('.', $hn, 2)[0] ?? $hn);
$short = preg_replace('/[^a-z0-9\-]/', '', $short);

// Tier % by version. vSphere 8 only supports up to 100% tiering. vSphere 9 supports up to 400%
$tierPct = version_compare($ver, '9.0.0.0', '>=') ? 400 : (version_compare($ver, '8.0.3.0', '==') ? 100 : 100);

// NVMe Memory Tiering block (only if nvme_model provided in CSV)
$memTierBlock = '';
if ($nvme_model !== '') {
  // Escape double-quotes inside the model just in case
  $nvme_model_escaped = str_replace('"', '\"', $nvme_model);
  $memTierBlock = <<<MEM
# -------- NVMe Memory Tiering (auto-detect from model in CSV) --------
NVME_TIERING_DEVICE="\$(esxcli storage core device list \
  | grep -B2 "Model: {$nvme_model_escaped}" \
  | grep "Devfs Path:" \
  | head -n1 \
  | awk '{print \$3}')"

if [ -n "\$NVME_TIERING_DEVICE" ]; then
  esxcli system settings kernel set -s MemoryTiering -v TRUE
  esxcli system settings advanced set -o /Mem/TierNvmePct -i {$tierPct}
  esxcli system tierdevice delete -d \$NVME_TIERING_DEVICE 2>/dev/null
  esxcli system tierdevice create -d \$NVME_TIERING_DEVICE
fi

MEM;
}

// Emit the Kickstart
echo <<<KS
vmaccepteula
clearpart --drives=nvme0,nvme1,nvme2 --overwritevmfs
install --firstdisk="{$firstdisk}" --overwritevmfs
reboot

network --bootproto=static --vlanid={$vlan} --ip={$ip} --netmask={$mask} --gateway={$gw} --hostname={$hn} --nameserver={$DNS} --addvmportgroup=1 --device={$nic}
rootpw VMware1!VMware1!VMware1!

%firstboot --interpreter=busybox

NTP_SERVER={$NTP}
SSH_ROOT_KEY="{$SSHKEY}"
MANAGEMENT_VLAN=3
MANAGEMENT_VSWITCH_MTU=1500

# Wait for hostd
while ! vim-cmd hostsvc/runtimeinfo; do sleep 10; done

vim-cmd hostsvc/enable_ssh
vim-cmd hostsvc/start_ssh
vim-cmd hostsvc/enable_esx_shell
vim-cmd hostsvc/start_esx_shell

esxcli system settings advanced set -o /UserVars/SuppressShellWarning -i 1
esxcli system settings advanced set -o /UserVars/HostClientCEIPOptIn -i 1
esxcli system settings advanced set -o /Mem/ShareForceSalting -i 0

esxcli system ntp set -e true -s \$NTP_SERVER

# Datastore rename uses short host (no FQDN)
vim-cmd hostsvc/datastore/rename datastore1 local-vmfs-datastore-{$short}

{$memTierBlock}
# Optional: Ryzen + vSAN ESA mock
echo 'monitor_control.disable_apichv ="TRUE"' >> /etc/vmware/config
esxcli network firewall ruleset set -e true -r httpClient
esxcli software acceptance set --level CommunitySupported
esxcli software vib install -v https://github.com/lamw/nested-vsan-esa-mock-hw-vib/releases/download/1.0/nested-vsan-esa-mock-hw.vib --no-sig-check
esxcli network firewall ruleset set -e false -r httpClient

if [ -n "\$SSH_ROOT_KEY" ]; then
  echo "\$SSH_ROOT_KEY" > /etc/ssh/keys-root/authorized_keys
fi

esxcli network vswitch standard portgroup set -p "VM Network" -v \$MANAGEMENT_VLAN
esxcli network vswitch standard set -m \$MANAGEMENT_VSWITCH_MTU -v vSwitch0
esxcli network ip dns search add --domain=wynner.ie
esxcli network ip set --ipv6-enabled=false
/bin/generate-certificates

reboot
KS;
// Accept GET params (fallbacks)
$hn        = $_GET['hn']        ?? null;
$ip        = $_GET['ip']        ?? null;
$mask      = $_GET['mask']      ?? "255.255.255.0";
$gw        = $_GET['gw']        ?? "192.168.10.1";
$vlan      = $_GET['vlan']      ?? "10";
$nic       = $_GET['nic']       ?? "vmnic0";
$ver       = $_GET['ver']       ?? "9.0.0.0";
$firstdisk = $_GET['firstdisk'] ?? "local";
$mac       = strtolower($_GET['mac'] ?? "");

// CSV lookup if MAC provided
$nvme_model = "";  // from column 10 if present
if ((!$hn || !$ip) && $mac) {
  $csv = "/volume1/web/kickstart/hosts.csv";
  if (($fh = @fopen($csv, "r")) !== false) {
    while (($r = fgetcsv($fh)) !== false) {
      if (!isset($r[0])) continue;
      if (strtolower(trim($r[0])) === "mac") continue; // header
      if (strtolower(trim($r[0])) === $mac) {
        $r = array_map('trim', array_pad($r, 10, ""));
        // mac,hn,ip,mask,gw,vlan,nic,ver,firstdisk,nvmetier
        $hn        = $r[1] ?: $hn;
        $ip        = $r[2] ?: $ip;
        $mask      = $r[3] ?: $mask;
        $gw        = $r[4] ?: $gw;
        $vlan      = $r[5] ?: $vlan;
        $nic       = $r[6] ?: $nic;
        $ver       = $r[7] ?: $ver;
        $firstdisk = $r[8] ?: $firstdisk;
        $nvme_model= $r[9] ?: "";     // e.g. "Samsung SSD 990 PRO 2TB" or empty
        break;
      }
    }
    fclose($fh);
  }
}

if (!$hn || !$ip || !$mask || !$gw) {
  http_response_code(400);
  echo "# Missing hn/ip/mask/gw (pass as query or map MAC in hosts.csv)\n";
  exit;
}

// Short hostname for datastore naming
$short = strtolower(explode('.', $hn, 2)[0] ?? $hn);
$short = preg_replace('/[^a-z0-9\-]/', '', $short);

// Tier % by version
$tierPct = version_compare($ver, '9.0.0.0', '>=') ? 400 : (version_compare($ver, '8.0.3.0', '==') ? 100 : 100);

// NVMe Memory Tiering block (only if nvme_model provided in CSV)
$memTierBlock = '';
if ($nvme_model !== '') {
  // Escape double-quotes inside the model just in case
  $nvme_model_escaped = str_replace('"', '\"', $nvme_model);
  $memTierBlock = <<<MEM
# -------- NVMe Memory Tiering (auto-detect from model in CSV) --------
NVME_TIERING_DEVICE="\$(esxcli storage core device list \
  | grep -B2 "Model: {$nvme_model_escaped}" \
  | grep "Devfs Path:" \
  | head -n1 \
  | awk '{print \$3}')"

if [ -n "\$NVME_TIERING_DEVICE" ]; then
  esxcli system settings kernel set -s MemoryTiering -v TRUE
  esxcli system settings advanced set -o /Mem/TierNvmePct -i {$tierPct}
  esxcli system tierdevice delete -d \$NVME_TIERING_DEVICE 2>/dev/null
  esxcli system tierdevice create -d \$NVME_TIERING_DEVICE
fi

MEM;
}

// Emit the Kickstart
echo <<<KS
vmaccepteula
clearpart --alldrives --overwritevmfs
install --firstdisk="{$firstdisk}" --overwritevmfs
reboot

network --bootproto=static --vlanid={$vlan} --ip={$ip} --netmask={$mask} --gateway={$gw} --hostname={$hn} --nameserver={$DNS} --addvmportgroup=1 --device={$nic}
rootpw VMware1!VMware1!VMware1!

%firstboot --interpreter=busybox

NTP_SERVER={$NTP}
SSH_ROOT_KEY="{$SSHKEY}"
MANAGEMENT_VLAN=3
MANAGEMENT_VSWITCH_MTU=1500

# Wait for hostd
while ! vim-cmd hostsvc/runtimeinfo; do sleep 10; done

vim-cmd hostsvc/enable_ssh
vim-cmd hostsvc/start_ssh
vim-cmd hostsvc/enable_esx_shell
vim-cmd hostsvc/start_esx_shell

esxcli system settings advanced set -o /UserVars/SuppressShellWarning -i 1
esxcli system settings advanced set -o /UserVars/HostClientCEIPOptIn -i 1
esxcli system settings advanced set -o /Mem/ShareForceSalting -i 0

esxcli system ntp set -e true -s \$NTP_SERVER

# Datastore rename uses short host (no FQDN)
vim-cmd hostsvc/datastore/rename datastore1 local-vmfs-datastore-{$short}

{$memTierBlock}
# Optional: Ryzen + vSAN ESA mock
echo 'monitor_control.disable_apichv ="TRUE"' >> /etc/vmware/config
esxcli network firewall ruleset set -e true -r httpClient
esxcli software acceptance set --level CommunitySupported
esxcli software vib install -v https://github.com/lamw/nested-vsan-esa-mock-hw-vib/releases/download/1.0/nested-vsan-esa-mock-hw.vib --no-sig-check
esxcli network firewall ruleset set -e false -r httpClient

if [ -n "\$SSH_ROOT_KEY" ]; then
  echo "\$SSH_ROOT_KEY" > /etc/ssh/keys-root/authorized_keys
fi

esxcli network vswitch standard portgroup set -p "VM Network" -v \$MANAGEMENT_VLAN
esxcli network vswitch standard set -m \$MANAGEMENT_VSWITCH_MTU -v vSwitch0
esxcli network ip dns search add --domain=wynner.ie
esxcli network ip set --ipv6-enabled=false
/bin/generate-certificates

reboot
KS;
