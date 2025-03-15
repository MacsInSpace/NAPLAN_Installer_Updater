
# Define paths
$scriptDir = "C:\ProgramData\Naplan"
$Year = (Get-Date -Format "yyyy")
$cmdFile = Join-Path -Path $scriptDir -ChildPath "NAPLAN_Launcher.cmd"
$iconPath = "C:\Program Files (x86)\NAP Locked down browser\Content\replay.ico"
$shortcutFile = "C:\Users\Public\Desktop\NAPLAN $Year Launcher.lnk"  # Launcher shortcut for all users

# Define the file pattern
$shortcutPattern = "NAP*er.lnk"

# Ensure necessary directories exist
if (!(Test-Path $scriptDir)) {
    New-Item -Path $scriptDir -ItemType Directory -Force | Out-Null
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

# Create CMD file (launcher)
$cmdContent = "@echo off`r`npowershell.exe -NoProfile -ExecutionPolicy Bypass -File `"%~dp0NAPLAN_Launcher.ps1`"`r`nexit /b"
Set-Content -Path $cmdFile -Value $cmdContent -Encoding ASCII

# Create Shortcut to CMD file on Public Desktop
$WScriptShell = New-Object -ComObject WScript.Shell
$shortcut = $WScriptShell.CreateShortcut($shortcutFile)
$shortcut.TargetPath = $cmdFile
$shortcut.WorkingDirectory = $scriptDir
$shortcut.Arguments = ""
$shortcut.WindowStyle = 7  # Minimized window

# Assign full absolute icon path without variables
if (Test-Path $iconPath) {
    $shortcut.IconLocation = "$iconPath,0"
} else {
    Write-Host "WARNING: Icon file missing, shortcut will use default icon."
}

$shortcut.Save()

ie4uinit.exe -ClearIconCache

Write-Host "Shortcut created at: $shortcutFile"
Write-Host "CMD and PowerShell scripts saved in: $scriptDir"
