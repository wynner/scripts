# Sanitize RVTools Exports

Author: Ross  
Created: 2026-04-29  
Version: 1.0

`sanitize_rvtools.ps1` is a standalone PowerShell 7 script that sanitizes sensitive values in an RVTools `.xlsx` export and writes a JSON reverse lookup map. The same script can also desanitize a sanitized workbook when given the matching JSON map.

The script is intended to preserve RVTools workbook structure while changing values such as VM names, guest DNS names, ESXi host names, domains, service names, and IPv4 addresses.

## What Gets Sanitized

The script targets common RVTools columns that can contain customer-identifying information:

- VM names
- guest DNS names
- ESXi host names
- domains and DNS search suffixes
- vCenter/API, NTP, gateway, DNS, and other service names or addresses
- IPv4 addresses, while keeping related addresses in equivalent sanitized subnets
- selected free-form paths and messages when they contain already-known sensitive values

The script uses column allow-lists so that unrelated data such as MAC addresses, IDs, versions, build strings, and most arbitrary text is left alone.

## Package Contents

This folder is designed to be copied or shared as a small standalone package:

- `sanitize_rvtools.ps1`
- `README.md`

The script is self-contained and bootstraps the required `ImportExcel` module itself when the module is not already installed.

## Required PowerShell Modules

- **ImportExcel** - opens, edits, and saves RVTools `.xlsx` files.

The script attempts to install `ImportExcel` automatically if it is not present, but new users should install it explicitly before first use.

## Prepare PowerShell

Use PowerShell 7 or later.

### Windows

Open PowerShell 7 and run:

```powershell
Set-ExecutionPolicy -Scope CurrentUser RemoteSigned
Install-PackageProvider -Name NuGet -Scope CurrentUser -Force
Install-Module -Name ImportExcel -Scope CurrentUser -Force
```

### macOS or Linux

Open PowerShell 7 and run:

```powershell
Install-Module -Name ImportExcel -Scope CurrentUser -Force
```

On macOS, `ImportExcel` may warn that autosize support needs `mono-libgdiplus`. The sanitizer does not require autosizing, but the warning can be removed with:

```sh
brew install mono-libgdiplus
```

## Sanitize Usage

Run from the `sanitize-rvtools` folder:

```powershell
pwsh -NoProfile -File ./sanitize_rvtools.ps1 `
  -InputXlsx ./input/RVTools_export.xlsx
```

By default, output files are written beside the source workbook:

- `<source>-sanitized-yyyyMMdd-HHmmss.xlsx`
- `<source>-sanitized-yyyyMMdd-HHmmss-map.json`

Specify output paths when required:

```powershell
pwsh -NoProfile -File ./sanitize_rvtools.ps1 `
  -InputXlsx ./input/RVTools_export.xlsx `
  -OutputXlsx ./output/RVTools_sanitized.xlsx `
  -OutputJson ./output/RVTools_sanitized-map.json
```

Show progress and phase details:

```powershell
pwsh -NoProfile -File ./sanitize_rvtools.ps1 `
  -InputXlsx ./input/RVTools_export.xlsx `
  -ShowProgress
```

For timestamped debug output:

```powershell
pwsh -NoProfile -File ./sanitize_rvtools.ps1 `
  -InputXlsx ./input/RVTools_export.xlsx `
  -DebugProgress
```

## Desanitize Usage

Use `-Desanitize` with the sanitized workbook and the JSON map created during sanitization:

```powershell
pwsh -NoProfile -File ./sanitize_rvtools.ps1 `
  -Desanitize `
  -InputXlsx ./output/RVTools_sanitized.xlsx `
  -MappingJson ./output/RVTools_sanitized-map.json
```

By default, the restored workbook is written beside the sanitized workbook:

- `<sanitized-source>-desanitized-yyyyMMdd-HHmmss.xlsx`

Specify the restored output path when required:

```powershell
pwsh -NoProfile -File ./sanitize_rvtools.ps1 `
  -Desanitize `
  -InputXlsx ./output/RVTools_sanitized.xlsx `
  -MappingJson ./output/RVTools_sanitized-map.json `
  -OutputXlsx ./output/RVTools_restored.xlsx
```

`-OutputJson` is accepted as a compatibility alias for `-MappingJson` in desanitize mode:

```powershell
pwsh -NoProfile -File ./sanitize_rvtools.ps1 `
  -Desanitize `
  -InputXlsx ./output/RVTools_sanitized.xlsx `
  -OutputJson ./output/RVTools_sanitized-map.json
```

## Parameters

| Parameter | Required? | Description |
|-----------|-----------|-------------|
| `-InputXlsx` | Yes | Source workbook. In sanitize mode this is the original RVTools export. In desanitize mode this is the sanitized workbook. |
| `-OutputXlsx` | No | Output workbook path. If omitted, a timestamped file is created beside the input workbook. |
| `-OutputJson` | No | Sanitizer JSON output path. In desanitize mode, this can be used as an alias for `-MappingJson`. |
| `-MappingJson` | Desanitize only | JSON reverse lookup map produced during sanitization. |
| `-Desanitize` | No | Switches the script from sanitize mode to restore mode. |
| `-ShowProgress` | No | Shows a PowerShell progress bar. |
| `-DebugProgress` | No | Shows progress plus timestamped phase/debug messages. |
| `-Quiet` | No | Suppresses final success messages. |

## Notes

- The JSON map contains the original sensitive values. Protect it and do not share it with the sanitized workbook unless the recipient must be able to restore the original values.
- Keep the sanitized `.xlsx` and JSON map together. The JSON map is required to reverse the sanitization.
- Do not use the same path for input and output. The script blocks this to protect the source workbook.
- The script performs a post-save workbook XML repair step to keep the generated `.xlsx` compatible with Excel.
- Desanitization is expected to recreate the original cell text when the sanitized workbook and matching JSON map are used together.
- If you inspect the JSON map directly in PowerShell, use `ConvertFrom-Json -AsHashtable`. RVTools data can include names that differ only by letter casing, which plain `ConvertFrom-Json` cannot represent safely.
