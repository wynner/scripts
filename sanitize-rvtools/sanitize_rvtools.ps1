<#
.AUTHOR
Ross

.CREATED
2026-04-29

.VERSION
1.0

.SYNOPSIS
Sanitize sensitive values in an RVTools workbook and write a reverse lookup map.

.PARAMETER ShowProgress
Show a PowerShell progress bar while the workbook is scanned, sanitized, and saved.

.PARAMETER DebugProgress
Show the progress bar plus timestamped phase and worksheet messages.
#>
#Requires -Version 7.0
[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$InputXlsx,
    [string]$OutputXlsx,
    [string]$OutputJson,
    [string]$MappingJson,
    [switch]$Desanitize,
    [switch]$Quiet,
    [switch]$ShowProgress,
    [switch]$DebugProgress
)

Set-StrictMode -Version 3
$ErrorActionPreference = 'Stop'

# Bootstrap the only external dependency. Keeping this here makes the folder
# portable: users do not need the rest of the health-check repository.
function Install-ImportExcel {
    if (Get-Module ImportExcel -ListAvailable) {
        Import-Module ImportExcel -ErrorAction Stop
        return
    }

    if (-not (Get-Command Install-Module -ErrorAction SilentlyContinue)) {
        throw "ImportExcel is not installed and Install-Module is unavailable. Install PowerShellGet, then run: Install-Module ImportExcel -Scope CurrentUser -Force"
    }

    try {
        if ((Get-Command Install-PackageProvider -ErrorAction SilentlyContinue) -and -not (Get-PackageProvider -Name NuGet -ErrorAction SilentlyContinue)) {
            Install-PackageProvider -Name NuGet -Scope CurrentUser -Force -ErrorAction Stop | Out-Null
        }

        Install-Module -Name ImportExcel -Scope CurrentUser -Repository PSGallery -Force -AllowClobber -ErrorAction Stop
    }
    catch {
        throw "Failed to install ImportExcel from PowerShell Gallery. Install it manually with: Install-Module ImportExcel -Scope CurrentUser -Force. Details: $($_.Exception.Message)"
    }

    Import-Module ImportExcel -ErrorAction Stop
}

$null = Install-ImportExcel

# Forward maps are original -> sanitized. Reverse maps are sanitized -> original
# and are written to JSON so a workbook can be desanitized later.
$domainMap       = [System.Collections.Specialized.OrderedDictionary]::new([System.StringComparer]::OrdinalIgnoreCase)
$hostMap         = [System.Collections.Specialized.OrderedDictionary]::new([System.StringComparer]::OrdinalIgnoreCase)
$vmMap           = [System.Collections.Specialized.OrderedDictionary]::new([System.StringComparer]::Ordinal)
$guestDnsMap     = [System.Collections.Specialized.OrderedDictionary]::new([System.StringComparer]::OrdinalIgnoreCase)
$serviceMap      = [System.Collections.Specialized.OrderedDictionary]::new([System.StringComparer]::OrdinalIgnoreCase)
$ipv4Map         = [System.Collections.Specialized.OrderedDictionary]::new([System.StringComparer]::Ordinal)
$subnetMap       = [System.Collections.Specialized.OrderedDictionary]::new([System.StringComparer]::Ordinal)
$subnetState     = [System.Collections.Specialized.OrderedDictionary]::new([System.StringComparer]::Ordinal)

$domainReverse   = [System.Collections.Specialized.OrderedDictionary]::new([System.StringComparer]::OrdinalIgnoreCase)
$hostReverse     = [System.Collections.Specialized.OrderedDictionary]::new([System.StringComparer]::OrdinalIgnoreCase)
$vmReverse       = [System.Collections.Specialized.OrderedDictionary]::new([System.StringComparer]::Ordinal)
$guestDnsReverse = [System.Collections.Specialized.OrderedDictionary]::new([System.StringComparer]::OrdinalIgnoreCase)
$serviceReverse  = [System.Collections.Specialized.OrderedDictionary]::new([System.StringComparer]::OrdinalIgnoreCase)
$ipv4Reverse     = [System.Collections.Specialized.OrderedDictionary]::new([System.StringComparer]::Ordinal)
$subnetReverse   = [System.Collections.Specialized.OrderedDictionary]::new([System.StringComparer]::Ordinal)

$domainCounter   = 1
$hostCounter     = 1
$vmCounter       = 1
$guestDnsCounter = 1
$serviceCounter  = 1
$subnetCounter   = 1

