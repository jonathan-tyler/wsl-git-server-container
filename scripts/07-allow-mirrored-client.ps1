#Requires -RunAsAdministrator
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$RemoteAddress,

    [int]$LocalPort = 2222,

    [string]$DisplayName,

    [ValidateSet('Any', 'Domain', 'Private', 'Public', 'NotApplicable')]
    [string]$Profile = 'Private',

    [string]$VMCreatorId = '{40E0AC32-46A5-438A-A0B2-2B479E8F2E90}'
)

$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'

if (-not $DisplayName) {
    $DisplayName = "WSL Git LAN $LocalPort from $RemoteAddress"
}

$existingRule = Get-NetFirewallHyperVRule |
    Where-Object {
        $_.DisplayName -eq $DisplayName -and
        $_.Direction -eq 'Inbound' -and
        $_.VMCreatorId -eq $VMCreatorId
    }

if ($existingRule) {
    Write-Host "Hyper-V firewall rule already exists: $DisplayName"
    return
}

New-NetFirewallHyperVRule `
    -DisplayName $DisplayName `
    -Direction Inbound `
    -VMCreatorId $VMCreatorId `
    -Protocol TCP `
    -LocalPorts $LocalPort `
    -RemoteAddresses $RemoteAddress `
    -Action Allow `
    -Enabled True `
    -Profiles $Profile | Out-Null

Write-Host "Created Hyper-V firewall rule '$DisplayName' for TCP $LocalPort from $RemoteAddress."