param (
    [string]$InputFile = ".\input.txt",
    [string]$DnsServer = "8.8.8.8"
)

function Resolve-Forward {
    param ($Fqdn, $Server)
    try {
        $result = Resolve-DnsName -Name $Fqdn -Server $Server -ErrorAction Stop
        return $result | Where-Object { $_.Type -eq "A" } | Select-Object -ExpandProperty IPAddress
    } catch {
        return $null
    }
}

function Resolve-Reverse {
    param ($Ip, $Server)
    try {
        $result = Resolve-DnsName -Name ([System.Net.IPAddress]::Parse($Ip).GetAddressBytes() -join '.') + '.in-addr.arpa' -Server $Server -ErrorAction Stop -Type PTR
        return $result | Select-Object -ExpandProperty NameHost
    } catch {
        return $null
    }
}

$inputLines = Get-Content -Path $InputFile | Where-Object { $_ -and $_.Trim() -ne "" }

$results = @()

foreach ($line in $inputLines) {
    $item = $line.Trim()
    $isIP = [System.Net.IPAddress]::TryParse($item, [ref]$null)

    if ($isIP) {
        $fqdn = Resolve-Reverse -Ip $item -Server $DnsServer
        $status = if ($fqdn) { "Reverse OK" } else { "No PTR Record" }
        $results += [PSCustomObject]@{
            Input     = $item
            Type      = "IP"
            Result    = $fqdn
            Status    = $status
        }
    } else {
        $ip = Resolve-Forward -Fqdn $item -Server $DnsServer
        $status = if ($ip) { "Forward OK" } else { "No A Record" }
        $results += [PSCustomObject]@{
            Input     = $item
            Type      = "FQDN"
            Result    = $ip -join ", "
            Status    = $status
        }
    }
}

# Color-coded output
Write-Host "`nDNS Validation Results (Server: $DnsServer)" -ForegroundColor Cyan
Write-Host "------------------------------------------------------------"
Write-Host ("{0,-30} {1,-8} {2,-30} {3,-15}" -f "Input", "Type", "Result", "Status") -ForegroundColor Yellow
Write-Host "------------------------------------------------------------"

foreach ($entry in $results) {
    $color = if ($entry.Status -like "*OK") { "Green" } else { "Red" }
    Write-Host ("{0,-30} {1,-8} {2,-30} {3,-15}" -f $entry.Input, $entry.Type, $entry.Result, $entry.Status) -ForegroundColor $color
}

# Optional CSV export
$timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
$results | Export-Csv -NoTypeInformation -Path ".\DNS_Validation_Report_$timestamp.csv"
