<#
    .SYNOPSIS
        Remediation script that disables local MCP servers and desktop extensions.

    .DESCRIPTION
        Creates HKLM:\SOFTWARE\Policies\Claude if needed and sets isLocalDevMcpEnabled and
        isDesktopExtensionEnabled to 0 (DWORD), blocking manual MCP server configuration and local
        desktop extension installs in the Claude Desktop app. Pairs with the matching detection script.

    .NOTES
        Author:   Bryan Moses
        Version:  v1.0
        Released: 2026-06-09

        Deployment (Microsoft Intune):
            Script type:  Remediation (remediation script)
            Assigned to:  All Claude Desktop devices

        Recommended script settings:
            - Run this script using the logged-on credentials : No
            - Enforce script signature check                  : No
            - Run script in 64-bit PowerShell host            : Yes

        Exit codes:
            0 - Remediation successful
            1 - Remediation failed or partial (check Intune logs)
#>

#### Logging Variables ####
$Script:ScriptName = "Remediate-DisableDesktopExtensionsAndManualMCPConfigs"
$Script:LogFile = "$ScriptName.log"
$Script:LogsFolder = "$env:ProgramData\Microsoft\IntuneManagementExtension\Logs"

#### Script Variables ####
$ErrorActionPreference = [System.Management.Automation.ActionPreference]::SilentlyContinue
$Host.UI.RawUI.WindowTitle = '$ScriptName'

$RegPath = "HKLM:\SOFTWARE\Policies\Claude"

# Policy state to enforce (0 = disabled)
$Policies = @{
    "isLocalDevMcpEnabled"      = 0  # 0 = block manual MCP server config
    "isDesktopExtensionEnabled" = 0  # 0 = block local extension installs
}

#### Functions ####
function Start-Logging {
    Start-Transcript -Path $LogsFolder\$LogFile -Append
    Write-Host "Current script timestamp: $(Get-Date -f yyyy-MM-dd_HH-mm)"
}

#### Script ####
Start-Logging

$Errors = @()

try {
    if (-not (Test-Path $RegPath)) {
        New-Item -Path $RegPath -Force | Out-Null
    }

    foreach ($PolicyName in $Policies.Keys) {
        try {
            Set-ItemProperty -Path $RegPath -Name $PolicyName -Value $Policies[$PolicyName] -Type DWord -Force
            Write-Output "SET: $PolicyName = $($Policies[$PolicyName])"
        }
        catch {
            $Errors += "FAILED: $PolicyName - $($_.Exception.Message)"
        }
    }

    if ($Errors.Count -gt 0) {
        Write-Output "PARTIAL: $($Errors -join '; ')"
        Stop-Transcript
        Exit 1
    }
    else {
        Write-Output "REMEDIATED: Local MCP and desktop extensions disabled."
        Stop-Transcript
        Exit 0
    }
}
catch {
    Write-Output "FAILED: $($_.Exception.Message)"
    Stop-Transcript
    Exit 1
}
