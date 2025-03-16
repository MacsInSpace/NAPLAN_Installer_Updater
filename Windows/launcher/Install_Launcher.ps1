# run *THIS* with:
# You may need to enable TLS for secure downloads on PS version 5ish
# [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12;
# irm -UseBasicParsing -Uri "https://raw.githubusercontent.com/MacsInSpace/NAPLAN_Installer_Updater/refs/heads/main/Windows/launcher/Install_Launcher.ps1" | iex

# Git branch
$BranchName = "main"

# Define paths
$scriptDir = "C:\ProgramData\Naplan"
$Year = (Get-Date -Format "yyyy")
$NAPLANLaunchercmdFile = Join-Path -Path $scriptDir -ChildPath "NAPLAN_Launcher.cmd"
$iconPath = "C:\Program Files (x86)\NAP Locked down browser\Content\replay.ico"
$shortcutFile = "C:\Users\Public\Desktop\NAPLAN $Year Launcher.lnk"  # Launcher shortcut for all users
$LauncherScriptPath = Join-Path $StoragePath "NAPLAN_Launcher.ps1"
$NAPLANLauncherURL = "https://raw.githubusercontent.com/MacsInSpace/NAPLAN_Installer_Updater/refs/heads/$BranchName/Windows/launcher/NAPLAN_Launcher.ps1"
$NAPLANLaunchercmdFileURL = "https://raw.githubusercontent.com/MacsInSpace/NAPLAN_Installer_Updater/refs/heads/$BranchName/Windows/launcher/NAPLANLaunchercmdFile.cmd"

# Define the file pattern
$shortcutPattern = 'NAP*er.lnk'

# Ensure NAPLAN is installed and the directory exists
if (!(Test-Path -Path $iconPath -PathType Leaf)) {
    Write-Host "Naplan does not appear to be installed in the standard location. Exiting..."
    exit 1
}

# Ensure necessary directories exist
if (!(Test-Path $scriptDir)) {
    New-Item -Path $scriptDir -ItemType Directory -Force | Out-Null
}

# Download the Launcher script
try {
    Invoke-WebRequest -Uri $NAPLANLauncherURL -OutFile $LauncherScriptPath -UseBasicParsing
    Write-Host "Launcher script downloaded successfully: $LauncherScriptPath"
} catch {
    Write-Host "Failed to download launcher script: $_"
}

# Download the Launcher CMD script
try {
    Invoke-WebRequest -Uri $NAPLANLaunchercmdFileURL -OutFile $NAPLANLaunchercmdFile -UseBasicParsing
    Write-Host "Proxy script downloaded successfully: $NAPLANLaunchercmdFile"
} catch {
    Write-Host "Failed to download launcher script: $_"
}

# Remove from Public Desktop
$publicDesktop = "C:\Users\Public\Desktop"
Get-ChildItem -Path $publicDesktop -Filter $shortcutPattern -File | ForEach-Object { 
    Remove-Item -Path $_.FullName -Force 
    Write-Host "Removed: $($_.FullName)"
}

# Remove from all user-specific Desktops
$userDesktops = Get-ChildItem -Path "C:\Users" -Directory | ForEach-Object { 
    Join-Path -Path $_.FullName -ChildPath "Desktop"
}

foreach ($desktop in $userDesktops) {
    if (Test-Path $desktop) {
        Get-ChildItem -Path $desktop -Filter $shortcutPattern -File | ForEach-Object { 
            Remove-Item -Path $_.FullName -Force 
            Write-Host "Removed: $($_.FullName)"
        }
    }
}

Write-Host "Cleanup of original icons complete."

# Create Shortcut to CMD file on Public Desktop
$WScriptShell = New-Object -ComObject WScript.Shell
$shortcut = $WScriptShell.CreateShortcut($shortcutFile)
$shortcut.TargetPath = $cmdFile
$shortcut.WorkingDirectory = $scriptDir
$shortcut.Arguments = ""
$shortcut.WindowStyle = 7  # Minimized window
$shortcut.IconLocation = "$iconPath,0"
$shortcut.Save()

ie4uinit.exe -ClearIconCache

Write-Host "Shortcut created at: $shortcutFile"
Write-Host "CMD and PowerShell scripts saved in: $scriptDir"
