# Installs the optional NAPLAN Launcher: a desktop shortcut that runs a few
# pre-flight checks (volume, internet, battery, screen, headphones reminder)
# before starting the NAP Locked Down Browser.
#
# The browser must already be installed. Run this in an elevated PowerShell:
#   [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
#   irm -UseBasicParsing -Uri "https://raw.githubusercontent.com/MacsInSpace/NAPLAN_Installer_Updater/main/Windows/launcher/Install_Launcher.ps1" | iex
#
# What gets installed:
#   C:\ProgramData\Naplan\NAPLAN_Launcher.ps1    (the checks)
#   C:\ProgramData\Naplan\NAPLAN_Launcher.cmd    (what the shortcut starts)
#   C:\Users\Public\Desktop\NAPLAN <year> Launcher.lnk
# The browser's own desktop shortcuts are removed so students use the launcher.
#
# To remove the launcher and put the browser's own shortcut back, run this script
# with -Uninstall. The updater's full uninstall removes the launcher too.

param(
    [string]$RepoBase = 'https://raw.githubusercontent.com/MacsInSpace/NAPLAN_Installer_Updater/main',
    [switch]$Uninstall
)

function Install-NapLauncher {
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    if (-not (New-Object Security.Principal.WindowsPrincipal($identity)).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
        Write-Host 'This script must be run as Administrator. Open PowerShell with "Run as administrator" and try again.' -ForegroundColor Red
        return
    }
    [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12

    $StoragePath   = Join-Path $env:ProgramData 'Naplan'
    $LauncherPs1   = Join-Path $StoragePath 'NAPLAN_Launcher.ps1'
    $LauncherCmd   = Join-Path $StoragePath 'NAPLAN_Launcher.cmd'
    $PublicDesktop = Join-Path $env:PUBLIC 'Desktop'
    $ShortcutFile  = Join-Path $PublicDesktop ("NAPLAN {0} Launcher.lnk" -f (Get-Date -Format 'yyyy'))
    $StockPattern  = 'NAP Locked*.lnk'        # the browser's own shortcuts
    $LauncherPattern = 'NAPLAN*Launcher.lnk'  # ours, any year

    # Every desktop a shortcut could be on.
    $desktops = @($PublicDesktop) + @(Get-ChildItem 'C:\Users' -Directory -ErrorAction SilentlyContinue |
        ForEach-Object { Join-Path $_.FullName 'Desktop' } | Where-Object { Test-Path $_ })

    function Find-NapBrowserDir {
        $keys = 'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*',
                'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*'
        $candidates = @(Get-ItemProperty -Path $keys -ErrorAction SilentlyContinue |
            Where-Object { $_.DisplayName -like 'NAP Locked Down Browser*' -and $_.InstallLocation } |
            ForEach-Object { $_.InstallLocation })
        if (${env:ProgramFiles(x86)}) { $candidates += Join-Path ${env:ProgramFiles(x86)} 'NAP Locked Down Browser' }
        $candidates += Join-Path $env:ProgramFiles 'NAP Locked Down Browser'
        foreach ($dir in $candidates) {
            if (Test-Path (Join-Path $dir 'NAP Locked Down Browser.exe')) { return $dir.TrimEnd('\') }
        }
        return $null
    }

    function New-NapShortcut([string]$Path, [string]$Target, [string]$WorkDir, [string]$Icon, [int]$WindowStyle, [string]$Description) {
        $shell = New-Object -ComObject WScript.Shell
        $shortcut = $shell.CreateShortcut($Path)
        $shortcut.TargetPath = $Target
        $shortcut.WorkingDirectory = $WorkDir
        $shortcut.WindowStyle = $WindowStyle
        $shortcut.IconLocation = "$Icon,0"
        $shortcut.Description = $Description
        $shortcut.Save()
    }

    if ($Uninstall) {
        foreach ($desktop in $desktops) {
            Get-ChildItem -Path $desktop -Filter $LauncherPattern -File -ErrorAction SilentlyContinue | Remove-Item -Force
        }
        Remove-Item $LauncherPs1, $LauncherCmd -Force -ErrorAction SilentlyContinue
        Write-Host 'NAPLAN Launcher removed.'
        # Put the browser's own desktop shortcut back, if the browser is installed.
        $dir = Find-NapBrowserDir
        if ($dir) {
            $exe = Join-Path $dir 'NAP Locked Down Browser.exe'
            $stock = Join-Path $PublicDesktop 'NAP Locked down browser.lnk'
            New-NapShortcut $stock $exe $dir $exe 1 'NAP Locked down browser'
            Write-Host "Restored the browser's own shortcut: $stock"
        }
        return
    }

    # --- the browser must be installed ------------------------------------------------
    $installDir = Find-NapBrowserDir
    if (-not $installDir) {
        Write-Host 'The NAP Locked Down Browser does not appear to be installed. Install it first, then run this again.' -ForegroundColor Red
        return
    }
    $exePath  = Join-Path $installDir 'NAP Locked Down Browser.exe'
    $iconPath = Join-Path $installDir 'Content\replay.ico'
    if (-not (Test-Path $iconPath)) { $iconPath = $exePath }   # fall back to the exe's own icon

    # --- storage folder: students must be able to read it but not change it -----------------
    if (-not (Test-Path $StoragePath)) { New-Item -ItemType Directory -Path $StoragePath -Force | Out-Null }
    & icacls.exe $StoragePath /setowner '*S-1-5-32-544' /T /C /Q 2>&1 | Out-Null
    & icacls.exe $StoragePath /inheritance:r /grant:r '*S-1-5-18:(OI)(CI)F' '*S-1-5-32-544:(OI)(CI)F' '*S-1-5-32-545:(OI)(CI)RX' /C /Q 2>&1 | Out-Null

    # --- get the launcher files (from next to this script, or GitHub) ---------------------------
    function Get-LauncherFile([string]$RepoName, [string]$Destination) {
        $tmp = "$Destination.new"
        Remove-Item $tmp -Force -ErrorAction SilentlyContinue
        if ($PSScriptRoot -and (Test-Path (Join-Path $PSScriptRoot $RepoName))) {
            Copy-Item (Join-Path $PSScriptRoot $RepoName) $tmp -Force
        } else {
            try { (New-Object Net.WebClient).DownloadFile("$RepoBase/Windows/launcher/$RepoName", $tmp) }
            catch { Write-Host "Could not download $RepoName : $($_.Exception.Message)" -ForegroundColor Red; return $false }
        }
        return $true
    }

    if (-not (Get-LauncherFile 'NAPLAN_Launcher.ps1' $LauncherPs1) -or -not (Get-LauncherFile 'NAPLANLaunchercmdFile.cmd' $LauncherCmd)) {
        Remove-Item "$LauncherPs1.new", "$LauncherCmd.new" -Force -ErrorAction SilentlyContinue
        Write-Host 'The launcher was NOT installed. Nothing was changed.' -ForegroundColor Red
        return
    }
    $tokens = $null; $errors = $null
    [void][System.Management.Automation.Language.Parser]::ParseFile("$LauncherPs1.new", [ref]$tokens, [ref]$errors)
    if ($errors -or (Get-Content "$LauncherPs1.new" -Raw) -notmatch 'NAPLAN-LAUNCHER-SCRIPT') {
        Remove-Item "$LauncherPs1.new", "$LauncherCmd.new" -Force -ErrorAction SilentlyContinue
        Write-Host 'The downloaded launcher script does not look right. Nothing was changed.' -ForegroundColor Red
        return
    }
    Move-Item "$LauncherPs1.new" $LauncherPs1 -Force
    Move-Item "$LauncherCmd.new" $LauncherCmd -Force
    & icacls.exe $LauncherPs1 $LauncherCmd /reset /C /Q 2>&1 | Out-Null

    # --- shortcuts: remove the browser's own and any older launcher, add ours -------------------------
    foreach ($desktop in $desktops) {
        Get-ChildItem -Path $desktop -File -ErrorAction SilentlyContinue |
            Where-Object { $_.Name -like $StockPattern -or $_.Name -like $LauncherPattern } |
            ForEach-Object { Remove-Item $_.FullName -Force; Write-Host "Removed: $($_.FullName)" }
    }

    # Window style 7 = minimised, so the command window does not flash up.
    New-NapShortcut $ShortcutFile $LauncherCmd $StoragePath $iconPath 7 'Checks this device, then starts the NAP Locked Down Browser'

    if (-not (Test-Path $ShortcutFile)) {
        Write-Host "Failed to create the shortcut at $ShortcutFile" -ForegroundColor Red
        return
    }
    try { Start-Process -FilePath 'ie4uinit.exe' -ArgumentList '-ClearIconCache' -WindowStyle Hidden } catch { }

    Write-Host "Shortcut created: $ShortcutFile"
    Write-Host "Launcher scripts saved in: $StoragePath"
}

Install-NapLauncher
