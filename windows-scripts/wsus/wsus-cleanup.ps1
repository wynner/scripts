 <#
  WSUS decliner with robust DLL discovery, dry-run support, and -SupersededOnly.
  Run in Windows PowerShell 5.1 (x64).
#>

param(
  [string]$ServerName = "$($env:COMPUTERNAME).$($env:USERDNSDOMAIN)",
  [int]$Port = 8530,
  [bool]$UseSsl = $false,
  [switch]$WhatIf,
  [switch]$DryRun,
  [string]$WsusToolsPath,
  [string]$WsusServerForDll,
  [switch]$SupersededOnly
)

# --- Env guards ---
if ($PSVersionTable.PSEdition -ne 'Desktop' -or $PSVersionTable.PSVersion.Major -ne 5) { throw 'Run in Windows PowerShell 5.1 (x64).' }
if (-not [Environment]::Is64BitProcess) { throw 'Run the 64-bit Windows PowerShell host.' }

# --- Load WSUS Admin API ---
function Load-WsusAssembly {
  param([string]$ExplicitToolsPath,[string]$PreferredServer)
  if ([Type]::GetType('Microsoft.UpdateServices.Administration.AdminProxy', $false)) { return }
  try { Add-Type -AssemblyName Microsoft.UpdateServices.Administration -ErrorAction Stop; return } catch {}
  $candidateDlls = @()
  if ($ExplicitToolsPath) { $candidateDlls += (Join-Path $ExplicitToolsPath 'Microsoft.UpdateServices.Administration.dll') }
  try {
    $regTools = (Get-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\Update Services\Server\Setup' -ErrorAction Stop).ToolsPath
    if ($regTools) { $candidateDlls += (Join-Path $regTools 'Microsoft.UpdateServices.Administration.dll') }
  } catch {}
  foreach ($p in @('C:\Program Files\Update Services\Tools','C:\Program Files (x86)\Update Services\Tools','C:\Program Files\Update Services\AdministrationSnapin\bin')) {
    $candidateDlls += (Join-Path $p 'Microsoft.UpdateServices.Administration.dll')
  }
  if ($PreferredServer) {
    foreach ($rp in @(
      "\\$PreferredServer\C$\Program Files\Update Services\Tools",
      "\\$PreferredServer\C$\Program Files (x86)\Update Services\Tools",
      "\\$PreferredServer\C$\Program Files\Update Services\AdministrationSnapin\bin"
    )) { $candidateDlls += (Join-Path $rp 'Microsoft.UpdateServices.Administration.dll') }
  }
  $gacRoot = 'C:\Windows\Microsoft.NET\assembly\GAC_MSIL\Microsoft.UpdateServices.Administration'
  if (Test-Path $gacRoot) {
    $gacHit = Get-ChildItem -Path $gacRoot -Recurse -Filter 'Microsoft.UpdateServices.Administration.dll' -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($gacHit) { $candidateDlls += $gacHit.FullName }
  }
  $dll = $candidateDlls | Where-Object { $_ -and (Test-Path $_) } | Select-Object -First 1
  if (-not $dll) { throw "Could not locate Microsoft.UpdateServices.Administration.dll. Use -WsusToolsPath / -WsusServerForDll or install the tools." }
  Add-Type -Path $dll
}
Load-WsusAssembly -ExplicitToolsPath $WsusToolsPath -PreferredServer $WsusServerForDll

# --- Connect ---
try {
  $wsus = [Microsoft.UpdateServices.Administration.AdminProxy]::GetUpdateServer($ServerName, $UseSsl, $Port)
} catch {
  throw ("Failed to connect to WSUS at {0}:{1} (SSL={2}). {3}" -f $ServerName, $Port, $UseSsl, $_.Exception.Message)
}
Write-Host ("Connected to WSUS: {0}:{1} (SSL={2})" -f $ServerName, $Port, $UseSsl) -ForegroundColor Yellow

# --- Scope (no IsSuperseded on UpdateScope) ---
$scope = New-Object Microsoft.UpdateServices.Administration.UpdateScope
$scope.ApprovedStates = [Microsoft.UpdateServices.Administration.ApprovedStates]::NotApproved

# --- Fetch updates, exclude declined, then (optionally) keep superseded only ---
$updates = $wsus.GetUpdates($scope) | Where-Object { -not $_.IsDeclined }
if ($SupersededOnly) {
  $updates = $updates | Where-Object { $_.IsSuperseded }
}

# --- When NOT SupersededOnly, optional extra logic (kept minimal here) ---
$classTitlesToDecline = @('Language Packs') #'Upgrades','Language Packs','Feature Packs')
$titleDropPatterns = @('*Itanium*')#,'*IA64*')
$titleDropPatterns += '*Security Only*'  # comment out if you *use* Security-Only model
$titleDropPatterns += '*Language*Pack*'  # comment out if you *use* Security-Only model
$titleDropPatterns += '*Language*Interface*Pack*'  # comment out if you *use* Security-Only model
$titleDropPatterns += '*Language*Feature*'  # comment out if you *use* Security-Only model

function Test-InTargetClass {
  param([Microsoft.UpdateServices.Administration.IUpdate]$Update)
  $classes = $Update.UpdateClassifications
  if (-not $classes) { return $false }
  foreach ($c in $classes) { if ($classTitlesToDecline -contains $c.Title) { return $true } }
  return $false
}
function Test-TitleMatch {
  param([string]$Title)
  foreach ($p in $titleDropPatterns) { if ($Title -like $p) { return $true } }
  return $false
}

function Get-DeclineReason {
  param([Microsoft.UpdateServices.Administration.IUpdate]$Update)
  if ($Update.IsSuperseded) { return 'Superseded by a newer update' }
  $classes = $Update.UpdateClassifications
  if ($classes) {
    foreach ($c in $classes) {
      if ($classTitlesToDecline -contains $c.Title) {
        switch ($c.Title) {
          'Upgrades'        { return 'Upgrade/feature update (managed elsewhere)' }
          'Language Packs'  { return 'Language pack not required' }
          'Feature Packs'   { return 'Feature on Demand / feature pack not required' }
          default           { return ("Classification '{0}'" -f $c.Title) }
        }
      }
    }
  }
  foreach ($p in $titleDropPatterns) {
    if ($Update.Title -like $p) {
      switch ($p) {
        '*Itanium*'       { return 'Itanium/IA64 not targeted' }
        '*IA64*'          { return 'Itanium/IA64 not targeted' }
        '*Security Only*' { return 'Using Monthly Rollup model (drop Security-Only)' }
        default           { return ("Title matches pattern '{0}'" -f $p) }
      }
    }
  }
  return $null
}

# --- Process ---
$declined = 0
$errors   = New-Object System.Collections.Generic.List[object]

foreach ($u in $updates) {
  try {
    $shouldDecline = $false
    if ($SupersededOnly) {
      $shouldDecline = [bool]$u.IsSuperseded                    # ONLY superseded
    } else {
      $shouldDecline = $u.IsSuperseded -or (Test-InTargetClass $u) -or (Test-TitleMatch $u.Title)
    }

    if ($shouldDecline) {
      $reason = Get-DeclineReason -Update $u
      if ($WhatIf -or $DryRun) {
        Write-Host "[DRY-RUN] Would decline: $($u.Title) — Reason: $reason"
      } else {
        $u.Decline()
        $declined++
        Write-Host "Declined: $($u.Title) — Reason: $reason"
      }
    }
  } catch {
    $errors.Add($_)
    Write-Warning "Failed on: $($u.Title) -> $($_.Exception.Message)"
  }
}

Write-Host "Total declined: $declined"
if ($errors.Count) { Write-Warning ("Errors encountered: {0}" -f $errors.Count) } 
