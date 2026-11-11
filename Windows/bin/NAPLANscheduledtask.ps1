# Installs the scheduled task that keeps the NAP Locked Down Browser up to date.
#
# Run this in an elevated PowerShell:
#   [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
#   irm -UseBasicParsing -Uri "https://raw.githubusercontent.com/MacsInSpace/NAPLAN_Installer_Updater/main/Windows/bin/NAPLANscheduledtask.ps1" | iex
#
# What gets installed:
#   Scheduled task "InstallNaplan" (runs as SYSTEM, daily and at startup)
#   C:\ProgramData\Naplan\RunNaplanUpdate.ps1   (small runner the task starts)
#   C:\ProgramData\Naplan\InstallNaplan.ps1     (cached copy of the installer)
#   C:\ProgramData\Naplan\proxy.ps1             (proxy helper)
#   C:\ProgramData\Naplan\NaplanUpdater.log
#
# Each run refreshes the cached installer from GitHub if it can, then runs it
# with -Scheduled. If GitHub is unreachable the cached copy is used.

param(
    [string]$RepoBase = 'https://raw.githubusercontent.com/MacsInSpace/NAPLAN_Installer_Updater/main',
    [switch]$NoStart      # register/refresh the task but do not run it now
)

function Install-NapTask {
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $isAdmin = (New-Object Security.Principal.WindowsPrincipal($identity)).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    if (-not $isAdmin) {
        Write-Host 'This script must be run as Administrator. Open PowerShell with "Run as administrator" and try again.' -ForegroundColor Red
        return
    }

    [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12
    $ProgressPreference = 'SilentlyContinue'

    $TaskName    = 'InstallNaplan'
    $StoragePath = Join-Path $env:ProgramData 'Naplan'
    $Runner      = Join-Path $StoragePath 'RunNaplanUpdate.ps1'
    $Installer   = Join-Path $StoragePath 'InstallNaplan.ps1'
    $ProxyScript = Join-Path $StoragePath 'proxy.ps1'

    # C:\ProgramData lets ordinary users create files by default. This folder holds
    # scripts that run as SYSTEM, so lock it down first: SYSTEM + Administrators
    # full, Users read-only. SIDs are used so this works on non-English Windows.
    foreach ($dir in $StoragePath, (Join-Path $StoragePath 'Temp')) {
        if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
    }
    & icacls.exe $StoragePath /setowner '*S-1-5-32-544' /T /C /Q 2>&1 | Out-Null
    & icacls.exe $StoragePath /inheritance:r /grant:r '*S-1-5-18:(OI)(CI)F' '*S-1-5-32-544:(OI)(CI)F' '*S-1-5-32-545:(OI)(CI)RX' /C /Q 2>&1 | Out-Null
    & icacls.exe (Join-Path $StoragePath '*') /reset /T /C /Q 2>&1 | Out-Null

    # Files left by older versions of this project.
    Remove-Item (Join-Path $StoragePath 'NaplanLastUpdate.txt') -Force -ErrorAction SilentlyContinue

    # --- get the installer and proxy helper (from next to this script, or GitHub) ----
    function Get-NapFile([string]$RepoPath, [string]$LocalName, [string]$Destination) {
        if ($PSScriptRoot) {
            foreach ($candidate in (Join-Path $PSScriptRoot $LocalName), (Join-Path $PSScriptRoot "..\conf\$LocalName")) {
                if ((Test-Path $candidate) -and ((Resolve-Path $candidate).Path -ne $Destination)) { Copy-Item $candidate $Destination -Force; return $true }
            }
        }
        try {
            Remove-Item "$Destination.new" -Force -ErrorAction SilentlyContinue
            (New-Object Net.WebClient).DownloadFile("$RepoBase/$RepoPath", "$Destination.new")
            Move-Item "$Destination.new" $Destination -Force
            return $true
        } catch {
            Write-Host "Could not download $RepoPath : $($_.Exception.Message)"
            return $false
        }
    }

    if (-not (Get-NapFile 'Windows/bin/InstallNaplan.ps1' 'InstallNaplan.ps1' $Installer) -and -not (Test-Path $Installer)) {
        Write-Host 'Could not get InstallNaplan.ps1. The scheduled task was NOT installed.' -ForegroundColor Red
        return
    }
    if ((Get-Content $Installer -Raw) -notmatch 'NAPLAN-UPDATER-SCRIPT') {
        Write-Host 'Downloaded InstallNaplan.ps1 does not look right. The scheduled task was NOT installed.' -ForegroundColor Red
        Remove-Item $Installer -Force
        return
    }
    if (-not (Get-NapFile 'Windows/conf/proxy.ps1' 'proxy.ps1' $ProxyScript)) {
        Write-Host 'Proxy helper not available; continuing without it.'
    }

    # --- the runner the task starts -------------------------------------------------
    $runnerText = @'
# Written by NAPLANscheduledtask.ps1. Refreshes the cached installer, then runs it.
$RepoBase  = '__REPOBASE__'
$Storage   = Join-Path $env:ProgramData 'Naplan'
$Installer = Join-Path $Storage 'InstallNaplan.ps1'
$Proxy     = Join-Path $Storage 'proxy.ps1'
$Log       = Join-Path $Storage 'NaplanUpdater.log'
$ProgressPreference = 'SilentlyContinue'
[Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12

if (Test-Path $Proxy) { try { & $Proxy *> $null } catch { } }

# At startup the network may not be up yet: try for up to five minutes.
$new = "$Installer.new"
$ok = $false
for ($i = 0; $i -lt 10 -and -not $ok; $i++) {
    try {
        Remove-Item $new -Force -ErrorAction SilentlyContinue
        (New-Object Net.WebClient).DownloadFile("$RepoBase/Windows/bin/InstallNaplan.ps1", $new)
        $ok = $true
    } catch { Start-Sleep -Seconds 30 }
}
if ($ok) {
    $text = Get-Content $new -Raw
    $tokens = $null; $errors = $null
    [void][System.Management.Automation.Language.Parser]::ParseInput($text, [ref]$tokens, [ref]$errors)
    if ($text -match 'NAPLAN-UPDATER-SCRIPT' -and -not $errors) { Move-Item $new $Installer -Force } else { $ok = $false; Remove-Item $new -Force }
}
if (-not $ok) {
    Add-Content $Log ("{0} [WARN] Could not refresh the installer from GitHub; using the cached copy." -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'))
}
if (-not (Test-Path $Installer)) { exit 1 }

& $Installer -Scheduled -RepoBase $RepoBase
exit $LASTEXITCODE
'@
    Set-Content -Path $Runner -Value ($runnerText.Replace('__REPOBASE__', $RepoBase)) -Encoding ASCII

    # --- the task: daily at a random school-hours time, and at startup ----------------------
    $ps = Join-Path $env:SystemRoot 'System32\WindowsPowerShell\v1.0\powershell.exe'
    $action = New-ScheduledTaskAction -Execute $ps -Argument "-NoProfile -NonInteractive -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$Runner`""

    $dailyAt = Get-Date -Hour (Get-Random -Minimum 9 -Maximum 16) -Minute (Get-Random -Minimum 0 -Maximum 60) -Second 0
    $daily = New-ScheduledTaskTrigger -Daily -At $dailyAt
    $startup = New-ScheduledTaskTrigger -AtStartup
    $startup.Delay = 'PT5M'

    $settings = New-ScheduledTaskSettingsSet `
        -AllowStartIfOnBatteries `
        -DontStopIfGoingOnBatteries `
        -StartWhenAvailable `
        -ExecutionTimeLimit (New-TimeSpan -Hours 2) `
        -RunOnlyIfNetworkAvailable `
        -MultipleInstances IgnoreNew

    $principal = New-ScheduledTaskPrincipal -UserId 'SYSTEM' -LogonType ServiceAccount -RunLevel Highest

    $existed = [bool](Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue)
    Register-ScheduledTask -TaskName $TaskName -Description 'Keeps the NAP Locked Down Browser up to date' `
        -Action $action -Trigger @($daily, $startup) -Settings $settings -Principal $principal -Force | Out-Null

    if (-not (Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue)) {
        Write-Host "Failed to register scheduled task '$TaskName'." -ForegroundColor Red
        return
    }
    Write-Host ("Scheduled task '{0}' {1}. It runs daily at {2:HH:mm} and at startup." -f $TaskName, $(if ($existed) { 'updated' } else { 'installed' }), $dailyAt)
    Write-Host "Log: $(Join-Path $StoragePath 'NaplanUpdater.log')"

    if (-not $NoStart) {
        Start-ScheduledTask -TaskName $TaskName
        Write-Host 'The first run has started now.'
    }
}

Install-NapTask
