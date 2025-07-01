# Check-DNSExchangeHealth-Mac.ps1

A macOS-friendly script that validates common Exchange Server DNS records using the `dig` utility. It checks A, MX, SPF, DKIM and DMARC records along with the Autodiscover host.

## Required Modules

This script does not rely on any PowerShell modules but requires the `dig` command to be available (typically via `bind` utilities on macOS or Linux).

## Disclaimer

This script is provided as is without any warranty. I hold no liability for the accuracy of the information produced by this script.
