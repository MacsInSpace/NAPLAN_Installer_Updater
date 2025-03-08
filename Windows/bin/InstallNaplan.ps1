# installs the latest version
# run *THIS* with:
# You may need to enable TLS for secure downloads on PS version 5ish
# [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12;
# irm -UseBasicParsing -Uri "https://raw.githubusercontent.com/MacsInSpace/NAPLAN_Installer_Updater/refs/heads/testing/Windows/bin/InstallNaplan.ps1" | iex

# Function to check if a transcript is running
function Start-ConditionalTranscript {
    if ($global:transcript -ne $null) {
        Write-Host "Transcript is already running. Skipping Start-Transcript."
    } else {
        Start-Transcript -Path "$env:windir\Temp\NaplanInstallScheduledTask.log" -Append
        $global:transcript = $true  # Mark transcript as active
    }
}

# Function to stop transcript safely
function Stop-ConditionalTranscript {
    try {
        Stop-Transcript
    } catch {
        Write-Host "No active transcript to stop."
    }
    $global:transcript = $null
}

# Call the function to conditionally start transcript
Start-ConditionalTranscript

# Define the fallback local SMB path (only used if the internet check fails)
$FallbackSMB = "\\XXXXWDS01\Deploymentshare$\Applications\Naplan.msi"

# Force an update (uninstall and reinstall regardless of time, date)
$ForceUpdate = $false # default to $false. # $true will force the update regardless of version number

# Force an update of the scheduled task
$Updatetasktoo = $true #default to $false. # true will force the update task.

# Testing or main git branch?
$BranchName = "testing"

# NAPLAN key dates page
$kdurl = "https://www.nap.edu.au/naplan/key-dates"

# NAPLAN downloads page
$dlurls = "https://www.assessform.edu.au/naplan-online/locked-down-browser"

$napnukeurl = "https://raw.githubusercontent.com/MacsInSpace/NAPLAN_Installer_Updater/refs/heads/$BranchName/Windows/bin/NAPLANnuke.ps1"

$scheduledtaskurl = "https://raw.githubusercontent.com/MacsInSpace/NAPLAN_Installer_Updater/refs/heads/$BranchName/Windows/bin/NAPLANscheduledtask.ps1"

$currentDate = Get-Date
# Get the current year dynamically
$currentYear = (Get-Date).Year

# Set some backup testing dates
$testStartDateFallback = Get-Date "$currentYear-03-1"  # Approximate fallback
$testEndDateFallback =  Get-Date "$currentYear-04-30"

# Define the storage path
$StoragePath = Join-Path $env:ProgramData "Naplan"
$ProxyScriptPath = Join-Path $StoragePath "proxy.ps1"
$LocalTempDir = Join-Path $StoragePath "Temp"
$Setup = Join-Path $LocalTempDir "Naplan_Setup.msi"
$lastUpdateFile = Join-Path $StoragePath "NaplanLastUpdate.txt"

# Ensure the directory exists
if (-not (Test-Path $StoragePath)) {
    New-Item -ItemType Directory -Path $StoragePath -Force | Out-Null
    Write-Host "Created directory: $StoragePath"
}

# Ensure the directory exists
if (-not (Test-Path $LocalTempDir)) {
    New-Item -ItemType Directory -Path $LocalTempDir -Force | Out-Null
    Write-Host "Created directory: $LocalTempDir"
}

# Set permissions (SYSTEM and Administrators: FullControl)
$acl = Get-Acl $StoragePath
$rule = New-Object System.Security.AccessControl.FileSystemAccessRule("SYSTEM", "FullControl", "ContainerInherit, ObjectInherit", "None", "Allow")
$acl.AddAccessRule($rule)

$rule = New-Object System.Security.AccessControl.FileSystemAccessRule("Administrators", "FullControl", "ContainerInherit, ObjectInherit", "None", "Allow")
$acl.AddAccessRule($rule)

Set-Acl -Path $StoragePath -AclObject $acl
Write-Host "Permissions set: SYSTEM and Administrators have FullControl"

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
   #$Host.UI.RawUI.WindowTitle = $myInvocation.MyCommand.Definition + "(Elevated)"
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

