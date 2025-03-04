# installs the latest version
# run *THIS* with:
# You may need to enable TLS for secure downloads on PS version 5ish
# [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12;
# irm -UseBasicParsing -Uri "https://raw.githubusercontent.com/MacsInSpace/NAPLAN_Installer_Updater/refs/heads/main/Windows/InstallNaplan.ps1" | iex

Start-Transcript -Path "C:\Windows\Temp\NaplanScheduledTask.log" -Append

# Define the fallback local SMB path (only used if the internet check fails)
$FallbackSMB = "\\XXXXWDS01\Deploymentshare$\Applications\Naplan.msi"
$ErrorActionPreference = 'Stop'
$ForceUpdate = $false #true will force the update regardless of version number

#=======================================================================
#CHECK IF SCRIPT IS RUN AS ADMINISTRATOR

# Get the ID and security principal of the current user account
$myWindowsID=[System.Security.Principal.WindowsIdentity]::GetCurrent()
$myWindowsPrincipal=new-object System.Security.Principal.WindowsPrincipal($myWindowsID)
 
# Get the security principal for the Administrator role
$adminRole=[System.Security.Principal.WindowsBuiltInRole]::Administrator
 
# Check to see if we are currently running "as Administrator"
if ($myWindowsPrincipal.IsInRole($adminRole))
   {
   # We are running "as Administrator" - so change the title and background color to indicate this
   $Host.UI.RawUI.WindowTitle = $myInvocation.MyCommand.Definition + "(Elevated)"
   # $Host.UI.RawUI.BackgroundColor = "DarkBlue"
   clear-host
   }
else
   {
   # We are not running "as Administrator" - so relaunch as administrator
   # Create a new process object that starts PowerShell
   $newProcess = new-object System.Diagnostics.ProcessStartInfo "PowerShell";
   
   # Specify the current script path and name as a parameter
   $newProcess.Arguments = $myInvocation.MyCommand.Definition;
   
   # Indicate that the process should be elevated
   $newProcess.Verb = "runas";
   
   # Start the new process
   [System.Diagnostics.Process]::Start($newProcess);
   
   # Exit from the current, unelevated, process
   exit
   }

Clear-Host

$sig = '[DllImport("user32.dll")] public static extern bool ShowWindowAsync(IntPtr hWnd, int nCmdShow);'

Add-Type -MemberDefinition $sig -name NativeMethods -namespace Win32

$PSId = @(Get-Process | Where-Object {$_.Name -like "*Powershell*"} -ErrorAction SilentlyContinue)[0].MainWindowHandle

If ($PSId -ne $NULL) { [Win32.NativeMethods]::ShowWindowAsync($PSId,2)}


# Self-elevate the script if required

#if (!([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
#    Start-Process PowerShell -Verb RunAs "-NoProfile -ExecutionPolicy Bypass -Command `"cd '$pwd'; & '$PSCommandPath';`"";
#    exit;
#}

# Set download directory for SYSTEM compatibility
$LocalTempDir = "$env:Windir\Temp"
$Setup = Join-Path $LocalTempDir "Naplan_Setup.msi"

# Check if we have an active internet connection
$InternetAvailable = $false
try {
    $pingTest = Test-Connection -ComputerName "8.8.8.8" -Count 1 -Quiet
    if ($pingTest) { $InternetAvailable = $true }
} catch {
    Write-Host "Internet check failed. Falling back to local SMB."
    exit 1
}
# Securely download and execute the script with TLS 1.2
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

# Try to get the latest MSI download URL if internet is available
if ($InternetAvailable) {
    try {
        # Fetch the MSI download link
        $URL = ((Invoke-WebRequest -UseBasicParsing -Uri 'https://www.assessform.edu.au/naplan-online/locked-down-browser').Links | 
        Where-Object {$_.href -match "\.msi$"}).href

        if ($URL) {
            # Decode URL to replace %20 with spaces
            $DecodedURL = [System.Uri]::UnescapeDataString($URL)

            # Extract the version number from filename
            if ($DecodedURL -match '(\d+)[-_.](\d+)[-_.](\d+)') {
                $RemoteVersion = "$($matches[1]).$($matches[2]).$($matches[3])"
                Write-Host "Latest Naplan Version Found Online: $RemoteVersion"
            } else {
                Write-Host "Failed to extract version number from MSI URL: $DecodedURL"
                exit 1
            }
        } else {
            Write-Host "No MSI URL found."
            exit 1
        }

    } catch {
        Write-Host "Failed to retrieve MSI URL. Falling back to local SMB. Error: $_"
        $InternetAvailable = $false
        exit 1
    }
}

