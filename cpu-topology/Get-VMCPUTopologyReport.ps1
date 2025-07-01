

[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string]$vCenter,
    [System.Management.Automation.PSCredential]$Credential,
    [string]$OutputPath
)

function Highlight-Yellow($text) { "$([char]27)[33m$text$([char]27)[0m" }
function Highlight-Orange($text) { "$([char]27)[38;5;208m$text$([char]27)[0m" }

<#
.SYNOPSIS
    Report VMs with hardware version 20+ that are not set to CPU topology "Assigned on Power On".
.DESCRIPTION
    Connects to the supplied vCenter Server and inspects every virtual machine.
    VMs running virtual hardware version 20 or higher are checked for the CPU
    topology option. Machines that explicitly define a socket/core topology
    (rather than letting vSphere assign topology on power on) are returned.
.PARAMETER vCenter
    The vCenter Server to connect to.
.PARAMETER Credential
    Optional credential for vCenter authentication.
.PARAMETER OutputPath
    Optional path to export the results as CSV.
.EXAMPLE
    ./Get-VMCPUTopologyReport.ps1 -vCenter vcsa.lab.local -Credential (Get-Credential)
#>

Set-StrictMode -Version 3

if (-not ($Host.UI.SupportsVirtualTerminal)) {
    $env:TERM = 'xterm'
}

Import-Module VMware.PowerCLI -ErrorAction Stop
Set-PowerCLIConfiguration -InvalidCertificateAction Ignore -Confirm:$false | Out-Null

if ($Credential) {
    Connect-VIServer -Server $vCenter -Credential $Credential | Out-Null
} else {
    Connect-VIServer -Server $vCenter | Out-Null
}

$vms = Get-View -ViewType VirtualMachine -Property Name,Config,Runtime
Write-Host "Retrieved $($vms.Count) virtual machines."

$results = foreach ($vm in $vms) {
    $hwVersion = ($vm.Config.Version -replace 'vmx-', '') -as [int]
    if ($hwVersion -lt 20) { continue }
    Write-Host "Inspecting VM: $($vm.Name) (HW Version: $hwVersion)"

    $numCpu        = $vm.Config.Hardware.NumCPU
    $coresPerSocket = $vm.Config.Hardware.NumCoresPerSocket

    $latencySensitivity = if ($vm.Config.PSObject.Properties['LatencySensitivity']) {
        $vm.Config.LatencySensitivity.Level
    } else {
        $null
    }

    $cpuReservationMHz = if ($vm.Config.PSObject.Properties['CpuAllocation']) {
        $vm.Config.CpuAllocation.Reservation
    } else {
        $null
    }

    $cpuHotAdd = if ($vm.Config.PSObject.Properties['CpuHotAddEnabled']) {
        [bool]$vm.Config.CpuHotAddEnabled
    } else {
        $null
    }

    # Try to detect if topology is explicitly set
    $sockets = if ($vm.Config.Hardware.PSObject.Properties['NumCpuPackages']) {
        $vm.Config.Hardware.NumCpuPackages
    } elseif ($coresPerSocket -gt 0) {
        [int]($numCpu / $coresPerSocket)
    } else {
        $null
    }

    $topologyAssigned = $vm.Config.Hardware.PSObject.Properties['NumCpuPackages'] -and
                        ($vm.Config.Hardware.NumCpuPackages -ne $null)

    $numaNodes = if ($vm.Config.PSObject.Properties['NumaInfo']) {
        $ni = $vm.Config.NumaInfo
        $mode = if ($ni.AutoCoresPerNumaNode) { 'Auto' } else { 'Manual' }
        if ($vm.Runtime.PowerState -eq 'poweredOn') {
            if ($ni.CoresPerNumaNode -gt 0) {
                "$([int]($numCpu / $ni.CoresPerNumaNode)) ($mode)"
            } else {
                "Unknown ($mode)"
            }
        } else {
            if ($ni.CoresPerNumaNode -gt 0 -and -not $ni.AutoCoresPerNumaNode) {
                "Manual ($([int]($numCpu / $ni.CoresPerNumaNode)))"
            } else {
                'Assigned at power on'
            }
        }
    } else {
        'Unavailable'
    }

    $topologyMode = if ($topologyAssigned) { 'Manual' } else { 'Assigned on Power On' }

    $cpuTopologyAuto = -not $topologyAssigned
    $numaAuto = if ($vm.Config.PSObject.Properties['NumaInfo']) {
        $vm.Config.NumaInfo.AutoCoresPerNumaNode
    } else {
        $true
    }

    $cpuConfigMode = switch ("$cpuTopologyAuto|$numaAuto") {
        'True|True'   { 'Automatic (vCPU & NUMA)' }
        'False|False' { 'Manual (vCPU & NUMA)' }
        'False|True'  { 'Manual (vCPU)' }
        'True|False'  { 'Manual (NUMA)' }
    }

    $memReservationMB = if ($vm.Config.PSObject.Properties['MemoryAllocation']) {
        $vm.Config.MemoryAllocation.Reservation
    } else {
        $null
    }

    [pscustomobject]@{
        'VM Name'               = $vm.Name
        'HW Version'            = $hwVersion
        'CPU & NUMA Config'     = if ($cpuConfigMode -ne 'Automatic (vCPU & NUMA)') { Highlight-Yellow $cpuConfigMode } else { $cpuConfigMode }
        'Power State'           = $vm.Runtime.PowerState
        'Total vCPU'            = $numCpu
        'vCPU Sockets'          = $sockets
        'vCPU per Socket'       = $coresPerSocket
        'NUMA Nodes (boot)'     = if ($numaNodes -notmatch 'Auto|Assigned at power on') { Highlight-Yellow $numaNodes } else { $numaNodes }
        'Latency Sensitivity'   = $latencySensitivity
        'CPU Hot Add Enabled'   = if ($cpuHotAdd) { Highlight-Orange $cpuHotAdd } else { $cpuHotAdd }
        'Memory Hot Add Enabled'= if ($vm.Config.MemoryHotAddEnabled) { Highlight-Orange $vm.Config.MemoryHotAddEnabled } else { $vm.Config.MemoryHotAddEnabled }
        'CPU Reservation MHz'   = $cpuReservationMHz
        'Memory Reservation MB' = $memReservationMB
    }
}

