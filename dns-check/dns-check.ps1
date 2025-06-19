param (
    [string]$InputFile = "./input.txt",
    [string]$DnsServer = "8.8.8.8"
)

function Resolve-Forward {
    param ($Fqdn, $Server)
    $result = nslookup $Fqdn $Server 2>&1
    $lines = $result -split "`n"
    $ipLines = $lines | Where-Object { $_ -match "Address:" -and $_ -notmatch "$Server" }
    if ($ipLines) {
        return ($ipLines -replace "Address:\s*", "") -join ", "
    }
    return $null
}


function Resolve-Reverse {
    param ($Ip, $Server)
    $result = nslookup $Ip $Server 2>&1
    $ptr = ($result -split "`n" | Where-Object { $_ -match "name =" }) -replace ".*name = ", ""
    if ($ptr) {
        return $ptr.Trim(".")
    }
    return $null
}


$inputLines = Get-Content -Path $InputFile | Where-Object { $_.Trim() -ne "" }

$results = @()

foreach ($line in $inputLines) {
    $item = $line.Trim()
    $isIP = [System.Net.IPAddress]::TryParse($item, [ref]$null)

    Write-Host "Checking: $item on $DnsServer" -ForegroundColor DarkGray

    if ($isIP) {
        $fqdn = Resolve-Reverse -Ip $item -Server $DnsServer
        $status = if ($fqdn) { "Reverse OK" } else { "No PTR Record" }
        $results += [PSCustomObject]@{
            Input  = $item
            Type   = "IP"
            Result = $fqdn
            Status = $status
        }
    } else {
        $ip = Resolve-Forward -Fqdn $item -Server $DnsServer
        $status = if ($ip) { "Forward OK" } else { "No A Record" }
        $results += [PSCustomObject]@{
            Input  = $item
            Type   = "FQDN"
            Result = $ip
            Status = $status
        }
    }
}

# Display results in color
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
$results | Export-Csv -NoTypeInformation -Path "./DNS_Validation_Report_$timestamp.csv"
