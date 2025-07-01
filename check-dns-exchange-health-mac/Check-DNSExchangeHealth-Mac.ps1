$domain = "domain.com"
$dnsServer = "1.1.1.1"
$autodiscoverHost = "autodiscover.$domain"
$mailHost = "exchange.domain.com"
$selector = "selector1"

function Run-Dig {
    param(
        [string]$Query,
        [string]$Type
    )
    Write-Host "→ $Query ($Type)"
    $result = & dig +short @$dnsServer $Query $Type
    if (-not $result) {
        Write-Warning "$Type record not found for $Query"
    } else {
        $result
    }
    Write-Host ""
}

Write-Host "`n=== DNS Health Check for Exchange Server (via dig) ===`n"

Write-Host "==> A Record"
Run-Dig -Query $mailHost -Type "A"

Write-Host "==> MX Record"
Run-Dig -Query $domain -Type "MX"

Write-Host "==> SPF Record (TXT)"
Run-Dig -Query $domain -Type "TXT"

Write-Host "==> DKIM Record (optional)"
Run-Dig -Query "$selector._domainkey.$domain" -Type "TXT"

Write-Host "==> DMARC Record"
Run-Dig -Query "_dmarc.$domain" -Type "TXT"

Write-Host "==> Autodiscover A Record"
Run-Dig -Query $autodiscoverHost -Type "A"

Write-Host "=== DNS Health Check Complete ===`n"