# Column allow-lists keep replacement scoped to RVTools fields that can contain
# sensitive values. This avoids accidental replacements in fields such as MAC
# addresses, IDs, build strings, or other free text that only looks sensitive.
$vmColumnNames         = @('VM')
$vmDnsColumnNames      = @('DNS Name')
$hostColumnNames       = @('Host')
$hostListColumnNames   = @('Hosts')
$domainColumnNames     = @('Domain','Domain List','DNS Search Order')
$serviceColumnNames    = @('VI SDK Server','NTP Server(s)')
$subnetMaskColumnNames = @('Subnet mask')
$ipv4ColumnNames       = @('IP Address','IPv4 Address','Primary IP Address','Gateway','DNS Servers')
$freeformColumnNames   = @('Path','Log directory','Snapshot directory','Suspend directory','Name','Message')
$sensitiveMarkerChars  = [char[]]@('.', '/', '\', ':', '-', '_', '[', ']')

# Reused regexes are compiled once because large RVTools exports can contain
# hundreds of thousands of cells.
$ipv4Regex = [regex]::new('(?<!\d)(?<ip>(?:(?:25[0-5]|2[0-4]\d|1?\d?\d)\.){3}(?:25[0-5]|2[0-4]\d|1?\d?\d))(?!\d)', [System.Text.RegularExpressions.RegexOptions]::Compiled)
$fqdnRegex = [regex]::new('(?<![A-Za-z0-9_&-])(?<name>[A-Za-z0-9_&-]+(?:\.[A-Za-z0-9_&-]+)+\.?)(?![A-Za-z0-9_&-])', [System.Text.RegularExpressions.RegexOptions]::Compiled)
$literalReplacementRegexCache = @{}
$desanitizeReplacementRegexCache = $null

$script:progressActivity = if ($Desanitize) { 'Desanitize RVTools workbook' } else { 'Sanitize RVTools workbook' }
$script:progressStart = Get-Date
$script:progressEnabled = [bool]($ShowProgress -or $DebugProgress)

# Progress helpers. They stay quiet by default so the script can be used in
# batch jobs, but the same code path can show progress/debug detail on demand.
function Write-SanitizeProgress {
    param(
        [Parameter(Mandatory)][string]$Status,
        [double]$PercentComplete = -1,
        [string]$CurrentOperation
    )

    if (-not $script:progressEnabled) { return }

    $progressArgs = @{
        Activity = $script:progressActivity
        Status   = $Status
    }

    if ($PercentComplete -ge 0) {
        $progressArgs.PercentComplete = [Math]::Min(100, [Math]::Max(0, [int][Math]::Round($PercentComplete)))
    }
    if (-not [string]::IsNullOrWhiteSpace($CurrentOperation)) {
        $progressArgs.CurrentOperation = $CurrentOperation
    }

    Write-Progress @progressArgs
}

function Write-SanitizeDebug {
    param([Parameter(Mandatory)][string]$Message)

    if (-not $DebugProgress -or $Quiet) { return }

    $elapsed = (Get-Date) - $script:progressStart
    Write-Host ('[{0:hh\:mm\:ss}] {1}' -f $elapsed, $Message) -ForegroundColor DarkGray
}

function Complete-SanitizeProgress {
    if ($script:progressEnabled) {
        Write-Progress -Activity $script:progressActivity -Completed
    }
}

function Get-WorkbookDataRowCount {
    param([Parameter(Mandatory)][object]$Workbook)

    $count = 0
    foreach ($sheet in $Workbook.Worksheets) {
        if (-not $sheet.Dimension) { continue }
        $count += [Math]::Max(0, $sheet.Dimension.End.Row - $sheet.Dimension.Start.Row)
    }

    return $count
}

# Add both directions at the same time so the JSON map is always reversible.
function Add-SanitizationMapEntry {
    param(
        [Parameter(Mandatory)][System.Collections.Specialized.OrderedDictionary]$ForwardMap,
        [Parameter(Mandatory)][System.Collections.Specialized.OrderedDictionary]$ReverseMap,
        [Parameter(Mandatory)][string]$Original,
        [Parameter(Mandatory)][string]$Sanitized
    )

    if (-not $ForwardMap.Contains($Original)) {
        $ForwardMap[$Original] = $Sanitized
    }
    if (-not $ReverseMap.Contains($Sanitized)) {
        $ReverseMap[$Sanitized] = $Original
    }
}

function Get-TrimmedValue {
    param([AllowNull()][object]$Value)

    if ($null -eq $Value) { return '' }
    return ([string]$Value).Trim()
}

function Get-CanonicalDomain {
    param([AllowNull()][string]$Domain)

    $value = Get-TrimmedValue $Domain
    if ([string]::IsNullOrWhiteSpace($value)) { return '' }
    return $value.Trim('.')
}

function Test-IPv4Address {
    param([AllowNull()][string]$Value)

    $text = Get-TrimmedValue $Value
    if (-not $ipv4Regex.IsMatch($text)) { return $false }
    return [string]::Equals($ipv4Regex.Match($text).Value, $text, [System.StringComparison]::Ordinal)
}

# Treat localdomain as a valid environment domain, but reject version-looking
# strings such as "7.3.1" or "2.2.312-..." by requiring an alphabetic TLD.
function Test-DomainName {
    param([AllowNull()][string]$Value)

    $text = (Get-TrimmedValue $Value).Trim('.')
    if ([string]::IsNullOrWhiteSpace($text)) { return $false }
    if ([string]::Equals($text, 'localdomain', [System.StringComparison]::OrdinalIgnoreCase)) { return $true }
    if (-not $text.Contains('.')) { return $false }
    if (Test-IPv4Address $text) { return $false }

    $labels = @($text.Split('.'))
    if ($labels.Count -lt 2) { return $false }

    $topLevelDomain = $labels[-1]
    if ($topLevelDomain -notmatch '^[A-Za-z][A-Za-z-]{1,23}$') {
        return $false
    }

    foreach ($label in $labels) {
        if ($label -notmatch '^[A-Za-z0-9](?:[A-Za-z0-9-]{0,61}[A-Za-z0-9])?$') {
            return $false
        }
    }

    return $true
}

# Split names into base + domain only when the suffix is actually domain-like.
# This stops VM/template version numbers from being mistaken for domains.
function Get-NameComponents {
    param([AllowNull()][string]$Name)

    $normalized = (Get-TrimmedValue $Name).TrimEnd('.')
    $baseName = $normalized
    $domain = ''

    if (-not [string]::IsNullOrWhiteSpace($normalized) -and -not (Test-IPv4Address $normalized)) {
        $dotIndex = $normalized.IndexOf('.')
        if ($dotIndex -gt 0) {
            $candidateDomain = $normalized.Substring($dotIndex + 1)
            if (Test-DomainName $candidateDomain) {
                $baseName = $normalized.Substring(0, $dotIndex)
                $domain = $candidateDomain
            }
        }
    }

    return [pscustomobject]@{
        Normalized = $normalized
        Base       = $baseName
        Domain     = $domain
    }
}

function Get-SanitizedDomain {
    param([Parameter(Mandatory)][string]$Domain)

    $canonical = Get-CanonicalDomain $Domain
    if ([string]::IsNullOrWhiteSpace($canonical)) {
        return $Domain
    }
    if (-not (Test-DomainName $canonical)) {
        return $Domain
    }

    if (-not $domainMap.Contains($canonical)) {
        $sanitized = 'domain{0}.com' -f $script:domainCounter
        $script:domainCounter++
        Add-SanitizationMapEntry -ForwardMap $domainMap -ReverseMap $domainReverse -Original $canonical -Sanitized $sanitized
    }

    return $domainMap[$canonical]
}

function Get-SanitizedHost {
    param([Parameter(Mandatory)][string]$HostName)

    $parts = Get-NameComponents $HostName
    if ([string]::IsNullOrWhiteSpace($parts.Normalized)) {
        return $HostName
    }

    if ($hostMap.Contains($parts.Normalized)) {
        return $hostMap[$parts.Normalized]
    }

    $baseSanitized = $null
    if (-not [string]::IsNullOrWhiteSpace($parts.Base) -and $hostMap.Contains($parts.Base)) {
        $baseSanitized = $hostMap[$parts.Base]
    }
    else {
        $baseSanitized = 'host{0:0000}' -f $script:hostCounter
        $script:hostCounter++
        Add-SanitizationMapEntry -ForwardMap $hostMap -ReverseMap $hostReverse -Original $parts.Base -Sanitized $baseSanitized
    }

    $sanitized = $baseSanitized
    if (-not [string]::IsNullOrWhiteSpace($parts.Domain)) {
        $sanitized = '{0}.{1}' -f $baseSanitized, (Get-SanitizedDomain $parts.Domain)
    }

    Add-SanitizationMapEntry -ForwardMap $hostMap -ReverseMap $hostReverse -Original $parts.Normalized -Sanitized $sanitized
    return $sanitized
}

function Resolve-SanitizedVmName {
    param([Parameter(Mandatory)][string]$VmName)

    $parts = Get-NameComponents $VmName
    if ([string]::IsNullOrWhiteSpace($parts.Normalized)) {
        return $VmName
    }

    if ($vmMap.Contains($parts.Normalized)) {
        return $vmMap[$parts.Normalized]
    }

    if (-not [string]::IsNullOrWhiteSpace($parts.Domain) -and $vmMap.Contains($parts.Base)) {
        $sanitized = '{0}.{1}' -f $vmMap[$parts.Base], (Get-SanitizedDomain $parts.Domain)
        Add-SanitizationMapEntry -ForwardMap $vmMap -ReverseMap $vmReverse -Original $parts.Normalized -Sanitized $sanitized
        return $sanitized
    }

    return $null
}

function Get-SanitizedVm {
    param([Parameter(Mandatory)][string]$VmName)

    $existing = Resolve-SanitizedVmName $VmName
    if ($existing) { return $existing }

    $parts = Get-NameComponents $VmName
    if ([string]::IsNullOrWhiteSpace($parts.Normalized)) {
        return $VmName
    }

    $baseSanitized = $null
    if (-not [string]::IsNullOrWhiteSpace($parts.Base) -and $vmMap.Contains($parts.Base)) {
        $baseSanitized = $vmMap[$parts.Base]
    }
    else {
        $baseSanitized = 'vm{0:00000}' -f $script:vmCounter
        $script:vmCounter++
        Add-SanitizationMapEntry -ForwardMap $vmMap -ReverseMap $vmReverse -Original $parts.Base -Sanitized $baseSanitized
    }

    $sanitized = $baseSanitized
    if (-not [string]::IsNullOrWhiteSpace($parts.Domain)) {
        $sanitized = '{0}.{1}' -f $baseSanitized, (Get-SanitizedDomain $parts.Domain)
    }

    Add-SanitizationMapEntry -ForwardMap $vmMap -ReverseMap $vmReverse -Original $parts.Normalized -Sanitized $sanitized
    return $sanitized
}

function Resolve-SanitizedGuestDnsName {
    param([Parameter(Mandatory)][string]$DnsName)

    $vmName = Resolve-SanitizedVmName $DnsName
    if ($vmName) { return $vmName }

    $parts = Get-NameComponents $DnsName
    if ([string]::IsNullOrWhiteSpace($parts.Normalized)) {
        return $DnsName
    }

    if ($guestDnsMap.Contains($parts.Normalized)) {
        return $guestDnsMap[$parts.Normalized]
    }

    if (-not [string]::IsNullOrWhiteSpace($parts.Domain) -and $guestDnsMap.Contains($parts.Base)) {
        $sanitized = '{0}.{1}' -f $guestDnsMap[$parts.Base], (Get-SanitizedDomain $parts.Domain)
        Add-SanitizationMapEntry -ForwardMap $guestDnsMap -ReverseMap $guestDnsReverse -Original $parts.Normalized -Sanitized $sanitized
        return $sanitized
    }

    return $null
}

function Get-SanitizedGuestDnsName {
    param([Parameter(Mandatory)][string]$DnsName)

    $existing = Resolve-SanitizedGuestDnsName $DnsName
    if ($existing) { return $existing }

    $parts = Get-NameComponents $DnsName
    if ([string]::IsNullOrWhiteSpace($parts.Normalized)) {
        return $DnsName
    }

    $baseSanitized = $null
    if (-not [string]::IsNullOrWhiteSpace($parts.Base) -and $guestDnsMap.Contains($parts.Base)) {
        $baseSanitized = $guestDnsMap[$parts.Base]
    }
    else {
        $baseSanitized = 'vmhost{0:00000}' -f $script:guestDnsCounter
        $script:guestDnsCounter++
        Add-SanitizationMapEntry -ForwardMap $guestDnsMap -ReverseMap $guestDnsReverse -Original $parts.Base -Sanitized $baseSanitized
    }

    $sanitized = $baseSanitized
    if (-not [string]::IsNullOrWhiteSpace($parts.Domain)) {
        $sanitized = '{0}.{1}' -f $baseSanitized, (Get-SanitizedDomain $parts.Domain)
    }

    Add-SanitizationMapEntry -ForwardMap $guestDnsMap -ReverseMap $guestDnsReverse -Original $parts.Normalized -Sanitized $sanitized
    return $sanitized
}

function Get-SanitizedServiceName {
    param([Parameter(Mandatory)][string]$Name)

    $vmName = Resolve-SanitizedVmName $Name
    if ($vmName) { return $vmName }

    $guestName = Resolve-SanitizedGuestDnsName $Name
    if ($guestName) { return $guestName }

    $parts = Get-NameComponents $Name
    if ([string]::IsNullOrWhiteSpace($parts.Normalized)) {
        return $Name
    }

    if ($hostMap.Contains($parts.Normalized)) {
        return $hostMap[$parts.Normalized]
    }

    if ($serviceMap.Contains($parts.Normalized)) {
        return $serviceMap[$parts.Normalized]
    }

    $serviceBase = 'service{0:000}' -f $script:serviceCounter
    $script:serviceCounter++

    $sanitized = $serviceBase
    if (-not [string]::IsNullOrWhiteSpace($parts.Domain)) {
        $sanitized = '{0}.{1}' -f $serviceBase, (Get-SanitizedDomain $parts.Domain)
    }

    Add-SanitizationMapEntry -ForwardMap $serviceMap -ReverseMap $serviceReverse -Original $parts.Normalized -Sanitized $sanitized
    return $sanitized
}

# IPv4 handling keeps addresses in equivalent sanitized subnets. For example,
# a gateway and VMkernel address from the same original subnet remain together
# after sanitization so downstream health checks still make sense.
function ConvertTo-IPv4UInt32 {
    param([Parameter(Mandatory)][string]$IpAddress)

    if (-not (Test-IPv4Address $IpAddress)) {
        throw "Invalid IPv4 address '$IpAddress'."
    }

    $octets = $IpAddress.Split('.') | ForEach-Object { [uint32]$_ }
    return [uint32](
        (($octets[0] -shl 24) -bor
         ($octets[1] -shl 16) -bor
         ($octets[2] -shl 8)  -bor
          $octets[3])
    )
}

function ConvertFrom-IPv4UInt32 {
    param([Parameter(Mandatory)][uint32]$Value)

    return '{0}.{1}.{2}.{3}' -f (($Value -shr 24) -band 255),
                                (($Value -shr 16) -band 255),
                                (($Value -shr 8) -band 255),
                                ($Value -band 255)
}

function Get-PrefixLengthFromMask {
    param([Parameter(Mandatory)][string]$SubnetMask)

    if (-not (Test-IPv4Address $SubnetMask)) { return $null }

    $maskInt = ConvertTo-IPv4UInt32 $SubnetMask
    $bits = [Convert]::ToString([int64]$maskInt, 2).PadLeft(32, '0')
    if ($bits -notmatch '^1*0*$') { return $null }

    $zeroIndex = $bits.IndexOf('0')
    if ($zeroIndex -lt 0) { return 32 }
    return $zeroIndex
}

function Register-IPv4Subnet {
    param(
        [Parameter(Mandatory)][string]$IpAddress,
        [Parameter(Mandatory)][string]$SubnetMask
    )

    $prefixLength = Get-PrefixLengthFromMask $SubnetMask
    if ($null -eq $prefixLength) { return $null }

    $ipInt = ConvertTo-IPv4UInt32 $IpAddress
    $maskInt = ConvertTo-IPv4UInt32 $SubnetMask
    $networkInt = [uint32]($ipInt -band $maskInt)
    $network = ConvertFrom-IPv4UInt32 $networkInt
    $subnetKey = '{0}/{1}' -f $network, $prefixLength

    if ($subnetState.Contains($subnetKey)) {
        return $subnetState[$subnetKey]
    }

    $hostBitCount = 32 - $prefixLength
    $blockSize = [uint64]1 -shl $hostBitCount
    $baseInt = [uint64](ConvertTo-IPv4UInt32 '100.0.0.0')
    $maxInt = [uint64](ConvertTo-IPv4UInt32 '100.255.255.255')

    if ($prefixLength -lt 8) {
        $sanitizedNetworkInt64 = $baseInt
    }
    else {
        # Allocate sanitized networks inside 100.0.0.0/8 while preserving host bits.
        $sanitizedNetworkInt64 = $baseInt + ([uint64]$script:subnetCounter * $blockSize)
        $script:subnetCounter++
    }

    if ($sanitizedNetworkInt64 -gt $maxInt) {
        throw "Unable to allocate sanitized subnet for '$subnetKey' inside 100.0.0.0/8."
    }

    $sanitizedNetworkInt = [uint32]$sanitizedNetworkInt64
    $sanitizedNetwork = ConvertFrom-IPv4UInt32 $sanitizedNetworkInt
    $sanitizedSubnet = '{0}/{1}' -f $sanitizedNetwork, $prefixLength
    $hostMask = [uint32]([uint32]::MaxValue - $maskInt)

    $state = [pscustomobject]@{
        OriginalSubnet      = $subnetKey
        SanitizedSubnet     = $sanitizedSubnet
        OriginalNetworkInt  = $networkInt
        SanitizedNetworkInt = $sanitizedNetworkInt
        PrefixLength        = $prefixLength
        MaskInt             = $maskInt
        HostMask            = $hostMask
    }

    $subnetState[$subnetKey] = $state
    Add-SanitizationMapEntry -ForwardMap $subnetMap -ReverseMap $subnetReverse -Original $subnetKey -Sanitized $sanitizedSubnet
    return $state
}

# When a cell contains an IP without a local subnet mask, use the most specific
# subnet already discovered elsewhere in the workbook.
function Find-RegisteredIPv4Subnet {
    param([Parameter(Mandatory)][string]$IpAddress)

    if (-not (Test-IPv4Address $IpAddress)) { return $null }

    $ipInt = ConvertTo-IPv4UInt32 $IpAddress
    $bestState = $null

    foreach ($key in $subnetState.Keys) {
        $state = $subnetState[$key]
        if (($ipInt -band $state.MaskInt) -eq $state.OriginalNetworkInt) {
            if (-not $bestState -or $state.PrefixLength -gt $bestState.PrefixLength) {
                $bestState = $state
            }
        }
    }

    return $bestState
}

function Get-SanitizedIPv4Address {
    param(
        [Parameter(Mandatory)][string]$IpAddress,
        [string]$SubnetMask
    )

    $normalized = Get-TrimmedValue $IpAddress
    if (-not (Test-IPv4Address $normalized)) {
        return $IpAddress
    }

    if ($ipv4Map.Contains($normalized)) {
        return $ipv4Map[$normalized]
    }

    $state = $null
    if (-not [string]::IsNullOrWhiteSpace($SubnetMask)) {
        $state = Register-IPv4Subnet -IpAddress $normalized -SubnetMask $SubnetMask
    }
    if (-not $state) {
        $state = Find-RegisteredIPv4Subnet -IpAddress $normalized
    }
    if (-not $state) {
        $octets = $normalized.Split('.')
        $state = Register-IPv4Subnet -IpAddress ('{0}.{1}.{2}.0' -f $octets[0], $octets[1], $octets[2]) -SubnetMask '255.255.255.0'
    }

    $ipInt = ConvertTo-IPv4UInt32 $normalized
    $hostBits = [uint32]($ipInt -band $state.HostMask)
    $sanitizedInt = [uint32]($state.SanitizedNetworkInt -bor $hostBits)
    $sanitized = ConvertFrom-IPv4UInt32 $sanitizedInt

    Add-SanitizationMapEntry -ForwardMap $ipv4Map -ReverseMap $ipv4Reverse -Original $normalized -Sanitized $sanitized
    return $sanitized
}

function Convert-IPv4AddressesInText {
    param(
        [Parameter(Mandatory)][string]$Value,
        [string]$SubnetMask,
        [switch]$AllowUnknown
    )

    return $ipv4Regex.Replace($Value, {
        param($match)
        $ip = $match.Groups['ip'].Value
        if (-not $AllowUnknown -and -not $ipv4Map.Contains($ip) -and -not (Find-RegisteredIPv4Subnet -IpAddress $ip)) {
            return $ip
        }
        Get-SanitizedIPv4Address -IpAddress $ip -SubnetMask $SubnetMask
    })
}

# Lightweight worksheet helpers used by both discovery and mutation passes.
function Get-HeaderMap {
    param([Parameter(Mandatory)][object]$Worksheet)

    $headers = @{}
    if (-not $Worksheet.Dimension) { return $headers }

    $headerRow = $Worksheet.Dimension.Start.Row
    for ($col = $Worksheet.Dimension.Start.Column; $col -le $Worksheet.Dimension.End.Column; $col++) {
        $headers[$col] = Get-TrimmedValue $Worksheet.Cells[$headerRow, $col].Text
    }

    return $headers
}

function Get-WorksheetByName {
    param(
        [Parameter(Mandatory)][object]$Workbook,
        [Parameter(Mandatory)][string]$Name
    )

    foreach ($sheet in $Workbook.Worksheets) {
        if ([string]::Equals($sheet.Name, $Name, [System.StringComparison]::OrdinalIgnoreCase)) {
            return $sheet
        }
    }

    return $null
}

function Get-ColumnsByHeader {
    param(
        [Parameter(Mandatory)][hashtable]$Headers,
        [Parameter(Mandatory)][string[]]$Names
    )

    $columns = @()
    foreach ($entry in $Headers.GetEnumerator()) {
        foreach ($name in $Names) {
            if ([string]::Equals($entry.Value, $name, [System.StringComparison]::OrdinalIgnoreCase)) {
                $columns += [int]$entry.Key
                break
            }
        }
    }
    return ,@($columns | Sort-Object)
}

function Split-ListValue {
    param([AllowNull()][string]$Value)

    $text = Get-TrimmedValue $Value
    if ([string]::IsNullOrWhiteSpace($text)) { return @() }
    return @($text -split '\s*[,;]\s*' | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
}

# FQDN replacement is context-aware. Freeform text only uses domains we already
# know, while explicit domain/service columns are allowed to create mappings.
function Resolve-FqdnToken {
    param(
        [Parameter(Mandatory)][string]$Token,
        [ValidateSet('Freeform','Service','Domain')][string]$Context = 'Freeform'
    )

    $trailingDot = if ($Token.EndsWith('.')) { '.' } else { '' }
    $core = $Token.TrimEnd('.')

    if ([string]::IsNullOrWhiteSpace($core)) { return $Token }
    if (Test-IPv4Address $core) { return "$core$trailingDot" }

    if ($vmMap.Contains($core)) {
        return "$($vmMap[$core])$trailingDot"
    }

    if ($guestDnsMap.Contains($core)) {
        return "$($guestDnsMap[$core])$trailingDot"
    }

    if ($hostMap.Contains($core)) {
        return "$($hostMap[$core])$trailingDot"
    }

    if ($serviceMap.Contains($core)) {
        return "$($serviceMap[$core])$trailingDot"
    }

    $canonicalDomain = Get-CanonicalDomain $core
    if ($domainMap.Contains($canonicalDomain)) {
        return "$($domainMap[$canonicalDomain])$trailingDot"
    }

    if (-not (Test-DomainName $core)) {
        return $Token
    }

    $parts = Get-NameComponents $core
    $domainKnown = (
        -not [string]::IsNullOrWhiteSpace($parts.Domain) -and
        $domainMap.Contains((Get-CanonicalDomain $parts.Domain))
    )

    if ($domainKnown) {
        if ($vmMap.Contains($parts.Base)) {
            $sanitizedVmFqdn = '{0}.{1}' -f $vmMap[$parts.Base], (Get-SanitizedDomain $parts.Domain)
            Add-SanitizationMapEntry -ForwardMap $vmMap -ReverseMap $vmReverse -Original $parts.Normalized -Sanitized $sanitizedVmFqdn
            return "$sanitizedVmFqdn$trailingDot"
        }
        if ($guestDnsMap.Contains($parts.Base)) {
            $sanitizedGuestFqdn = '{0}.{1}' -f $guestDnsMap[$parts.Base], (Get-SanitizedDomain $parts.Domain)
            Add-SanitizationMapEntry -ForwardMap $guestDnsMap -ReverseMap $guestDnsReverse -Original $parts.Normalized -Sanitized $sanitizedGuestFqdn
            return "$sanitizedGuestFqdn$trailingDot"
        }
    }

    if ($Context -eq 'Domain') {
        return "{0}{1}" -f (Get-SanitizedDomain $core), $trailingDot
    }

    if ($Context -eq 'Freeform' -and -not $domainKnown) {
        return $Token
    }

    return "{0}{1}" -f (Get-SanitizedServiceName $core), $trailingDot
}

function Convert-FqdnTokensInText {
    param(
        [Parameter(Mandatory)][string]$Value,
        [ValidateSet('Freeform','Service','Domain')][string]$Context = 'Freeform'
    )

    return $fqdnRegex.Replace($Value, {
        param($match)
        Resolve-FqdnToken -Token $match.Groups['name'].Value -Context $Context
    })
}

function Test-PotentialFreeformSensitiveText {
    param([Parameter(Mandatory)][string]$Value)

    if ($Value.IndexOfAny($sensitiveMarkerChars) -ge 0) { return $true }
    if ($Value.IndexOf(' ') -ge 0 -or $Value.IndexOf("`t") -ge 0) { return $true }

    $trimmed = $Value.Trim()
    if ($hostMap.Contains($trimmed) -or $vmMap.Contains($trimmed) -or $guestDnsMap.Contains($trimmed)) {
        return $true
    }

    return $false
}

# Build one literal regex per map instead of doing one replace per key per cell.
# Longest keys are tried first so "vm00123.domain1.com" wins over "vm00123".
function Replace-LiteralMapValues {
    param(
        [Parameter(Mandatory)][string]$Value,
        [Parameter(Mandatory)][System.Collections.Specialized.OrderedDictionary]$Map,
        [System.Text.RegularExpressions.RegexOptions]$Options = [System.Text.RegularExpressions.RegexOptions]::None,
        [switch]$IncludeDottedKeys
    )

    if ($Map.Count -eq 0) { return $Value }

    $cacheKey = '{0}:{1}:{2}' -f $Map.GetHashCode(), [int]$Options, [bool]$IncludeDottedKeys
    $cacheEntry = if ($literalReplacementRegexCache.ContainsKey($cacheKey)) { $literalReplacementRegexCache[$cacheKey] } else { $null }

    if (-not $cacheEntry -or $cacheEntry.MapCount -ne $Map.Count) {
        $keys = @(
            $Map.Keys |
            Where-Object {
                -not [string]::IsNullOrWhiteSpace([string]$_) -and
                ($IncludeDottedKeys -or -not ([string]$_).Contains('.')) -and
                ([string]$_).Length -ge 2
            } |
            Sort-Object Length -Descending
        )

        if ($keys.Count -eq 0) {
            $cacheEntry = [pscustomobject]@{
                MapCount = $Map.Count
                Regex    = $null
            }
        }
        else {
            $alternation = ($keys | ForEach-Object { [System.Text.RegularExpressions.Regex]::Escape([string]$_) }) -join '|'
            $pattern = '(?<![A-Za-z0-9])(?<key>{0})(?![A-Za-z0-9])' -f $alternation
            $regexOptions = $Options -bor [System.Text.RegularExpressions.RegexOptions]::Compiled
            $cacheEntry = [pscustomobject]@{
                MapCount = $Map.Count
                Regex    = [regex]::new($pattern, $regexOptions)
            }
        }

        $literalReplacementRegexCache[$cacheKey] = $cacheEntry
        Write-SanitizeDebug ("Built literal replacement regex with {0} keys." -f $keys.Count)
    }

    if (-not $cacheEntry.Regex) {
        return $Value
    }

    return $cacheEntry.Regex.Replace($Value, [System.Text.RegularExpressions.MatchEvaluator]{
        param([System.Text.RegularExpressions.Match]$match)

        $key = $match.Groups['key'].Value
        if ($Map.Contains($key)) {
            return [string]$Map[$key]
        }

        return $match.Value
    })
}

function Convert-FreeformText {
    param(
        [Parameter(Mandatory)][string]$Value,
        [string]$SubnetMask
    )

    if (-not (Test-PotentialFreeformSensitiveText $Value)) {
        return $Value
    }

    $result = Convert-IPv4AddressesInText -Value $Value -SubnetMask $SubnetMask
    $result = Convert-FqdnTokensInText -Value $result -Context Freeform
    $result = Replace-LiteralMapValues -Value $result -Map $hostMap -Options ([System.Text.RegularExpressions.RegexOptions]::IgnoreCase) -IncludeDottedKeys
    $result = Replace-LiteralMapValues -Value $result -Map $vmMap -IncludeDottedKeys
    $result = Replace-LiteralMapValues -Value $result -Map $guestDnsMap -Options ([System.Text.RegularExpressions.RegexOptions]::IgnoreCase) -IncludeDottedKeys
    return $result
}

function Convert-DomainValue {
    param([Parameter(Mandatory)][string]$Value)

    $result = Convert-FqdnTokensInText -Value $Value -Context Domain
    foreach ($item in (Split-ListValue $Value)) {
        if (Test-DomainName $item) {
            $sanitized = Get-SanitizedDomain $item
            $pattern = '(?<![A-Za-z0-9.-]){0}(?![A-Za-z0-9.-])' -f [System.Text.RegularExpressions.Regex]::Escape($item.Trim('.'))
            $result = [System.Text.RegularExpressions.Regex]::Replace($result, $pattern, $sanitized, [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)
        }
    }
    return $result
}

function Convert-ServiceValue {
    param(
        [Parameter(Mandatory)][string]$Value,
        [string]$SubnetMask
    )

    $result = Convert-IPv4AddressesInText -Value $Value -SubnetMask $SubnetMask -AllowUnknown
    return Convert-FqdnTokensInText -Value $result -Context Service
}

# Central dispatch for a cell. Known sensitive columns get targeted handling;
# unknown columns are left alone to reduce false positives.
function Convert-CellText {
    param(
        [Parameter(Mandatory)][string]$Value,
        [string]$Header,
        [string]$SubnetMask
    )

    if ([string]::IsNullOrWhiteSpace($Value)) { return $Value }

    foreach ($subnetHeader in $subnetMaskColumnNames) {
        if ([string]::Equals($Header, $subnetHeader, [System.StringComparison]::OrdinalIgnoreCase)) {
            return $Value
        }
    }

    foreach ($ipHeader in $ipv4ColumnNames) {
        if ([string]::Equals($Header, $ipHeader, [System.StringComparison]::OrdinalIgnoreCase)) {
            return Convert-IPv4AddressesInText -Value $Value -SubnetMask $SubnetMask -AllowUnknown
        }
    }

    foreach ($vmHeader in $vmColumnNames) {
        if ([string]::Equals($Header, $vmHeader, [System.StringComparison]::OrdinalIgnoreCase)) {
            return Get-SanitizedVm $Value
        }
    }

    foreach ($dnsHeader in $vmDnsColumnNames) {
        if ([string]::Equals($Header, $dnsHeader, [System.StringComparison]::OrdinalIgnoreCase)) {
            if (Test-IPv4Address $Value) {
                return Get-SanitizedIPv4Address $Value
            }
            return Get-SanitizedGuestDnsName $Value
        }
    }

    foreach ($hostHeader in $hostColumnNames) {
        if ([string]::Equals($Header, $hostHeader, [System.StringComparison]::OrdinalIgnoreCase)) {
            return Get-SanitizedHost $Value
        }
    }

    foreach ($hostListHeader in $hostListColumnNames) {
        if ([string]::Equals($Header, $hostListHeader, [System.StringComparison]::OrdinalIgnoreCase)) {
            return Convert-FreeformText -Value $Value -SubnetMask $SubnetMask
        }
    }

    foreach ($domainHeader in $domainColumnNames) {
        if ([string]::Equals($Header, $domainHeader, [System.StringComparison]::OrdinalIgnoreCase)) {
            return Convert-DomainValue $Value
        }
    }

    foreach ($serviceHeader in $serviceColumnNames) {
        if ([string]::Equals($Header, $serviceHeader, [System.StringComparison]::OrdinalIgnoreCase)) {
            return Convert-ServiceValue -Value $Value -SubnetMask $SubnetMask
        }
    }

    foreach ($freeformHeader in $freeformColumnNames) {
        if ([string]::Equals($Header, $freeformHeader, [System.StringComparison]::OrdinalIgnoreCase)) {
            return Convert-FreeformText -Value $Value -SubnetMask $SubnetMask
        }
    }

    return $Value
}

# First pass: discover subnet relationships before mutating any IP address.
# This lets gateways, DNS servers, and interface addresses land in matching
# sanitized networks later.
function Initialize-IPv4Subnets {
    param([Parameter(Mandatory)][object]$Workbook)

    Write-SanitizeProgress -Status 'Discovering IPv4 subnets' -PercentComplete 5
    Write-SanitizeDebug 'Discovering IPv4 subnet relationships.'

    $totalRows = [Math]::Max(1, (Get-WorkbookDataRowCount -Workbook $Workbook))
    $processedRows = 0

    foreach ($sheet in $Workbook.Worksheets) {
        if (-not $sheet.Dimension) { continue }

        $sheetRows = [Math]::Max(0, $sheet.Dimension.End.Row - $sheet.Dimension.Start.Row)

        $headers = Get-HeaderMap -Worksheet $sheet
        $maskColumns = Get-ColumnsByHeader -Headers $headers -Names $subnetMaskColumnNames
        if ($maskColumns.Count -eq 0) {
            $processedRows += $sheetRows
            continue
        }

        $candidateColumns = Get-ColumnsByHeader -Headers $headers -Names @('IP Address','IPv4 Address','Primary IP Address','Gateway','DNS Servers')
        if ($candidateColumns.Count -eq 0) {
            $processedRows += $sheetRows
            continue
        }

        Write-SanitizeDebug ("IPv4 scan: worksheet '{0}' ({1} rows)." -f $sheet.Name, $sheetRows)

        for ($row = $sheet.Dimension.Start.Row + 1; $row -le $sheet.Dimension.End.Row; $row++) {
            foreach ($maskCol in $maskColumns) {
                $mask = Get-TrimmedValue $sheet.Cells[$row, $maskCol].Text
                if ([string]::IsNullOrWhiteSpace($mask)) { continue }

                foreach ($ipCol in $candidateColumns) {
                    $value = Get-TrimmedValue $sheet.Cells[$row, $ipCol].Text
                    if ([string]::IsNullOrWhiteSpace($value)) { continue }

                    foreach ($match in $ipv4Regex.Matches($value)) {
                        [void](Register-IPv4Subnet -IpAddress $match.Groups['ip'].Value -SubnetMask $mask)
                    }
                }
            }

            $processedRows++
            if (($processedRows % 200) -eq 0 -or $row -eq $sheet.Dimension.End.Row) {
                $percent = 5 + (10 * ($processedRows / $totalRows))
                Write-SanitizeProgress -Status 'Discovering IPv4 subnets' -PercentComplete $percent -CurrentOperation $sheet.Name
            }
        }
    }

    Write-SanitizeProgress -Status 'Discovered IPv4 subnets' -PercentComplete 15
    Write-SanitizeDebug ("Discovered {0} IPv4 subnet map(s)." -f $subnetReverse.Count)
}

# Second pass: build stable name maps. Doing this before cell mutation ensures
# the same VM, host, or domain gets the same sanitized value on every worksheet.
function Initialize-SensitiveNameMaps {
    param([Parameter(Mandatory)][object]$Workbook)

    Write-SanitizeProgress -Status 'Discovering sensitive names' -PercentComplete 15
    Write-SanitizeDebug 'Discovering VM, host, domain, DNS, and service names.'

    foreach ($sheetName in @('vInfo')) {
        $sheet = Get-WorksheetByName -Workbook $Workbook -Name $sheetName
        if (-not $sheet -or -not $sheet.Dimension) { continue }

        Write-SanitizeDebug ("Name scan: worksheet '{0}' VM and DNS columns." -f $sheet.Name)

        $headers = Get-HeaderMap -Worksheet $sheet
        foreach ($vmCol in (Get-ColumnsByHeader -Headers $headers -Names $vmColumnNames)) {
            for ($row = $sheet.Dimension.Start.Row + 1; $row -le $sheet.Dimension.End.Row; $row++) {
                $value = Get-TrimmedValue $sheet.Cells[$row, $vmCol].Text
                if (-not [string]::IsNullOrWhiteSpace($value)) {
                    [void](Get-SanitizedVm $value)
                }
            }
        }

        foreach ($dnsCol in (Get-ColumnsByHeader -Headers $headers -Names $vmDnsColumnNames)) {
            for ($row = $sheet.Dimension.Start.Row + 1; $row -le $sheet.Dimension.End.Row; $row++) {
                $value = Get-TrimmedValue $sheet.Cells[$row, $dnsCol].Text
                if (-not [string]::IsNullOrWhiteSpace($value) -and -not (Test-IPv4Address $value)) {
                    [void](Get-SanitizedGuestDnsName $value)
                }
            }
        }
    }

    Write-SanitizeProgress -Status 'Discovered VM and guest DNS names' -PercentComplete 19

    foreach ($sheetName in @('vHost')) {
        $sheet = Get-WorksheetByName -Workbook $Workbook -Name $sheetName
        if (-not $sheet -or -not $sheet.Dimension) { continue }

        Write-SanitizeDebug ("Name scan: worksheet '{0}' host columns." -f $sheet.Name)

        $headers = Get-HeaderMap -Worksheet $sheet
        foreach ($hostCol in (Get-ColumnsByHeader -Headers $headers -Names $hostColumnNames)) {
            for ($row = $sheet.Dimension.Start.Row + 1; $row -le $sheet.Dimension.End.Row; $row++) {
                $value = Get-TrimmedValue $sheet.Cells[$row, $hostCol].Text
                if (-not [string]::IsNullOrWhiteSpace($value)) {
                    [void](Get-SanitizedHost $value)
                }
            }
        }
    }

    Write-SanitizeProgress -Status 'Discovered host names' -PercentComplete 21

    $sheetCount = [Math]::Max(1, $Workbook.Worksheets.Count)
    $sheetIndex = 0

    foreach ($sheet in $Workbook.Worksheets) {
        $sheetIndex++
        if (-not $sheet.Dimension) { continue }

        Write-SanitizeDebug ("Name scan: worksheet '{0}' ({1}/{2})." -f $sheet.Name, $sheetIndex, $sheetCount)

        $headers = Get-HeaderMap -Worksheet $sheet

        foreach ($vmCol in (Get-ColumnsByHeader -Headers $headers -Names $vmColumnNames)) {
            for ($row = $sheet.Dimension.Start.Row + 1; $row -le $sheet.Dimension.End.Row; $row++) {
                $value = Get-TrimmedValue $sheet.Cells[$row, $vmCol].Text
                if (-not [string]::IsNullOrWhiteSpace($value)) {
                    [void](Get-SanitizedVm $value)
                }
            }
        }

        foreach ($hostCol in (Get-ColumnsByHeader -Headers $headers -Names $hostColumnNames)) {
            for ($row = $sheet.Dimension.Start.Row + 1; $row -le $sheet.Dimension.End.Row; $row++) {
                $value = Get-TrimmedValue $sheet.Cells[$row, $hostCol].Text
                if (-not [string]::IsNullOrWhiteSpace($value)) {
                    [void](Get-SanitizedHost $value)
                }
            }
        }

        foreach ($hostListCol in (Get-ColumnsByHeader -Headers $headers -Names $hostListColumnNames)) {
            for ($row = $sheet.Dimension.Start.Row + 1; $row -le $sheet.Dimension.End.Row; $row++) {
                foreach ($hostName in (Split-ListValue $sheet.Cells[$row, $hostListCol].Text)) {
                    [void](Get-SanitizedHost $hostName)
                }
            }
        }

        foreach ($dnsCol in (Get-ColumnsByHeader -Headers $headers -Names $vmDnsColumnNames)) {
            for ($row = $sheet.Dimension.Start.Row + 1; $row -le $sheet.Dimension.End.Row; $row++) {
                $value = Get-TrimmedValue $sheet.Cells[$row, $dnsCol].Text
                if (-not [string]::IsNullOrWhiteSpace($value) -and -not (Test-IPv4Address $value)) {
                    [void](Get-SanitizedGuestDnsName $value)
                }
            }
        }

        foreach ($domainCol in (Get-ColumnsByHeader -Headers $headers -Names $domainColumnNames)) {
            for ($row = $sheet.Dimension.Start.Row + 1; $row -le $sheet.Dimension.End.Row; $row++) {
                foreach ($domain in (Split-ListValue $sheet.Cells[$row, $domainCol].Text)) {
                    if (Test-DomainName $domain) {
                        [void](Get-SanitizedDomain $domain)
                    }
                }
            }
        }

        foreach ($serviceCol in (Get-ColumnsByHeader -Headers $headers -Names $serviceColumnNames)) {
            for ($row = $sheet.Dimension.Start.Row + 1; $row -le $sheet.Dimension.End.Row; $row++) {
                $value = Get-TrimmedValue $sheet.Cells[$row, $serviceCol].Text
                if ([string]::IsNullOrWhiteSpace($value)) { continue }
                foreach ($match in $fqdnRegex.Matches($value)) {
                    $token = $match.Groups['name'].Value.TrimEnd('.')
                    if (Test-DomainName $token) {
                        [void](Get-SanitizedServiceName $token)
                    }
                }
            }
        }

        $percent = 21 + (9 * ($sheetIndex / $sheetCount))
        Write-SanitizeProgress -Status 'Discovering sensitive names' -PercentComplete $percent -CurrentOperation $sheet.Name
    }

    Write-SanitizeProgress -Status 'Discovered sensitive names' -PercentComplete 30
    Write-SanitizeDebug ("Discovered {0} VM, {1} host, {2} domain, and {3} guest DNS mapping(s)." -f $vmReverse.Count, $hostReverse.Count, $domainReverse.Count, $guestDnsReverse.Count)
}

# Mutation pass: write sanitized values back into the workbook copy.
function Invoke-WorkbookSanitization {
    param([Parameter(Mandatory)][object]$Workbook)

    Write-SanitizeProgress -Status 'Sanitizing workbook cells' -PercentComplete 30
    Write-SanitizeDebug 'Sanitizing workbook cells.'

    $totalRows = [Math]::Max(1, (Get-WorkbookDataRowCount -Workbook $Workbook))
    $processedRows = 0

    foreach ($sheet in $Workbook.Worksheets) {
        if (-not $sheet.Dimension) { continue }

        $sheetRows = [Math]::Max(0, $sheet.Dimension.End.Row - $sheet.Dimension.Start.Row)
        $sheetCols = $sheet.Dimension.End.Column - $sheet.Dimension.Start.Column + 1
        Write-SanitizeDebug ("Sanitizing worksheet '{0}' ({1} rows x {2} columns)." -f $sheet.Name, $sheetRows, $sheetCols)

        $headers = Get-HeaderMap -Worksheet $sheet
        $maskColumns = Get-ColumnsByHeader -Headers $headers -Names $subnetMaskColumnNames

        for ($row = $sheet.Dimension.Start.Row + 1; $row -le $sheet.Dimension.End.Row; $row++) {
            $rowSubnetMask = $null
            foreach ($maskCol in $maskColumns) {
                $maskValue = Get-TrimmedValue $sheet.Cells[$row, $maskCol].Text
                if (-not [string]::IsNullOrWhiteSpace($maskValue)) {
                    $rowSubnetMask = $maskValue
                    break
                }
            }

            for ($col = $sheet.Dimension.Start.Column; $col -le $sheet.Dimension.End.Column; $col++) {
                $cell = $sheet.Cells[$row, $col]
                if (-not $cell) { continue }
                if (-not [string]::IsNullOrWhiteSpace($cell.Formula)) { continue }
                $rawValue = $cell.Value
                if ($null -eq $rawValue) { continue }

                if (-not ($rawValue -is [string])) { continue }

                $original = [string]$rawValue
                if ([string]::IsNullOrWhiteSpace($original)) { continue }

                $header = if ($headers.ContainsKey($col)) { $headers[$col] } else { '' }
                $sanitized = Convert-CellText -Value $original -Header $header -SubnetMask $rowSubnetMask

                if ($sanitized -ne $original) {
                    $cell.Value = $sanitized
                }
            }

            $processedRows++
            if (($processedRows % 200) -eq 0 -or $row -eq $sheet.Dimension.End.Row) {
                $percent = 30 + (55 * ($processedRows / $totalRows))
                Write-SanitizeProgress -Status 'Sanitizing workbook cells' -PercentComplete $percent -CurrentOperation ("{0} row {1}/{2}" -f $sheet.Name, ($row - $sheet.Dimension.Start.Row), $sheetRows)
            }
        }
    }

    Write-SanitizeProgress -Status 'Sanitized workbook cells' -PercentComplete 85
    Write-SanitizeDebug 'Finished sanitizing workbook cells.'
}

# Mapping JSON stores both directions. ReverseLookup is used for desanitization;
# ForwardLookup is useful for auditing what changed.
function New-MappingDocument {
    param(
        [Parameter(Mandatory)][string]$SourceWorkbook,
        [Parameter(Mandatory)][string]$SanitizedWorkbook
    )

    return [ordered]@{
        Version = 2
        SourceWorkbook = $SourceWorkbook
        SanitizedWorkbook = $SanitizedWorkbook
        ReverseLookup = [ordered]@{
            Domains       = $domainReverse
            Hosts         = $hostReverse
            VMs           = $vmReverse
            GuestDnsNames = $guestDnsReverse
            Services      = $serviceReverse
            IPv4Addresses = $ipv4Reverse
            IPv4Subnets   = $subnetReverse
        }
        ForwardLookup = [ordered]@{
            Domains       = $domainMap
            Hosts         = $hostMap
            VMs           = $vmMap
            GuestDnsNames = $guestDnsMap
            Services      = $serviceMap
            IPv4Addresses = $ipv4Map
            IPv4Subnets   = $subnetMap
        }
    }
}

# Desanitization reads the JSON written by this script and turns the reverse
# lookup sections into one replacement map.
function Import-MappingDocument {
    param([Parameter(Mandatory)][string]$Path)

    if (-not (Test-Path -LiteralPath $Path)) {
        throw "Mapping JSON '$Path' was not found."
    }

    $mapping = Get-Content -LiteralPath $Path -Raw | ConvertFrom-Json -AsHashtable
    if (-not $mapping.ContainsKey('ReverseLookup')) {
        throw "Mapping JSON '$Path' does not contain a ReverseLookup section."
    }

    return $mapping
}

function New-DesanitizeReplacementMap {
    param([Parameter(Mandatory)][hashtable]$Mapping)

    $replacementMap = [System.Collections.Specialized.OrderedDictionary]::new([System.StringComparer]::OrdinalIgnoreCase)
    $reverseLookup = $Mapping['ReverseLookup']
    $categoryNames = @('VMs','GuestDnsNames','Hosts','Services','Domains','IPv4Addresses','IPv4Subnets')

    foreach ($categoryName in $categoryNames) {
        if (-not $reverseLookup.ContainsKey($categoryName)) { continue }

        foreach ($entry in $reverseLookup[$categoryName].GetEnumerator()) {
            $sanitized = [string]$entry.Key
            $original = [string]$entry.Value
            if ([string]::IsNullOrWhiteSpace($sanitized)) { continue }
            if (-not $replacementMap.Contains($sanitized)) {
                $replacementMap[$sanitized] = $original
            }
        }
    }

    return $replacementMap
}

# Reverse replacement is intentionally broad. The JSON map contains exact
# sanitized tokens, so this pass can safely restore text in any string cell.
function Convert-DesanitizedText {
    param(
        [Parameter(Mandatory)][string]$Value,
        [Parameter(Mandatory)][System.Collections.Specialized.OrderedDictionary]$ReplacementMap
    )

    if ($ReplacementMap.Count -eq 0) { return $Value }

    if (-not $script:desanitizeReplacementRegexCache -or $script:desanitizeReplacementRegexCache.MapCount -ne $ReplacementMap.Count) {
        $keys = @(
            $ReplacementMap.Keys |
            Where-Object { -not [string]::IsNullOrWhiteSpace([string]$_) } |
            Sort-Object Length -Descending
        )

        $alternation = ($keys | ForEach-Object { [System.Text.RegularExpressions.Regex]::Escape([string]$_) }) -join '|'
        $pattern = '(?<![A-Za-z0-9])(?<key>{0})(?![A-Za-z0-9])' -f $alternation
        $script:desanitizeReplacementRegexCache = [pscustomobject]@{
            MapCount = $ReplacementMap.Count
            Regex    = [regex]::new($pattern, [System.Text.RegularExpressions.RegexOptions]::Compiled -bor [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)
        }
        Write-SanitizeDebug ("Built desanitization regex with {0} keys." -f $keys.Count)
    }

    return $script:desanitizeReplacementRegexCache.Regex.Replace($Value, [System.Text.RegularExpressions.MatchEvaluator]{
        param([System.Text.RegularExpressions.Match]$match)

        $key = $match.Groups['key'].Value
        if ($ReplacementMap.Contains($key)) {
            return [string]$ReplacementMap[$key]
        }

        return $match.Value
    })
}

function Invoke-WorkbookDesanitization {
    param(
        [Parameter(Mandatory)][object]$Workbook,
        [Parameter(Mandatory)][System.Collections.Specialized.OrderedDictionary]$ReplacementMap
    )

    Write-SanitizeProgress -Status 'Restoring workbook cells' -PercentComplete 20
    Write-SanitizeDebug ("Restoring workbook cells with {0} replacement key(s)." -f $ReplacementMap.Count)

    $totalRows = [Math]::Max(1, (Get-WorkbookDataRowCount -Workbook $Workbook))
    $processedRows = 0
    $changedCells = 0

    foreach ($sheet in $Workbook.Worksheets) {
        if (-not $sheet.Dimension) { continue }

        $sheetRows = [Math]::Max(0, $sheet.Dimension.End.Row - $sheet.Dimension.Start.Row)
        Write-SanitizeDebug ("Desanitizing worksheet '{0}' ({1} rows)." -f $sheet.Name, $sheetRows)

        for ($row = $sheet.Dimension.Start.Row + 1; $row -le $sheet.Dimension.End.Row; $row++) {
            for ($col = $sheet.Dimension.Start.Column; $col -le $sheet.Dimension.End.Column; $col++) {
                $cell = $sheet.Cells[$row, $col]
                if (-not $cell) { continue }
                if (-not [string]::IsNullOrWhiteSpace($cell.Formula)) { continue }

                $rawValue = $cell.Value
                if ($null -eq $rawValue -or -not ($rawValue -is [string])) { continue }

                $original = [string]$rawValue
                if ([string]::IsNullOrWhiteSpace($original)) { continue }

                $restored = Convert-DesanitizedText -Value $original -ReplacementMap $ReplacementMap
                if ($restored -ne $original) {
                    $cell.Value = $restored
                    $changedCells++
                }
            }

            $processedRows++
            if (($processedRows % 200) -eq 0 -or $row -eq $sheet.Dimension.End.Row) {
                $percent = 20 + (65 * ($processedRows / $totalRows))
                Write-SanitizeProgress -Status 'Restoring workbook cells' -PercentComplete $percent -CurrentOperation ("{0} row {1}/{2}" -f $sheet.Name, ($row - $sheet.Dimension.Start.Row), $sheetRows)
            }
        }
    }

    Write-SanitizeProgress -Status 'Restored workbook cells' -PercentComplete 85
    Write-SanitizeDebug ("Finished restoring workbook cells. Changed {0} cell(s)." -f $changedCells)
    return $changedCells
}

# EPPlus can preserve/write worksheet XML in a form that Excel repairs badly
# for RVTools files. This post-save step keeps the XLSX package Excel-friendly.
function Repair-WorksheetXml {
    param([Parameter(Mandatory)][string]$XlsxPath)

    Add-Type -AssemblyName System.IO.Compression
    Add-Type -AssemblyName System.IO.Compression.FileSystem

    $spreadsheetNamespace = 'http://schemas.openxmlformats.org/spreadsheetml/2006/main'
    $worksheetRootPattern = '<(?<prefix>[A-Za-z_][\w.-]*):worksheet\b(?<attrs>[^>]*)>'
    $sheetDataOpenPattern = '<(?:[A-Za-z_][\w.-]*:)?sheetData\b[^>]*(?:/>|>)'
    $repairs = [System.Collections.Generic.List[object]]::new()
    $zip = [System.IO.Compression.ZipFile]::Open($XlsxPath, [System.IO.Compression.ZipArchiveMode]::Update)

    try {
        foreach ($entry in @($zip.Entries | Where-Object { $_.FullName -like 'xl/worksheets/*.xml' })) {
            $reader = [System.IO.StreamReader]::new($entry.Open(), [System.Text.Encoding]::UTF8, $true)
            try {
                $xmlText = $reader.ReadToEnd()
            }
            finally {
                $reader.Dispose()
            }

            $namespaceAdded = $false
            $rootMatch = [regex]::Match($xmlText, $worksheetRootPattern)
            if ($rootMatch.Success -and $rootMatch.Value -notmatch '\sxmlns=') {
                $xmlText = $xmlText.Insert(
                    $rootMatch.Index + $rootMatch.Value.Length - 1,
                    (' xmlns="{0}"' -f $spreadsheetNamespace)
                )
                $namespaceAdded = $true
            }

            $matches = @([regex]::Matches($xmlText, $sheetDataOpenPattern))
            if ($matches.Count -le 1 -and -not $namespaceAdded) { continue }

            $selfClosingMatches = @($matches | Where-Object { $_.Value.TrimEnd().EndsWith('/>', [System.StringComparison]::Ordinal) })
            $removeMatches = @()
            if ($matches.Count -gt 1 -and $selfClosingMatches.Count -gt 0) {
                $hasPopulatedSheetData = $matches.Count -gt $selfClosingMatches.Count
                $removeMatches = @(
                    if ($hasPopulatedSheetData) {
                        $selfClosingMatches
                    }
                    else {
                        $selfClosingMatches | Select-Object -Skip 1
                    }
                )
            }

            $repairedText = $xmlText
            if ($removeMatches.Count -gt 0) {
                $builder = [System.Text.StringBuilder]::new($xmlText)
                foreach ($match in @($removeMatches | Sort-Object Index -Descending)) {
                    [void]$builder.Remove($match.Index, $match.Length)
                }
                $repairedText = $builder.ToString()
            }

            $repairs.Add([pscustomobject]@{
                EntryName      = $entry.FullName
                LastWriteTime  = $entry.LastWriteTime
                Text           = $repairedText
                NamespaceAdded = $namespaceAdded
                RemovedCount   = $removeMatches.Count
            }) | Out-Null
        }

        foreach ($repair in $repairs) {
            $entry = $zip.GetEntry($repair.EntryName)
            if ($entry) {
                $entry.Delete()
            }

            $newEntry = $zip.CreateEntry($repair.EntryName, [System.IO.Compression.CompressionLevel]::Optimal)
            $newEntry.LastWriteTime = $repair.LastWriteTime
            $writer = [System.IO.StreamWriter]::new($newEntry.Open(), [System.Text.UTF8Encoding]::new($false))
            try {
                $writer.Write($repair.Text)
            }
            finally {
                $writer.Dispose()
            }
        }
    }
    finally {
        $zip.Dispose()
    }

    $removedCount = 0
    $namespaceCount = 0
    foreach ($repair in $repairs) {
        $removedCount += $repair.RemovedCount
        if ($repair.NamespaceAdded) {
            $namespaceCount++
        }
    }

    return [pscustomobject]@{
        WorksheetCount             = $repairs.Count
        AddedDefaultNamespaceCount = $namespaceCount
        RemovedSheetDataCount      = $removedCount
    }
}

# Default outputs are timestamped and collision-safe so users can run the tool
# repeatedly without overwriting source or previous output files.
function Get-UniqueOutputPath {
    param(
        [Parameter(Mandatory)][string]$Directory,
        [Parameter(Mandatory)][string]$BaseName,
        [Parameter(Mandatory)][string]$Extension
    )

    $candidate = Join-Path -Path $Directory -ChildPath ('{0}{1}' -f $BaseName, $Extension)
    if (-not (Test-Path -LiteralPath $candidate)) {
        return $candidate
    }

    for ($counter = 1; $counter -lt 1000; $counter++) {
        $candidate = Join-Path -Path $Directory -ChildPath ('{0}-{1:000}{2}' -f $BaseName, $counter, $Extension)
        if (-not (Test-Path -LiteralPath $candidate)) {
            return $candidate
        }
    }

    throw "Unable to find a unique output path in '$Directory' for '$BaseName$Extension'."
}

# Command-line entry point starts here. The script has two modes:
# sanitize an original RVTools workbook, or desanitize a workbook using JSON.
$inputItem = Get-Item -LiteralPath $InputXlsx -ErrorAction Stop
if ($inputItem.PSIsContainer) {
    throw "Input path '$InputXlsx' points to a directory. Provide an RVTools .xlsx file."
}

$inputFull = $inputItem.FullName
$defaultStamp = Get-Date -Format 'yyyyMMdd-HHmmss'

# Desanitize mode: copy the sanitized workbook, restore every mapped token, save,
# then repair the XLSX XML so Excel opens the result without repairs.
if ($Desanitize) {
    if ([string]::IsNullOrWhiteSpace($MappingJson)) {
        $MappingJson = $OutputJson
    }
    if ([string]::IsNullOrWhiteSpace($MappingJson)) {
        throw "Desanitize mode requires -MappingJson pointing to the sanitizer JSON map. -OutputJson is also accepted as a compatibility alias."
    }

    if ([string]::IsNullOrWhiteSpace($OutputXlsx)) {
        $OutputXlsx = Get-UniqueOutputPath -Directory $inputItem.DirectoryName -BaseName ('{0}-desanitized-{1}' -f $inputItem.BaseName, $defaultStamp) -Extension $inputItem.Extension
    }

    $outputFull = [System.IO.Path]::GetFullPath($OutputXlsx)
    $mappingFull = [System.IO.Path]::GetFullPath($MappingJson)

    if ([string]::Equals($inputFull, $outputFull, [System.StringComparison]::OrdinalIgnoreCase)) {
        throw "Input and output paths must be different to preserve the sanitized workbook."
    }

    $outputDir = Split-Path -Path $outputFull -Parent
    if ($outputDir -and -not (Test-Path -LiteralPath $outputDir)) {
        New-Item -ItemType Directory -Path $outputDir -Force | Out-Null
    }

    if (Test-Path -LiteralPath $outputFull) {
        Remove-Item -LiteralPath $outputFull -Force
    }

    Write-SanitizeProgress -Status 'Reading mapping JSON' -PercentComplete 0 -CurrentOperation $mappingFull
    Write-SanitizeDebug "Reading mapping JSON '$mappingFull'."
    $mappingDocument = Import-MappingDocument -Path $mappingFull
    $replacementMap = New-DesanitizeReplacementMap -Mapping $mappingDocument

    Write-SanitizeProgress -Status 'Copying sanitized workbook' -PercentComplete 5 -CurrentOperation $outputFull
    Write-SanitizeDebug "Copying sanitized workbook '$inputFull' to '$outputFull'."
    Copy-Item -LiteralPath $inputFull -Destination $outputFull -Force

    Write-SanitizeProgress -Status 'Opening workbook copy' -PercentComplete 10 -CurrentOperation $outputFull
    Write-SanitizeDebug "Opening workbook copy '$outputFull'."

    $pkg = $null
    $changedCells = 0
    try {
        $pkg = Open-ExcelPackage -Path $outputFull
        if (-not $pkg.Workbook) {
            throw "Failed to load workbook from '$outputFull'."
        }

        Write-SanitizeDebug ("Workbook loaded: {0} worksheet(s), {1} data row(s)." -f $pkg.Workbook.Worksheets.Count, (Get-WorkbookDataRowCount -Workbook $pkg.Workbook))
        $changedCells = Invoke-WorkbookDesanitization -Workbook $pkg.Workbook -ReplacementMap $replacementMap

        Write-SanitizeProgress -Status 'Saving restored workbook' -PercentComplete 85 -CurrentOperation $outputFull
        Write-SanitizeDebug "Saving restored workbook '$outputFull'."
        $pkg.Save()
    }
    finally {
        if ($pkg) {
            Close-ExcelPackage -NoSave $pkg
        }
    }

    Write-SanitizeProgress -Status 'Repairing workbook XML' -PercentComplete 90 -CurrentOperation $outputFull
    Write-SanitizeDebug "Repairing worksheet XML namespaces and duplicate sheetData nodes in '$outputFull'."
    $repairResult = Repair-WorksheetXml -XlsxPath $outputFull
    if ($repairResult.WorksheetCount -gt 0) {
        Write-SanitizeDebug ("Repaired {0} worksheet XML file(s): added {1} default namespace declaration(s), removed {2} duplicate sheetData node(s)." -f $repairResult.WorksheetCount, $repairResult.AddedDefaultNamespaceCount, $repairResult.RemovedSheetDataCount)
    }

    Write-SanitizeProgress -Status 'Desanitization complete' -PercentComplete 100
    Write-SanitizeDebug 'Desanitization completed.'
    Complete-SanitizeProgress

    if (-not $Quiet) {
        Write-Host "Desanitization complete. Output saved to '$outputFull'." -ForegroundColor Green
        Write-Host ("Restored {0} cell(s) using mapping '$mappingFull'." -f $changedCells) -ForegroundColor Green
    }

    return
}

# Sanitize mode: copy the source workbook first so the original file is never
# modified, then build maps, mutate the copy, and write the reverse lookup JSON.
if ([string]::IsNullOrWhiteSpace($OutputXlsx)) {
    $OutputXlsx = Get-UniqueOutputPath -Directory $inputItem.DirectoryName -BaseName ('{0}-sanitized-{1}' -f $inputItem.BaseName, $defaultStamp) -Extension $inputItem.Extension
}
if ([string]::IsNullOrWhiteSpace($OutputJson)) {
    $OutputJson = Get-UniqueOutputPath -Directory $inputItem.DirectoryName -BaseName ('{0}-sanitized-{1}-map' -f $inputItem.BaseName, $defaultStamp) -Extension '.json'
}

$outputFull = [System.IO.Path]::GetFullPath($OutputXlsx)
$jsonFull = [System.IO.Path]::GetFullPath($OutputJson)

if ([string]::Equals($inputFull, $outputFull, [System.StringComparison]::OrdinalIgnoreCase)) {
    throw "Input and output paths must be different to preserve the original workbook."
}

$outputDir = Split-Path -Path $outputFull -Parent
if ($outputDir -and -not (Test-Path -LiteralPath $outputDir)) {
    New-Item -ItemType Directory -Path $outputDir -Force | Out-Null
}

$jsonDir = Split-Path -Path $jsonFull -Parent
if ($jsonDir -and -not (Test-Path -LiteralPath $jsonDir)) {
    New-Item -ItemType Directory -Path $jsonDir -Force | Out-Null
}

if (Test-Path -LiteralPath $outputFull) {
    Remove-Item -LiteralPath $outputFull -Force
}

Write-SanitizeProgress -Status 'Copying source workbook' -PercentComplete 0 -CurrentOperation $outputFull
Write-SanitizeDebug "Copying source workbook '$inputFull' to '$outputFull'."
Copy-Item -LiteralPath $inputFull -Destination $outputFull -Force

Write-SanitizeProgress -Status 'Opening workbook copy' -PercentComplete 0 -CurrentOperation $outputFull
Write-SanitizeDebug "Opening workbook copy '$outputFull'."

$pkg = $null
$mapping = $null
try {
    $pkg = Open-ExcelPackage -Path $outputFull
    if (-not $pkg.Workbook) {
        throw "Failed to load workbook from '$outputFull'."
    }

    Write-SanitizeDebug ("Workbook loaded: {0} worksheet(s), {1} data row(s)." -f $pkg.Workbook.Worksheets.Count, (Get-WorkbookDataRowCount -Workbook $pkg.Workbook))

    Initialize-IPv4Subnets -Workbook $pkg.Workbook
    Initialize-SensitiveNameMaps -Workbook $pkg.Workbook
    Invoke-WorkbookSanitization -Workbook $pkg.Workbook

    Write-SanitizeProgress -Status 'Saving sanitized workbook' -PercentComplete 85 -CurrentOperation $outputFull
    Write-SanitizeDebug "Saving sanitized workbook '$outputFull'."
    $pkg.Save()

    $mapping = New-MappingDocument -SourceWorkbook $inputFull -SanitizedWorkbook $outputFull
}
finally {
    if ($pkg) {
        Close-ExcelPackage -NoSave $pkg
    }
}

Write-SanitizeProgress -Status 'Repairing workbook XML' -PercentComplete 90 -CurrentOperation $outputFull
Write-SanitizeDebug "Repairing worksheet XML namespaces and duplicate sheetData nodes in '$outputFull'."
$repairResult = Repair-WorksheetXml -XlsxPath $outputFull
if ($repairResult.WorksheetCount -gt 0) {
    Write-SanitizeDebug ("Repaired {0} worksheet XML file(s): added {1} default namespace declaration(s), removed {2} duplicate sheetData node(s)." -f $repairResult.WorksheetCount, $repairResult.AddedDefaultNamespaceCount, $repairResult.RemovedSheetDataCount)
}

Write-SanitizeProgress -Status 'Writing mapping JSON' -PercentComplete 95 -CurrentOperation $jsonFull
Write-SanitizeDebug "Writing mapping JSON '$jsonFull'."
$mapping | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $jsonFull -Encoding UTF8

Write-SanitizeProgress -Status 'Sanitization complete' -PercentComplete 100
Write-SanitizeDebug 'Sanitization completed.'
Complete-SanitizeProgress

if (-not $Quiet) {
    Write-Host "Sanitization complete. Output saved to '$outputFull'." -ForegroundColor Green
    Write-Host "Mapping JSON written to '$jsonFull'." -ForegroundColor Green
    Write-Host "Protect the mapping JSON. It contains the original sensitive values needed for desanitization." -ForegroundColor Yellow
    Write-Host ("Mappings: {0} VMs, {1} hosts, {2} domains, {3} IPv4 addresses." -f $vmReverse.Count, $hostReverse.Count, $domainReverse.Count, $ipv4Reverse.Count) -ForegroundColor Green
}
