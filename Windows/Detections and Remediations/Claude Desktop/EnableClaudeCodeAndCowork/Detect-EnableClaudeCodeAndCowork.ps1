<#
    .SYNOPSIS
        Detection script that checks whether Claude Cowork and Claude Code are enabled.

    .DESCRIPTION
        Confirms Claude Desktop is installed, then checks HKLM:\SOFTWARE\Policies\Claude for
        secureVmFeaturesEnabled and isClaudeCodeForDesktopEnabled. Returns non-compliant if either
        value is missing, set to 0, or the policy path does not exist. Pairs with the matching
        remediation script.

    .NOTES
        Author:   Bryan Moses
        Version:  v1.0
        Released: 2026-06-09

        Deployment (Microsoft Intune):
            Script type:  Remediation (detection script)
            Assigned to:  Approved device group

        Recommended script settings:
            - Run this script using the logged-on credentials : No
            - Enforce script signature check                  : No
            - Run script in 64-bit PowerShell host            : Yes

        Exit codes:
            0 - Compliant (no remediation needed)
            1 - Non-compliant (triggers the remediation script)
#>

#### Logging Variables ####
$Script:ScriptName = "Detect-EnableClaudeCodeAndCowork"
$Script:LogFile = "$ScriptName.log"
$Script:LogsFolder = "$env:ProgramData\Microsoft\IntuneManagementExtension\Logs"

#### Script Variables ####
$ErrorActionPreference = [System.Management.Automation.ActionPreference]::SilentlyContinue
$Host.UI.RawUI.WindowTitle = '$ScriptName'

$RegPath = "HKLM:\SOFTWARE\Policies\Claude"

# Required policy state (1 = enabled)
$RequiredPolicies = @{
    "secureVmFeaturesEnabled"       = 1  # 1 = Cowork enabled
    "isClaudeCodeForDesktopEnabled" = 1  # 1 = Claude Code enabled
}

#### Functions ####
function Start-Logging {
    Start-Transcript -Path $LogsFolder\$LogFile -Append
    Write-Host "Current script timestamp: $(Get-Date -f yyyy-MM-dd_HH-mm)"
}

#### Script ####
Start-Logging

# Pre-check: Is Claude Desktop installed?
$ClaudeInstalled = $false

try {
    $AppxPackage = Get-AppxPackage -AllUsers -Name "*Claude*" -ErrorAction SilentlyContinue
    if ($AppxPackage) { $ClaudeInstalled = $true }
}
catch {}

if (-not $ClaudeInstalled) {
    try {
        $Provisioned = Get-AppxProvisionedPackage -Online -ErrorAction SilentlyContinue |
            Where-Object { $_.DisplayName -like "*Claude*" }
        if ($Provisioned) { $ClaudeInstalled = $true }
    }
    catch {}
}

if (-not $ClaudeInstalled) {
    $CommonPaths = @(
        "$env:ProgramFiles\Claude\Claude.exe",
        "$env:LOCALAPPDATA\Programs\Claude\Claude.exe",
        "$env:LOCALAPPDATA\AnthropicPBC\Claude\Claude.exe"
    )
    foreach ($Path in $CommonPaths) {
        if (Test-Path $Path) {
            $ClaudeInstalled = $true
            break
        }
    }
}

if (-not $ClaudeInstalled) {
    Write-Output "COMPLIANT: Claude Desktop is not installed."
    Stop-Transcript
    Exit 0
}

$NonCompliant = $false
$Details = @()

if (-not (Test-Path $RegPath)) {
    Write-Output "NON-COMPLIANT: Registry path $RegPath does not exist."
    Stop-Transcript
    Exit 1
}

foreach ($PolicyName in $RequiredPolicies.Keys) {
    $ExpectedValue = $RequiredPolicies[$PolicyName]

    try {
        $CurrentValue = Get-ItemPropertyValue -Path $RegPath -Name $PolicyName -ErrorAction Stop
        if ($CurrentValue -ne $ExpectedValue) {
            $NonCompliant = $true
            $Details += "$PolicyName = $CurrentValue (expected $ExpectedValue)"
        }
    }
    catch {
        $NonCompliant = $true
        $Details += "$PolicyName is MISSING (expected $ExpectedValue)"
    }
}

if ($NonCompliant) {
    Write-Output "NON-COMPLIANT: $($Details -join '; ')"
    Stop-Transcript
    Exit 1
}
else {
    Write-Output "COMPLIANT: Cowork and Claude Code are enabled."
    Stop-Transcript
    Exit 0
}
