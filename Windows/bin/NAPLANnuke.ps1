# NapNuke base on Rolfs bat script
# run *THIS* with:
# You may need to enable TLS for secure downloads on PS version 5ish
# [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12;

# irm -UseBasicParsing -Uri "https://raw.githubusercontent.com/MacsInSpace/NAPLAN_Installer_Updater/refs/heads/main/Windows/bin/NAPLANnuke.ps1" | iex

# Testing or main git branch?
$BranchName = "main"

Write-Host "Starting Naplan removal process..."

# **Uninstall known MSI versions**
$UninstallGUIDs = @(
    "{96441ACD-EBF0-4355-9A6C-634FA4B4D4A5}", "{936DA4FF-CA28-4EFE-839C-0FE1F11F6C53}",
    "{437FE330-1798-4A96-8BEE-388D7DDED9EC}", "{19A923B0-A305-41D2-A001-84865587FF03}",
    "{D344F921-1999-4FE5-A3D7-BC87211DDFEF}", "{D6051B85-FDAA-4A9F-AD47-E1D54897CEF5}",
    "{5B2AA702-93C9-41D8-924E-5EDB646BD50F}", "{1DC4C729-D48C-493E-887A-34BF10EE3128}",
    "{95FCC227-0BE6-4FE7-9832-992769641C4D}", "{29E46A31-A0A6-4E2A-91F5-B5F8248B4716}",
    "{8A4846B5-DF7E-442F-992E-60FE5228D31A}", "{74C4ACE7-0DEC-44FB-B366-C4573FB80D52}",
    "{3090BF31-F857-466E-9A75-9DBA6E506B83}", "{250939BF-C7CB-4B67-88D5-9E080F60E288}"
)

foreach ($GUID in $UninstallGUIDs) {
    Write-Host "Uninstalling $GUID..."
    Start-Process "msiexec.exe" -ArgumentList "/X $GUID /qn /norestart" -NoNewWindow -Wait
}

# **Uninstall EXE version (if exists)**
$BootstrapperPath = "C:\ProgramData\Package Cache\{a666099a-8347-47c9-a753-5240e7dc7a1f}\JanisonNaplanBootstrapper.exe"
if (Test-Path $BootstrapperPath) {
    Write-Host "Uninstalling EXE version..."
    Start-Process $BootstrapperPath -ArgumentList "/uninstall /silent" -NoNewWindow -Wait
}

# **Stop and Remove Running Services**
$Services = @("SEBWindowsService", "NAPLDBService")
foreach ($Service in $Services) {
    Write-Host "Stopping service: $Service..."
    Stop-Service -Name $Service -Force -ErrorAction SilentlyContinue
    sc.exe delete $Service | Out-Null
}

# **Kill Running Processes**
$Processes = @("SafeExamBrowser", "NAPLAN_LDB", "SEBWindowsService", "NAPLDBService")
foreach ($Process in $Processes) {
    Get-Process -Name $Process -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
}

# **Delete Remaining Registry Entries**
$RegistryKeys = @(
    "HKCR\napldb",
    "HKCU\SOFTWARE\Janison",
    "HKLM\SOFTWARE\Classes\napldb",
    "HKEY_USERS\.DEFAULT\Software\NAP Locked down browser",
    "HKLM\SOFTWARE\WOW6432Node\Microsoft\Tracing\SafeExamBrowser_RASAPI32",
    "HKLM\SOFTWARE\WOW6432Node\Microsoft\Tracing\SafeExamBrowser_RASMANCS",
    "HKLM\SYSTEM\CurrentControlSet\Services\NAPLDBService",
    "HKLM\SYSTEM\CurrentControlSet\Services\SEBWindowsService",
    "HKCR\Installer\Products\0B329A91503A2D140A1048685578FF30",
    "HKCR\Installer\Products\129F443D99915EF43A7DCB7812D1FDFE",
    "HKCR\Installer\Products\58B1506DAADFF9A4DA741E5D8479EC5F",
    "HKCR\Installer\Products\207AA2B59C398D1429E4E5BD46B65DF0",
    "HKCR\Installer\Products\13FB0903758FE664A957D9ABE605B638"
)

foreach ($RegKey in $RegistryKeys) {
    if (Test-Path "Registry::$RegKey") {
        Remove-Item -Path "Registry::$RegKey" -Recurse -Force -ErrorAction SilentlyContinue
        Write-Host "Deleted registry key: $RegKey"
    }
}

# **Restore Touch & PrecisionTouchPad Settings**
$TouchSettings = @(
    @{ Path = "HKCU\SOFTWARE\Microsoft\Wisp\Touch"; Name = "TouchGate" },
    @{ Path = "HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\PrecisionTouchPad"; Name = "ThreeFingerSlideEnabled" },
    @{ Path = "HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\PrecisionTouchPad"; Name = "FourFingerSlideEnabled" }
)

foreach ($reg in $TouchSettings) {
    if (Test-Path "Registry::$($reg.Path)") {
        Set-ItemProperty -Path $reg.Path -Name $reg.Name -Value 1 -Type DWORD -Force
        Write-Host "Restored: $($reg.Path)\$($reg.Name) to 1"
    }
}

# **Re-enable Task Manager, Shutdown, Restart & Lock Workstation**
Write-Host "Re-enabling Shutdown, Restart, and Task Manager..."
$ReEnableRegistry = @(
    @{ Path = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Policies\Explorer"; Name = "NoClose"; Value = 0 },
    @{ Path = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Policies\System"; Name = "DisableTaskMgr"; Value = 0 },
    @{ Path = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Policies\System"; Name = "DisableLockWorkstation"; Value = 0 }
)

foreach ($entry in $ReEnableRegistry) {
    if (Test-Path $entry.Path) {
        Set-ItemProperty -Path $entry.Path -Name $entry.Name -Value $entry.Value -Force -ErrorAction SilentlyContinue
        Write-Host "Restored: $($entry.Path)\$($entry.Name) to $($entry.Value)"
    }
}

# **Remove AppData Folders for All Users**
Write-Host "Removing Naplan AppData for all users..."
$UserProfiles = Get-ChildItem "C:\Users" -Directory
foreach ($User in $UserProfiles) {
    Remove-Item -Path "$($User.FullName)\Desktop\NAP*er.lnk" -Force -ErrorAction SilentlyContinue
    Remove-Item -Path "$($User.FullName)\AppData\Roaming\NAP Locked down browser" -Recurse -Force -ErrorAction SilentlyContinue
    Remove-Item -Path "$($User.FullName)\AppData\Roaming\NAP Locked down browser" -Recurse -Force -ErrorAction SilentlyContinue
}

# **Remove Desktop Shortcuts**
$ShortcutPaths = @(
    "C:\Users\Public\Desktop\NAP*er.lnk",
    "$env:USERPROFILE\Desktop\NAP*er.lnk",
    "C:\ProgramData\Microsoft\Windows\Start Menu\Programs\NAP*er.lnk"
)

foreach ($Shortcut in $ShortcutPaths) {
    Remove-Item -Path $Shortcut -Force -ErrorAction SilentlyContinue
}

# **Final Cleanup: Delete Installation Folder**
Write-Host "Removing Naplan installation directory..."
Remove-Item -Path "C:\Program Files (x86)\NAP Locked down browser" -Recurse -Force -ErrorAction SilentlyContinue

Write-Host "Naplan cleanup complete!"