# Check the currently installed version
Write-Host "Checking for old version..."
$Installed = (Get-WmiObject -Query "SELECT * FROM Win32_Product WHERE Name LIKE 'NAP Locked down browser%'")

If ($Installed) {
    $InstalledVersion = ($Installed).Version
    $InstalledGUID = ($Installed).IdentifyingNumber
    Write-Host "Installed Version: $InstalledVersion"
    Write-Host "Installed GUID: $InstalledGUID"
}

# Compare versions and proceed only if an update is needed
if ($ForceUpdate -or $InstalledVersion -ne $RemoteVersion) {
    # Uninstall old version
    if ($ForceUpdate -and $Installed) {
    Write-Host "Force update called. Installing new version"
    
    }   
    if ($InstalledGUID) {
        Write-Host "Removing old version: $InstalledGUID"
        Start-Process "msiexec.exe" -ArgumentList "/X $InstalledGUID /qn /norestart" -NoNewWindow -Wait
        #Nap Nuke
        Write-Host "Calling clean-up of old versions of Naplan"
        irm  -UseBasicParsing -Uri "https://raw.githubusercontent.com/MacsInSpace/NAPLAN_Installer_Updater/refs/heads/main/Windows/NAPLANnuke.ps1" | iex
    }

    Write-Host "Downloading and Installing..."

    if ($InternetAvailable -and $URL) {
        Write-Host "Downloading latest version from: $URL"
        (New-Object System.Net.WebClient).DownloadFile($URL, $Setup)
    } elseif (Test-Path $FallbackSMB) {
        Write-Host "Internet unavailable. Installing from local SMB: $FallbackSMB"
        Copy-Item "$FallbackSMB" -Destination "$Setup" -Force
    } else {
        Write-Host "No valid installation source found. Exiting."
        Exit 1
    }

    # Install the MSI
    Write-Host "Installing Naplan..."
    # Start the MSI installation and capture the process object
    $installProcess = Start-Process "msiexec.exe" -ArgumentList "/i `"$Setup`" /qn /norestart" -NoNewWindow -PassThru
    
    # Wait for the process to exit
    Write-Host "Waiting for installation to complete..."
    $installProcess.WaitForExit()

    # Clean up MSI file after installation completes
    Write-Host "Installation completed. Cleaning up..."
    Remove-Item "$Setup" -Force -ErrorAction SilentlyContinue -Verbose

    # Clearing/resetting icon cache
    #Write-Host "Stopping Windows Explorer..."
    #Stop-Process -Name "explorer" -Force -ErrorAction SilentlyContinue

    #Write-Host "Deleting icon cache for all users..."
    #$UserProfiles = Get-ChildItem "C:\Users" -Directory

    #foreach ($User in $UserProfiles) {
    #    $ExplorerCachePath = "$($User.FullName)\AppData\Local\Microsoft\Windows\Explorer"

    #    if (Test-Path $ExplorerCachePath) {
    #        Write-Host "Clearing cache for user: $($User.Name)"
    #        Remove-Item "$ExplorerCachePath\iconcache*" -Force -ErrorAction SilentlyContinue
    #    }
    #}

    #Write-Host "Refreshing icon cache..."
    #& ie4uinit.exe -show

    #Write-Host "Restarting Windows Explorer..."
    #Stop-Process -Name "explorer" -Force -ErrorAction SilentlyContinue
    #Start-Process "explorer.exe"
    (New-Object -ComObject Shell.Application).MinimizeAll()
     Start-Sleep -Milliseconds 500
    (New-Object -ComObject Shell.Application).UndoMinimizeAll()
    Write-Host "Icon refresh complete."
    
} 

Write-Host "Naplan is up-to-date. Exiting."
Stop-Transcript