# Set download directory for SYSTEM compatibility
Write-Host "Force Update NAPLAN set to: $ForceUpdate "
Write-Host "Update scheduled task set to: $Updatetasktoo"

# Check if we have an active internet connection
$InternetAvailable = $false
try {
    $pingTest = Test-Connection -ComputerName "8.8.8.8" -Count 1 -Quiet
    if ($pingTest) { $InternetAvailable = $true }
} catch {
    Write-Host "Internet check failed. Falling back to local SMB."
     Stop-Transcript;exit 1
}

# Securely download and execute the script with TLS 1.2
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

# Retry logic for fetching the webpage
$maxRetries = 3
$retryCount = 0
$webContent = $null
$success = $false

while (-not $success -and $retryCount -lt $maxRetries) {
    try {
        $webContent = Invoke-WebRequest -Uri $kdurl -UseBasicParsing -TimeoutSec 10
        $success = $true
    } catch {
        $retryCount++
        Write-Host "Failed to retrieve NAPLAN key dates page (Attempt $retryCount of $maxRetries): $_"
        Start-Sleep -Seconds 5  # Wait before retrying
    }
}

# If the request failed after retries, use fallback dates
if (-not $success) {
    Write-Host "ACARA website unreachable. Using fallback test dates."
    $testStartDate = $testStartDateFallback
    $testEndDate = $testEndDateFallback
} else {
     $contentString = $webContent.Content
     # Apply regex
     $pattern = "(\d{1,2})\s*[\p{Pd}]\s*(\d{1,2})\s+(January|February|March|April|May|June|July|August|September|October|November|December)"
     $matches = [regex]::Matches($contentString, $pattern)

     Write-Host "Found $($matches.Count) matches."

   
if ($matches.Count -gt 0) {
    # Extract start and end dates
    $startDay = $matches[0].Groups[1].Value
    $endDay = $matches[0].Groups[2].Value
    $month = $matches[0].Groups[3].Value

    # Convert the month name to a numerical format
    $monthNumber = @{
        "January" = 1; "February" = 2; "March" = 3; "April" = 4; "May" = 5;
        "June" = 6; "July" = 7; "August" = 8; "September" = 9;
        "October" = 10; "November" = 11; "December" = 12
    }[$month]

   # Construct full date strings, ensuring they remain DateTime objects
   $testStartDate = [datetime]::ParseExact("$startDay/$monthNumber/$currentYear", "dd/M/yyyy", $null)
   $testEndDate = [datetime]::ParseExact("$endDay/$monthNumber/$currentYear", "dd/M/yyyy", $null)

   # Output in Australian format for readability
   Write-Host "Detected NAPLAN test window: $($testStartDate.ToString('dd/MM/yyyy')) to $($testEndDate.ToString('dd/MM/yyyy'))"

} else {
    Write-Host "Failed to parse NAPLAN test dates from the webpage."
    $testStartDate = $testStartDateFallback
    $testEndDate = $testEndDateFallback
}
}
# --- Now use these dates for update logic ---

# If today falls in the test window, log and exit
if ($currentDate -ge $testStartDate -and $currentDate -le $testEndDate -or $ForceUpdate) {
    if ($ForceUpdate ) {
    Write-Host "We are in the detected testing period but forcing the update. Hold on tight..." 
    } else {
     Write-Host "$(Get-Date) - Not running due to NAPLAN testing window."
     Stop-Transcript;exit 0
    }
}

# Define high-frequency update period (e.g., 60 days before test start)
$highFreqStartDate = $testStartDate.AddDays(-60)
$highFreqEndDate = $testEndDate

# Set update interval
if ($currentDate -ge $highFreqStartDate -and $currentDate -le $highFreqEndDate) {
    $updateIntervalDays = 7  # Weekly updates
} else {
    $updateIntervalDays = 30  # Monthly updates
}

Write-Host "Update interval set to every $updateIntervalDays days."

# Check if an update is needed
$updateNeeded = $false

