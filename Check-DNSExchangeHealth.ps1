# DNS targets (replace with your real domain if needed)
$domain = "domain.com"
$autodiscoverHost = "autodiscover.$domain"
$mailHost = "exchange.$domain"
$dnsServer = "1.1.1.1"

function Test-Dns {
    param (
        [string]$Name,
        [string]$Type
    )
    try {
        Resolve-DnsName -Name $Name -Type $Type -Server $dnsServer -ErrorAction Stop
    } catch {
        Write-Warning "$Type record lookup failed for $Name"
    }
}

Write-Host "`n=== DNS Health Check for Exchange Server ===`n"

# A Record Check
Write-Host "==> A Record"
Test-Dns -Name $mailHost -Type A
Write-Host ""

# MX Record Check
Write-Host "==> MX Record"
Test-Dns -Name $domain -Type MX
Write-Host ""

# SPF (TXT) Check
Write-Host "==> SPF Record (TXT)"
$spf = Resolve-DnsName -Name $domain -Type TXT -Server $dnsServer | Where-Object { $_.Strings -match "v=spf1" }
if ($spf) {
    Write-Host $spf.Strings
} else {
    Write-Warning "No SPF record found!"
}
Write-Host ""

# DKIM Record Check (optional - adjust selector as needed)
Write-Host "==> DKIM Record (optional)"
$selector = "selector1"  # Common default. Use your actual selector.
$dkimDomain = "$selector._domainkey.$domain"
try {
    Resolve-DnsName -Name $dkimDomain -Type TXT -Server $dnsServer -ErrorAction Stop | Select-Object -ExpandProperty Strings
} catch {
    Write-Warning "No DKIM record found for $dkimDomain"
}
Write-Host ""

# DMARC Record
Write-Host "==> DMARC Record"
$dmarc = "_dmarc.$domain"
try {
    Resolve-DnsName -Name $dmarc -Type TXT -Server $dnsServer -ErrorAction Stop | Select-Object -ExpandProperty Strings
} catch {
    Write-Warning "No DMARC record found!"
}
Write-Host ""

# Autodiscover DNS
Write-Host "==> Autodiscover DNS"
Test-Dns -Name $autodiscoverHost -Type A
Write-Host ""

# Performance: DNS latency test
Write-Host "==> DNS Query Performance"
$timer = Measure-Command {
    Resolve-DnsName $domain -Server $dnsServer
}
Write-Host "Lookup time: $($timer.TotalMilliseconds) ms"

Write-Host "`n=== DNS Health Check Complete ===`n"