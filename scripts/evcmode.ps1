param(
    [Parameter(Mandatory = $true)]
    [string]$ClusterName
)

# --- Robust Connection Check ---
try {
    $null = Get-View -Id "ServiceInstance" -ErrorAction Stop
} catch {
    # Prompt user for vCenter if not connected
    $vcServer = Read-Host "Enter vCenter Server name or IP"
    Connect-VIServer -Server $vcServer
}

# Get cluster and hosts
$cluster = Get-Cluster -Name $ClusterName -ErrorAction Stop
$hosts = Get-VMHost -Location $cluster
$poweredVMs = $hosts | Get-VM | Where-Object { $_.PowerState -in ("PoweredOn", "Suspended") }

# Collect VM data
$results = @()
foreach ($vm in $poweredVMs) {
    $vmView = Get-View -Id $vm.Id
    $cpuFeatureOverride = $vmView.Config.ExtraConfig | Where-Object { $_.Key -like "cpuid*" }

    $results += [PSCustomObject]@{
        VMName         = $vm.Name
        VMHost         = $vm.VMHost.Name
        PowerState     = $vm.PowerState
        CPUIDOverrides = if ($cpuFeatureOverride) {
            ($cpuFeatureOverride | ForEach-Object { "$($_.Key)=$($_.Value)" }) -join "; "
        } else {
            "None Detected"
        }
    }
}

# Output results
if ($results.Count -eq 0) {
    Write-Host "`nNo powered-on or suspended VMs found in the cluster." -ForegroundColor Yellow
    return
}

Write-Host "`n===== EVC Blocking VMs Summary =====" -ForegroundColor Cyan
$results | Sort-Object VMHost, VMName | Format-Table -AutoSize

$overrideVMs = $results | Where-Object { $_.CPUIDOverrides -ne "None Detected" }

if ($overrideVMs.Count -gt 0) {
    Write-Host "`nSome VMs have manual CPUID overrides that can block EVC mode." -ForegroundColor Red
} else {
    Write-Host "`nNo CPUID overrides were detected, but powered-on VMs may still block EVC mode due to current CPU state." -ForegroundColor Yellow
}

Write-Host "`nTo enable EVC mode:" -ForegroundColor Green
Write-Host "1. Shut down all powered-on or suspended VMs in the cluster."
Write-Host "2. Enable EVC mode (Ice Lake)."
Write-Host "3. Power VMs back on. They will conform to the new EVC mask." -ForegroundColor Green