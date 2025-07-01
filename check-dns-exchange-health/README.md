# Check-DNSExchangeHealth.ps1

This script verifies key DNS records for an Exchange Server environment from a Windows host using the `Resolve-DnsName` cmdlet. It tests A, MX, SPF, DKIM, DMARC and Autodiscover records and measures DNS query latency.

## Required Modules

Uses built-in Windows cmdlets only. No additional PowerShell modules are required.

## Disclaimer

This script is provided as is without any warranty. I hold no liability for the accuracy of the information produced by this script.