## Read the last update date from the file
if (Test-Path $lastUpdateFile) {
    $lastUpdateString = Get-Content $lastUpdateFile | Where-Object { $_ -match "\S" } | Select-Object -Last 1

    if ($lastUpdateString) {
        try {
            # Parse last update as YYYYMMDD
            $lastUpdate = [datetime]::ParseExact($lastUpdateString, "yyyyMMdd", $null)
            $daysSinceLastUpdate = ($currentDate - $lastUpdate).Days

            Write-Host "Last update was on: $lastUpdate (Days since: $daysSinceLastUpdate)"

            if ($daysSinceLastUpdate -ge $updateIntervalDays) {
                $updateNeeded = $true
            }
        } catch {
            Write-Host "Failed to parse last update date. Forcing update."
            $updateNeeded = $true
        }
    } else {
        Write-Host "Update file is empty or invalid. Forcing update."
        $updateNeeded = $true
    }
} else {
    Write-Host "No previous update record found. Forcing update."
    $updateNeeded = $true
}

# Perform update if needed
if ($updateNeeded -or $ForceUpdate) {
    if ($ForceUpdate) {
        Write-Host "Initiating NAPLAN LDB due to Forced update flag set."
    }
    Write-Host "Initiating NAPLAN LDB update..."
# Try to get the latest MSI download URL if internet is available
if ($InternetAvailable) {
    try {
        # Fetch the MSI download link
        $URL = ((Invoke-WebRequest -UseBasicParsing -Uri $dlurls).Links | 
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
                 Stop-Transcript;exit 1
            }
        } else {
            Write-Host "No MSI URL found."
             Stop-Transcript;exit 1
        }

    } catch {
        Write-Host "Failed to retrieve MSI URL. Falling back to local SMB. Error: $_"
        $InternetAvailable = $false
         Stop-Transcript;exit 1
    }
}

# Check the currently installed version
Write-Host "Checking for old version..."
$Installed = Get-ItemProperty HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\* -ErrorAction SilentlyContinue |
    Where-Object { $_.DisplayName -match "NAP Locked Down Browser" }

if (-not $Installed -and [Environment]::Is64BitOperatingSystem) {
    $Installed = Get-ItemProperty HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\* -ErrorAction SilentlyContinue |
        Where-Object { $_.DisplayName -match "NAP Locked Down Browser" }
}
if ($Installed) {
    Write-Host "Installed Version: $($Installed.DisplayVersion)"
    Write-Host "Installed GUID: $($Installed.PSChildName)"  # GUID of the installed app
    $InstalledGUID = $($Installed.PSChildName)
    $OldVersion = $($Installed.DisplayVersion)
    } else {
    Write-Host "No InstallLocation property found or NAP Locked Down Browser is not installed."
}

$currentDate | Out-File -FilePath "$NaplanLastUpdate-Check.log" -Append -Encoding utf8

