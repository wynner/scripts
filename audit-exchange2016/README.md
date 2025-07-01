# Audit-Exchange2016.ps1

This PowerShell script performs a lightweight health and best practices audit of an Exchange Server 2016 environment. It gathers build information, service status, certificate expiry dates, basic mail flow tests and other common checks.

## Required Modules

- **Exchange** – provides the Exchange cmdlets such as `Get-ExchangeServer` and `Get-ExchangeCertificate`.
- **WebAdministration** – used for IIS related inspection.

Both modules are available on Exchange servers and will load automatically when run locally.

## Disclaimer

This script is provided as is without any warranty. I hold no liability for the accuracy of the information produced by this script.
