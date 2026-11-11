# Removes the NAPLAN updater scheduled task, the NAP Locked Down Browser, the
# firewall rule and C:\ProgramData\Naplan.
#
# Run this in an elevated PowerShell:
#   [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
#   irm -UseBasicParsing -Uri "https://raw.githubusercontent.com/MacsInSpace/NAPLAN_Installer_Updater/main/Windows/bin/NukeNAPLANScheduledTask.ps1" | iex

param(
    [string]$RepoBase = 'https://raw.githubusercontent.com/MacsInSpace/NAPLAN_Installer_Updater/main'
)

function Remove-NapEverything {
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    if (-not (New-Object Security.Principal.WindowsPrincipal($identity)).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
        Write-Host 'This script must be run as Administrator. Open PowerShell with "Run as administrator" and try again.' -ForegroundColor Red
        return
    }
    [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12

    $TaskName = 'InstallNaplan'
    $RuleName = 'NAPLockedDownBrowserOutbound'
    $StoragePath = Join-Path $env:ProgramData 'Naplan'

    # 1. The task first, so it cannot reinstall the browser behind us.
    $task = Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue
    if ($task) {
        Stop-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue
        Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false
        Write-Host "Scheduled task '$TaskName' removed."
    } else {
        Write-Host "Scheduled task '$TaskName' not found."
    }

    # 2. The browser (deep clean).
    try {
        $nuke = Invoke-RestMethod -UseBasicParsing -Uri "$RepoBase/Windows/bin/NAPLANnuke.ps1" -ErrorAction Stop
        & ([scriptblock]::Create($nuke))
    } catch {
        Write-Host "Could not download NAPLANnuke.ps1: $($_.Exception.Message)" -ForegroundColor Red
        Write-Host 'The browser was NOT removed. Uninstall it from Settings > Apps, or try again.'
    }

    # 3. Firewall rule.
    if (Get-NetFirewallRule -DisplayName $RuleName -ErrorAction SilentlyContinue) {
        Remove-NetFirewallRule -DisplayName $RuleName
        Write-Host "Firewall rule '$RuleName' removed."
    }

    # 4. The updater's own files.
    if (Test-Path $StoragePath) {
        try {
            Remove-Item -Path $StoragePath -Recurse -Force -ErrorAction Stop
            Write-Host "Removed $StoragePath"
        } catch {
            Write-Host "Failed to remove $StoragePath : $($_.Exception.Message)"
        }
    }
    Write-Host 'NAPLAN updater removal complete.'
}

Remove-NapEverything