# Compare versions and proceed only if an update is needed
if ($ForceUpdate -or $OldVersion -ne $RemoteVersion) {
    # Uninstall old version
    if ($ForceUpdate -and $Installed) {
    Write-Host "Force update called. Installing new version"
    
    }   
    if ($InstalledGUID) {
        Write-Host "Removing old version: $InstalledGUID"
        Start-Process "msiexec.exe" -ArgumentList "/X $InstalledGUID /qn /norestart" -NoNewWindow -Wait
        #Nap Nuke
        Write-Host "Calling clean-up of old versions of Naplan"
        irm  -UseBasicParsing -Uri "$napnukeurl" | iex
    }
    Write-Host "InternetAvailable = $InternetAvailable"
    Write-Host "Downloading and Installing from Url: $URL"
    
    if ($InternetAvailable -and $URL) {
        Write-Host "Downloading latest version from: $URL"
        (New-Object System.Net.WebClient).DownloadFile($URL, $Setup)
    } elseif (Test-Path $FallbackSMB) {
        Write-Host "Internet unavailable. Installing from local SMB: $FallbackSMB"
        Copy-Item "$FallbackSMB" -Destination "$Setup" -Force
    } else {
        Write-Host "No valid installation source found. Exiting."
         Stop-Transcript;exit 1
    }
    $signature = Get-AuthenticodeSignature -FilePath "$Setup"

    
    if ($signature.Status -ne "Valid" -or $signature.SignerCertificate.Subject -notlike "*JANISON SOLUTIONS PTY LTD*") {
    Write-Host "WARNING: MSI is NOT signed by ACARA(JANISON). Exiting."
     Stop-Transcript;exit 1
}

    Write-Host "MSI is signed by a trusted entity and signature is valid. Proceeding with installation..."
    # Install the MSI
    Write-Host "Installing Naplan..."
    # Start the MSI installation and capture the process object
    $installProcess = Start-Process "msiexec.exe" -ArgumentList "/i `"$Setup`" /qn /norestart" -NoNewWindow -PassThru
    
    # Wait for the process to exit
    Write-Host "Waiting for installation to complete..."
    $installProcess.WaitForExit()

    # Define the firewall rule name
     $RuleName = "NAPLockedDownBrowserOutbound"

    # Try to find the install path from the registry (32-bit and 64-bit locations)
     $RegistryPaths = @(
    "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\NAPLockedDownBrowser",
    "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\NAPLockedDownBrowser"
)

$AppPath = $null

foreach ($RegPath in $RegistryPaths) {
    if (Test-Path $RegPath) {
        $InstallLocation = (Get-ItemProperty -Path $RegPath).InstallLocation
        if ($InstallLocation) {
            $AppPath = Join-Path -Path $InstallLocation -ChildPath "NAP Locked Down Browser.exe"
            break
        }
    }
}

# Fallback paths (if registry doesn't contain install path)
if (-not $AppPath -or -not (Test-Path $AppPath)) {
    $FallbackPaths = @(
    "${env:ProgramFiles(x86)}\NAP Locked Down Browser\NAP Locked Down Browser.exe",
    "$env:ProgramFiles\NAP Locked Down Browser\NAP Locked Down Browser.exe"
)

    foreach ($Path in $FallbackPaths) {
        if (Test-Path $Path) {
            $AppPath = $Path
            break
        }
    }
}

# Check if we have a valid path before adding firewall rule
if ($AppPath -and (Test-Path $AppPath)) {

    # Log it as installed 
    $currentDateString = Get-Date -Format "yyyyMMdd"
    $currentDateString | Set-Content -Path $lastUpdateFile -Force
    
    # Check if the rule already exists
    $ruleExists = Get-NetFirewallRule -DisplayName $RuleName -ErrorAction SilentlyContinue

    if (-not $ruleExists) {
        New-NetFirewallRule -DisplayName $RuleName `
                            -Description "Outbound rule for NAP Locked Down Browser" `
                            -Program $AppPath `
                            -Direction Outbound `
                            -Action Allow `
                            -Profile Any

        Write-Host "Outbound rule for NAP Locked Down Browser has been added."
    } else {
        Write-Host "Firewall rule '$RuleName' already exists. No action taken."
    }
} else {
    Write-Host "Could not determine NAPLAN LDB install location. Firewall rule NOT added."
    }

    # Clean up MSI file after installation completes
    Write-Host "Installation completed. Cleaning up..."
    Remove-Item "$Setup" -Force -ErrorAction SilentlyContinue -Verbose
    Write-Host "Refreshing icon cache..."

    ## Refreshing icon cache option 1
    
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

    ## Refreshing icon cache option 2
    
    #ie4uinit.exe -ClearIconCache
    #& ie4uinit.exe -show

    #Write-Host "Restarting Windows Explorer..."
    #Stop-Process -Name "explorer" -Force -ErrorAction SilentlyContinue
    #Start-Process "explorer.exe"

    ## Refreshing icon cache option 3
    
    (New-Object -ComObject Shell.Application).MinimizeAll()
    Start-Sleep -Milliseconds 500
    ie4uinit.exe -ClearIconCache
    (New-Object -ComObject Shell.Application).UndoMinimizeAll()
} 
    Write-Host "Update completed. Next update will be checked in $updateIntervalDays days."
} else {
    Write-Host "No update needed. Last update was within the required interval."
}

if ($Updatetasktoo) {
    Write-Host "Self updating the scheduled task is set. Updating scheduled task."

    # Properly formatted script block
    $scriptBlock = @"
        Start-Sleep 5
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
        irm -UseBasicParsing -Uri $scheduledtaskurl | iex
"@

    # Corrected Start-Process call
    Start-Process "powershell.exe" -WindowStyle Hidden -ArgumentList "-NoProfile -ExecutionPolicy Bypass -Command `"$scriptBlock`""
}

# Stop the transcript only if it was started
Stop-ConditionalTranscript
