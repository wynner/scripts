Import-Module WebAdministration -ErrorAction SilentlyContinue
Import-Module Exchange -ErrorAction SilentlyContinue

Write-Host "`n=== Exchange 2016 Health & Best Practices Audit ===`n"

# 1. Server Roles and Build
Write-Host "==> Exchange Server Info"
Get-ExchangeServer | Select Name, Edition, AdminDisplayVersion, ServerRole | Format-Table -AutoSize
Write-Host ""

# 2. Service Health
Write-Host "==> Key Services"
$services = "MSExchangeIS", "MSExchangeTransport", "W3SVC", "MSExchangeMailboxAssistants", "MSExchangeFrontEndTransport"
Get-Service $services | Format-Table DisplayName, Status, StartType -AutoSize
Write-Host ""

# 3. Certificates
Write-Host "==> Certificate Status"
$certs = Get-ExchangeCertificate | Where-Object { $_.NotAfter -gt (Get-Date) } | Select Subject, Thumbprint, NotAfter, Services
$certs | Format-Table -AutoSize
$soon = $certs | Where-Object { $_.NotAfter -lt (Get-Date).AddDays(90) }
if ($soon) {
    Write-Warning "Some certs expire within 90 days!"
}
Write-Host ""

# 4. Mail Flow
Write-Host "==> Mail Flow Test"
Test-Mailflow | Format-List
Write-Host ""

# 5. Queue Check
Write-Host "==> Mail Queues"
Get-Queue | Select Identity, Status, MessageCount | Format-Table -AutoSize
Write-Host ""

# 6. Database Health
Write-Host "==> Mounted Databases and Circular Logging"
Get-MailboxDatabase | Select Name, Server, Mounted, CircularLoggingEnabled | Format-Table -AutoSize
Write-Host ""

# 7. Virtual Directory URLs
Write-Host "==> Virtual Directory URLs"
$vdCmdlets = @("Get-OwaVirtualDirectory","Get-EcpVirtualDirectory","Get-ActiveSyncVirtualDirectory","Get-AutodiscoverVirtualDirectory","Get-OabVirtualDirectory","Get-WebServicesVirtualDirectory")
foreach ($cmd in $vdCmdlets) {
    if (Get-Command $cmd -ErrorAction SilentlyContinue) {
        Invoke-Expression "$cmd | Select Name, InternalUrl, ExternalUrl | Format-Table -AutoSize"
    } else {
        Write-Warning "$cmd not available."
    }
}
Write-Host ""

# 8. SCP Check
Write-Host "==> Autodiscover SCP"
Get-ClientAccessService | Select Name, AutoDiscoverServiceInternalUri | Format-Table -AutoSize
Write-Host ""

# 9. Anti-malware Agent
Write-Host "==> Anti-Malware Agent"
if (Get-Command Get-MalwareFilteringServer -ErrorAction SilentlyContinue) {
    Get-MalwareFilteringServer | Select Name, MalwareFilteringEnabled | Format-Table -AutoSize
} else {
    Write-Warning "Anti-malware cmdlets not available."
}
Write-Host ""

# 10. Recent Errors in Event Logs (2 hours)
Write-Host "==> Event Logs (Last 2 Hours)"
try {
    Get-WinEvent -FilterHashtable @{ LogName = 'Application'; StartTime = (Get-Date).AddHours(-2); ProviderName = 'MSExchange*'; Level = 2 } |
    Select TimeCreated, Id, Message | Format-Table -AutoSize
} catch {
    Write-Warning "No Exchange-related errors in event log."
}
Write-Host ""

# 11. DNS Records to Consider
Write-Host "==> DNS Best Practices (manual checks)"
Write-Host "- SPF record: should exist for your sending domain (check via nslookup or dig)"
Write-Host "- DKIM/DMARC: recommended for mail to Gmail/Outlook.com"
Write-Host "- Autodiscover.domain.com should resolve publicly and internally"
Write-Host ""

# 12. Recommendations
Write-Host "==> Suggested Improvements:"
Write-Host "- Ensure only 1 certificate handles SMTP and has modern TLS (SHA-2, not SHA-1)"
Write-Host "- Use same Internal/External URLs for Outlook Anywhere, OWA, ECP if possible"
Write-Host "- Enable MAPI/HTTP for better Outlook connectivity performance"
Write-Host "- Review circular logging: should be disabled unless used for backups"
Write-Host "- Enable DKIM if sending mail to external recipients"
Write-Host ""

Write-Host "=== Exchange Audit Complete ===`n"