# Define paths
$scriptDir = "C:\ProgramData\Naplan"
$Year = (Get-Date -Format "yyyy)
$cmdFile = Join-Path -Path $scriptDir -ChildPath "NAPLAN_Launcher.cmd"
$psFile = Join-Path -Path $scriptDir -ChildPath "NAPLAN_Launcher.ps1"
$iconPath = "C:\Program Files (x86)\NAP Locked down browser\Content\replay.ico"
$shortcutFile = "C:\Users\Public\Desktop\NAPLAN $year Launcher.lnk"  # Launcher shortcut for all users
$OshortcutFile = "C:\Users\Public\Desktop\NAP*er.lnk" #Old shortcut for all users
# Ensure necessary directories exist
if (!(Test-Path $scriptDir)) {
    New-Item -Path $scriptDir -ItemType Directory -Force | Out-Null
}
# Get all matching shortcut files
$shortcuts = Get-ChildItem -Path $shortcutPattern -File

# Remove each found shortcut
if ($shortcuts) {
    $shortcuts | ForEach-Object {
        Remove-Item -Path $_.FullName -Force
        Write-Host "Removed: $($_.FullName)"
    }
} else {
    Write-Host "No matching shortcuts found."
}

# Create CMD file (launcher)
$cmdContent = "@echo off`r`npowershell.exe -NoProfile -ExecutionPolicy Bypass -File `"%~dp0NAPLAN_Launcher.ps1`"`r`nexit /b"
Set-Content -Path $cmdFile -Value $cmdContent -Encoding ASCII

# Create CMD file (launcher)
$cmdContent = "@echo off`r`npowershell.exe -NoProfile -ExecutionPolicy Bypass -File `"%~dp0NAPLAN_Launcher.ps1`"`r`nexit /b"
Set-Content -Path $cmdFile -Value $cmdContent -Encoding ASCII

# Create PowerShell script (placeholder for now)
$psContent = @'
# Placeholder PowerShell script for launching NAPLAN LDB
Write-Host "Launching NAPLAN Locked Down Browser..."
# Add logic here to check prerequisites and launch the app
'@
Set-Content -Path $psFile -Value $psContent -Encoding UTF8

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

Write-Host "Shortcut created at: $shortcutFile"
Write-Host "CMD and PowerShell scripts saved in: $scriptDir"
