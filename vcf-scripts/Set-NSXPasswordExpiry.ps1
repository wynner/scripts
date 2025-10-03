<#
.SYNOPSIS
  Manage password expiry for NSX local users (root, admin, audit) on Manager & Edge nodes.
#>

param(
    [Parameter(Mandatory)] [string] $NSXManager,
    [Parameter(Mandatory)] [string] $Username,
    [int] $SetDays = 0,
    [switch] $EdgeOnly,
    [switch] $ManagerOnly
)

# Prompt for password hidden
$secure = Read-Host -AsSecureString "Enter password for user '$Username'"
$plainPass = [Runtime.InteropServices.Marshal]::PtrToStringAuto(
    [Runtime.InteropServices.Marshal]::SecureStringToBSTR($secure)
)

function Get-AuthHeader($u,$p) {
    $b = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes("$u`:$p"))
    return @{ "Authorization" = "Basic $b" }
}

function Get-UserInfo($base,$h,$uid) {
    try {
        return Invoke-RestMethod -Uri "$base/users/$uid" -Method GET -Headers $h -SkipCertificateCheck -ContentType "application/json"
    } catch {
        return $null
    }
}

function Set-UserExpiry($base,$h,$name,$uid,$days) {
    $body = @{ password_change_frequency = $days } | ConvertTo-Json
    try {
        Invoke-RestMethod -Uri "$base/users/$uid" -Method PUT -Headers $h -Body $body -ContentType "application/json" -SkipCertificateCheck
        Write-Host "    → Updated $name (ID $uid) to expiry = $days" -ForegroundColor Green
    } catch {
        Write-Host "    [ERROR] Could not update $name (ID $uid)" -ForegroundColor Red
    }
}

function ReportOrSetOnNode($nodeUrl,$h,$nodeName) {
    Write-Host "" ; Write-Host "==== $nodeName ===="
    "{0,-10} {1,6} {2,8}" -f "User","ID","Expiry"
    "{0,-10} {1,6} {2,8}" -f "----","--","------"
    foreach ($nm in $userMap.Keys) {
        $uid = $userMap[$nm]
        $info = Get-UserInfo $nodeUrl $h $uid
        if ($info) {
            $freq = $info.password_change_frequency
            Write-Host ("{0,-10} {1,6} {2,8}" -f $nm, $uid, $freq)
            if ($SetDays -gt 0) { Set-UserExpiry $nodeUrl $h $nm $uid $SetDays }
        } else {
            Write-Host ("{0,-10} {1,6} {2,8}" -f $nm, $uid, "-") -ForegroundColor Yellow
        }
    }
}

function Try-EdgeUserApi($mgr,$nid,$h,$nm,$uid) {
    $tpls = @("api/v1/transport-nodes/{0}/node","api/v1/transport-nodes/{0}","api/v1/edge-nodes/{0}/node")
    foreach ($tpl in $tpls) {
        $base = "$mgr/" + ($tpl -f $nid)
        $resp = Get-UserInfo $base $h $uid
        if ($resp) {
            $freq = $resp.password_change_frequency
            Write-Host "  * $nm (ID $uid): expiry = $freq" -ForegroundColor Cyan
            if ($SetDays -gt 0) { Set-UserExpiry $base $h $nm $uid $SetDays }
            return
        }
    }
    Write-Host "  [WARN] $nm (ID $uid): no API path on this edge" -ForegroundColor Yellow
}

### Main logic ###
$userMap = @{ "root"=0; "admin"=10000; "audit"=10002 }
$h = Get-AuthHeader $Username $plainPass
$mgrBase = "https://$NSXManager"

if (-not $EdgeOnly) {
    ReportOrSetOnNode "$mgrBase/api/v1/node" $h "NSX Manager"
}
if (-not $ManagerOnly) {
    $nodes = Invoke-RestMethod -Uri "$mgrBase/api/v1/transport-nodes" -Method GET -Headers $h -SkipCertificateCheck -ContentType "application/json"
    foreach ($n in $nodes.results | Where { $_.resource_type -eq "EDGE_NODE" -or $_.display_name -match "(?i)edge" }) {
        Write-Host "" ; Write-Host "==== Edge: $($n.display_name) (ID $($n.node_id)) ===="
        foreach ($nm in $userMap.Keys) {
            Try-EdgeUserApi $mgrBase $n.node_id $h $nm $userMap[$nm]
        }
    }
}

Write-Host "" ; Write-Host "=== Finished ===" -ForegroundColor Magenta
