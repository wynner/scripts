 <#
Decline WSUS updates when ALL ProductTitles are in a predefined OS list.
- If an update has multiple ProductTitles, every one must be in the list.
- If any ProductTitle is outside the list, the update is skipped.
- Case-insensitive exact string match against ProductTitles.
- Use -DryRun to preview only.
#>

param(
  [string]$WsusServer = "wsus.wynner.ie",
  [switch]$UseSsl,
  [int]$Port = 8530,
  [switch]$DryRun
)

# --- Predefined decline list ---
$DeclineProducts = @(
  'Windows Vista',
  'Windows Server 2008',
  'Windows Embedded Standard 7',
  'Windows 2000',
  'Windows 2003',
  'Windows 2003, Datacenter Edition',
  'Windows XP Embedded',
  'Windows 8',
'Windows 8 Dynamic Update',
'Windows 8 Embedded',
'Windows 8 Language Interface Packs',
'Windows 8 Language Packs',
'Windows 8.1',
'Windows 8.1 Dynamic Update',
'Windows 8.1 Embedded',
'Windows 8.1 Language Interface Packs',
'Windows 8.1 Language Packs'
)

# Normalize to case-insensitive HashSet
$allowed = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
$DeclineProducts | ForEach-Object { [void]$allowed.Add($_.Trim()) }

# --- Load WSUS API ---
try {
  Add-Type -AssemblyName Microsoft.UpdateServices.Administration -ErrorAction Stop
} catch {
  $dll = 'C:\Program Files\Update Services\Api\Microsoft.UpdateServices.Administration.dll'
  if (-not (Test-Path $dll)) {
    throw "WSUS admin DLL not found at $dll — install the WSUS console."
  }
  [void][Reflection.Assembly]::LoadFrom($dll)
}

# --- Connect ---
$wsus = [Microsoft.UpdateServices.Administration.AdminProxy]::GetUpdateServer($WsusServer,[bool]$UseSsl,$Port)

# All non-declined updates
$updates = $wsus.GetUpdates() | Where-Object { -not $_.IsDeclined }

$declined = @()
$skipped  = @()

foreach ($u in $updates) {
  # Prefer ProductTitles property
  $prodTitles = @($u.ProductTitles)
  if (-not $prodTitles -or $prodTitles.Count -eq 0) {
    $prodTitles = @(($u.GetUpdateCategories() | Where-Object { $_.Type -eq 'Product' }).Title)
  }

  if (-not $prodTitles -or $prodTitles.Count -eq 0) {
    $skipped += [pscustomobject]@{
      KB       = ($u.KBArticleNumbers -join ',')
      Title    = $u.Title
      Products = ''
      Reason   = 'No ProductTitles metadata'
    }
    continue
  }

  # SUBSET: all product titles must be in allowed set
  $allInAllowed = $true
  foreach ($p in $prodTitles) {
    if (-not $allowed.Contains($p.Trim())) { $allInAllowed = $false; break }
  }

  if ($allInAllowed) {
    $row = [pscustomobject]@{
      KB        = ($u.KBArticleNumbers -join ',')
      Title     = $u.Title
      Products  = ($prodTitles -join '; ')
      Classes   = $u.UpdateClassificationTitle
    }
    if ($DryRun) {
      $row | Add-Member NoteProperty Action 'Would decline'
      $declined += $row
    } else {
      $u.Decline()
      $row | Add-Member NoteProperty Action 'Declined'
      $declined += $row
    }
  } else {
    $skipped += [pscustomobject]@{
      KB       = ($u.KBArticleNumbers -join ',')
      Title    = $u.Title
      Products = ($prodTitles -join '; ')
      Reason   = 'Contains products outside decline list'
    }
  }
}

Write-Host "---- Summary ----"
Write-Host ("Decline list: {0}" -f (([string[]]$allowed | Sort-Object) -join ', '))
Write-Host ("Declined (or would): {0}" -f $declined.Count)
Write-Host ("Skipped: {0}" -f $skipped.Count)

$declined | Sort-Object Title | Format-Table -AutoSize -Wrap 
