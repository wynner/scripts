param(
    [Parameter(Mandatory=$true)]
    [string]$vCenter,

    [Parameter(Mandatory=$false)]
    [string]$CsvPath = ".\\TPM-RecoveryKeys_$((Get-Date).ToString('yyyyMMdd_HHmmss')).csv"
)

# ---------- Connect ----------
Import-Module VMware.PowerCLI -ErrorAction Stop
Set-PowerCLIConfiguration -InvalidCertificateAction Ignore -Confirm:$false | Out-Null
Connect-VIServer -Server $vCenter | Out-Null

# ---------- Collect ----------
$report = @()

Get-VMHost | Sort-Object Name | ForEach-Object {

    $esxcli  = Get-EsxCli -VMHost $_ -V2
    $encInfo = $esxcli.system.settings.encryption.get.Invoke()

    if ($encInfo.Mode -eq 'TPM') {
        $rk = $esxcli.system.settings.encryption.recovery.list.Invoke()
    }

    $report += [pscustomobject]@{
        HostName       = $_.Name
        Cluster        = $_.Parent.Name
        EncryptionMode = $encInfo.Mode
        RecoveryID     = $rk?.RecoveryID
        RecoveryKey    = $rk?.Key
    }
}

# ---------- Output ----------
$report | Format-Table -AutoSize
$report | Export-Csv -Path $CsvPath -NoTypeInformation

Write-Host "Backup complete – keys written to '$CsvPath'."
