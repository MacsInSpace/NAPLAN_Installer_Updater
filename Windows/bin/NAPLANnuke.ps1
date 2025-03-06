# uninstalls all versions
# cheers Rolfe for all the leg work
# run *THIS* with:
# You may need to enable TLS for secure downloads on PS version 5ish
# [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12;
# irm -UseBasicParsing -Uri "https://raw.githubusercontent.com/MacsInSpace/NAPLAN_Installer_Updater/refs/heads/testing/Windows/bin/NAPLANnuke.ps1" | iex

Write-Host "Starting Naplan removal process..."

$BranchName = "testing"

# Uninstall known MSI versions
$UninstallGUIDs = @(
    "{96441ACD-EBF0-4355-9A6C-634FA4B4D4A5}", "{936DA4FF-CA28-4EFE-839C-0FE1F11F6C53}",
    "{437FE330-1798-4A96-8BEE-388D7DDED9EC}", "{19A923B0-A305-41D2-A001-84865587FF03}",
    "{D344F921-1999-4FE5-A3D7-BC87211DDFEF}", "{D6051B85-FDAA-4A9F-AD47-E1D54897CEF5}",
    "{5B2AA702-93C9-41D8-924E-5EDB646BD50F}", "{1DC4C729-D48C-493E-887A-34BF10EE3128}",
    "{95FCC227-0BE6-4FE7-9832-992769641C4D}", "{29E46A31-A0A6-4E2A-91F5-B5F8248B4716}",
    "{8A4846B5-DF7E-442F-992E-60FE5228D31A}", "{74C4ACE7-0DEC-44FB-B366-C4573FB80D52}",
    "{3090BF31-F857-466E-9A75-9DBA6E506B83}"
)

foreach ($GUID in $UninstallGUIDs) {
    Write-Host "Attempting to uninstall $GUID..."
    Start-Process "msiexec.exe" -ArgumentList "/X $GUID /qn /norestart" -NoNewWindow -Wait
}

# Uninstall EXE version (if exists)
$BootstrapperPath = "C:\ProgramData\Package Cache\{a666099a-8347-47c9-a753-5240e7dc7a1f}\JanisonNaplanBootstrapper.exe"
if (Test-Path $BootstrapperPath) {
    Write-Host "Uninstalling EXE version..."
    Start-Process $BootstrapperPath -ArgumentList "/uninstall /silent" -NoNewWindow -Wait
}

# Delete leftover registry keys
$RegKeys = @(
    "HKCR\Installer\Products\0B329A91503A2D140A1048685578FF30",
    "HKCR\Installer\Products\129F443D99915EF43A7DCB7812D1FDFE",
    "HKCR\Installer\Products\58B1506DAADFF9A4DA741E5D8479EC5F",
    "HKCR\Installer\Products\207AA2B59C398D1429E4E5BD46B65DF0",
    "HKLM\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\{96441ACD-EBF0-4355-9A6C-634FA4B4D4A5}",
    "HKLM\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\{3090BF31-F857-466E-9A75-9DBA6E506B83}"
)

foreach ($RegKey in $RegKeys) {
    Write-Host "Deleting registry key: $RegKey"
    Remove-Item -Path "Registry::$RegKey" -Recurse -Force -ErrorAction SilentlyContinue
}

# Kill running services
$Services = @("SEBWindowsService", "NAPLDBService")
foreach ($Service in $Services) {
    Write-Host "Stopping service: $Service"
    Stop-Service -Name $Service -Force -ErrorAction SilentlyContinue
    Get-Process | Where-Object { $_.Path -like "*$Service*" } | Stop-Process -Force -ErrorAction SilentlyContinue
    Write-Host "Deleting service: $Service"
    sc.exe delete $Service | Out-Null
}

# Delete remaining registry service entries
$ServiceRegKeys = @(
    "HKLM\SYSTEM\CurrentControlSet\Services\NAPLDBService",
    "HKLM\SYSTEM\CurrentControlSet\Services\SEBWindowsService"
)

foreach ($ServiceRegKey in $ServiceRegKeys) {
    Write-Host "Deleting registry service key: $ServiceRegKey"
    Remove-Item -Path "Registry::$ServiceRegKey" -Recurse -Force -ErrorAction SilentlyContinue
}

# Delete AppData folders for all users
Write-Host "Removing AppData folders..."
$UserProfiles = Get-ChildItem "C:\Users" -Directory
foreach ($User in $UserProfiles) {
    Remove-Item -Path "$($User.FullName)\AppData\Local\NAP Locked down browser" -Recurse -Force -ErrorAction SilentlyContinue
    Remove-Item -Path "$($User.FullName)\AppData\Roaming\NAP Locked down browser" -Recurse -Force -ErrorAction SilentlyContinue
}

# ReEnable Shutdown, Restart buttons if disabled
# https://www.reddit.com/r/SJSU/comments/yzzvk7/psa_respondus_lockdown_browser_messes_with_power/
Write-Host "ReEnabling Shutdown, Restart and Power buttons if disabled..."
Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Policies\Explorer" -Name "NoClose" -Value 0 -Type DWord -Force -ErrorAction SilentlyContinue

# Remove registry tracing logs
Write-Host "Removing tracing logs..."
Remove-Item -Path "Registry::HKLM\SOFTWARE\WOW6432Node\Microsoft\Tracing\SafeExamBrowser_RASAPI32" -Force -ErrorAction SilentlyContinue
Remove-Item -Path "Registry::HKLM\SOFTWARE\WOW6432Node\Microsoft\Tracing\SafeExamBrowser_RASMANCS" -Force -ErrorAction SilentlyContinue

# Remove shortcuts from All Users Start Menu
Write-Host "Removing shortcuts from All Users Start Menu..."
Remove-Item -Path "$env:ALLUSERSPROFILE\Microsoft\Windows\Start Menu\Programs\NAP*.lnk" -Force -ErrorAction SilentlyContinue

# Delete installation directory and shortcuts
Write-Host "Removing installation directories and shortcuts..."
Remove-Item -Path "C:\Program Files (x86)\NAP Locked down browser" -Recurse -Force -ErrorAction SilentlyContinue
Remove-Item -Path "C:\Users\Public\Desktop\NAP*.lnk" -Force -ErrorAction SilentlyContinue
Remove-Item -Path "$env:USERPROFILE\Desktop\NAP*.lnk" -Force -ErrorAction SilentlyContinue
Remove-Item -Path "C:\ProgramData\Microsoft\Windows\Start Menu\Programs\NAP*.lnk" -Force -ErrorAction SilentlyContinue

# Re-enable Task Manager if disabled
Write-Host "Ensuring Task Manager is enabled..."
Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Policies\System" -Name "DisableTaskMgr" -Value 0 -Force -ErrorAction SilentlyContinue

Write-Host "Naplan cleanup complete!"