Write-Host "Generated $($results.Count) results for output."

if ($OutputPath) {
    $results | Export-Csv -NoTypeInformation -Path $OutputPath
}

Write-Host "`n=== Powered On VMs ===`n"
$results | Where-Object { $_.'Power State' -eq 'poweredOn' } | Format-Table @{Label='VM Name';Expression={$_.'VM Name'}},
    @{Label='HW Version';Expression={$_.'HW Version'};Align='Right'},
    @{Label='CPU & NUMA Config';Expression={$_.'CPU & NUMA Config'}},
    @{Label='Power State';Expression={$_.'Power State'}},
    @{Label='Total vCPU';Expression={$_.'Total vCPU'};Align='Right'},
    @{Label='vCPU Sockets';Expression={$_.'vCPU Sockets'};Align='Right'},
    @{Label='vCPU per Socket';Expression={$_.'vCPU per Socket'};Align='Right'},
    @{Label='NUMA Nodes (boot)';Expression={$_.'NUMA Nodes (boot)'};Align='Right'},
    @{Label='Latency Sensitivity';Expression={$_.'Latency Sensitivity'}},
    @{Label='CPU Hot Add Enabled';Expression={$_.'CPU Hot Add Enabled'}},
    @{Label='Memory Hot Add Enabled';Expression={$_.'Memory Hot Add Enabled'}},
    @{Label='CPU Reservation MHz';Expression={$_.'CPU Reservation MHz'};Align='Right'},
    @{Label='Memory Reservation MB';Expression={$_.'Memory Reservation MB'};Align='Right'}

Write-Host "`n=== Powered Off VMs ===`n"
$results | Where-Object { $_.'Power State' -eq 'poweredOff' } | Format-Table @{Label='VM Name';Expression={$_.'VM Name'}},
    @{Label='HW Version';Expression={$_.'HW Version'};Align='Right'},
    @{Label='CPU & NUMA Config';Expression={$_.'CPU & NUMA Config'}},
    @{Label='Power State';Expression={$_.'Power State'}},
    @{Label='Total vCPU';Expression={$_.'Total vCPU'};Align='Right'},
    @{Label='vCPU Sockets';Expression={$_.'vCPU Sockets'};Align='Right'},
    @{Label='vCPU per Socket';Expression={$_.'vCPU per Socket'};Align='Right'},
    @{Label='NUMA Nodes (boot)';Expression={$_.'NUMA Nodes (boot)'};Align='Right'},
    @{Label='Latency Sensitivity';Expression={$_.'Latency Sensitivity'}},
    @{Label='CPU Hot Add Enabled';Expression={$_.'CPU Hot Add Enabled'}},
    @{Label='Memory Hot Add Enabled';Expression={$_.'Memory Hot Add Enabled'}},
    @{Label='CPU Reservation MHz';Expression={$_.'CPU Reservation MHz'};Align='Right'},
    @{Label='Memory Reservation MB';Expression={$_.'Memory Reservation MB'};Align='Right'}

Write-Host "`n=== Suspended VMs ===`n"
$results | Where-Object { $_.'Power State' -eq 'suspended' } | Format-Table @{Label='VM Name';Expression={$_.'VM Name'}},
    @{Label='HW Version';Expression={$_.'HW Version'};Align='Right'},
    @{Label='CPU & NUMA Config';Expression={$_.'CPU & NUMA Config'}},
    @{Label='Power State';Expression={$_.'Power State'}},
    @{Label='Total vCPU';Expression={$_.'Total vCPU'};Align='Right'},
    @{Label='vCPU Sockets';Expression={$_.'vCPU Sockets'};Align='Right'},
    @{Label='vCPU per Socket';Expression={$_.'vCPU per Socket'};Align='Right'},
    @{Label='NUMA Nodes (boot)';Expression={$_.'NUMA Nodes (boot)'};Align='Right'},
    @{Label='Latency Sensitivity';Expression={$_.'Latency Sensitivity'}},
    @{Label='CPU Hot Add Enabled';Expression={$_.'CPU Hot Add Enabled'}},
    @{Label='Memory Hot Add Enabled';Expression={$_.'Memory Hot Add Enabled'}},
    @{Label='CPU Reservation MHz';Expression={$_.'CPU Reservation MHz'};Align='Right'},
    @{Label='Memory Reservation MB';Expression={$_.'Memory Reservation MB'};Align='Right'}

Disconnect-VIServer -Server $vCenter -Confirm:$false
