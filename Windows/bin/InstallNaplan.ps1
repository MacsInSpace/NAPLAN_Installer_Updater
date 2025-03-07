# installs the latest version
# run *THIS* with:
# You may need to enable TLS for secure downloads on PS version 5ish
# [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12;
# irm -UseBasicParsing -Uri "https://raw.githubusercontent.com/MacsInSpace/NAPLAN_Installer_Updater/refs/heads/testing/Windows/bin/InstallNaplan.ps1" | iex

Start-Transcript -Path "$env:windir\Temp\NaplanInstall.log" -Append

# Define the fallback local SMB path (only used if the internet check fails)
$FallbackSMB = "\\XXXXWDS01\Deploymentshare$\Applications\Naplan.msi"
$ForceUpdate = $false #true will force the update regardless of version number
$Updatetasktoo = $true #true will force the update task also.
$BranchName = "testing"

# NAPLAN key dates page
$kdurl = "https://www.nap.edu.au/naplan/key-dates"

# NAPLAN downloads page
$dlurls = "https://www.assessform.edu.au/naplan-online/locked-down-browser"

$napnukeurl = "https://raw.githubusercontent.com/MacsInSpace/NAPLAN_Installer_Updater/refs/heads/$BranchName/Windows/bin/NAPLANnuke.ps1"

$scheduledtaskurl = "https://raw.githubusercontent.com/MacsInSpace/NAPLAN_Installer_Updater/refs/heads/$BranchName/Windows/bin/NAPLANscheduledtask.ps1"

$lastUpdateFile = "$env:windir\Temp\NaplanLastUpdate.txt"

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

# Set download directory for SYSTEM compatibility
$LocalTempDir = "$env:Windir\Temp"
$Setup = Join-Path $LocalTempDir "Naplan_Setup.msi"
Write-Host "Force Update NAPLAN set to: $ForceUpdate "
Write-Host "Update scheduled task set to: $Updatetasktoo"

[System.Net.WebRequest]::DefaultWebProxy = $null
netsh winhttp reset proxy

# Step 1: Check System-wide Proxy (HKLM)
$SystemProxyPath = "Registry::HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\Internet Settings"
$SystemProxySettings = Get-ItemProperty -Path $SystemProxyPath -ErrorAction SilentlyContinue

if ($SystemProxySettings) {
    if ($SystemProxySettings.ProxyEnable -eq 1 -and $SystemProxySettings.ProxyServer) {
        $proxyAddress = $SystemProxySettings.ProxyServer.Trim()
        Write-Host "System-wide Proxy Detected: $proxyAddress"

        if ($proxyAddress -notmatch "^(http|https)://") {
            $proxyAddress = "http://$proxyAddress"
        }

        try {
            netsh winhttp set proxy proxy-server="$proxyAddress"
            [System.Net.WebRequest]::DefaultWebProxy = New-Object System.Net.WebProxy($proxyAddress, $true)
            [System.Net.WebRequest]::DefaultWebProxy.Credentials = [System.Net.CredentialCache]::DefaultNetworkCredentials
            Write-Host "Proxy configured successfully (System-wide)."
        } catch {
            Write-Host "Failed to set system-wide proxy: $_"
            [System.Net.WebRequest]::DefaultWebProxy = $null
                netsh winhttp reset proxy
        }
    }
    elseif ($SystemProxySettings.AutoConfigURL) {
        $pacUrl = $SystemProxySettings.AutoConfigURL.Trim()
        Write-Host "Using System-wide PAC file: $pacUrl"
        $proxySettings = $SystemProxySettings
    }
}

# If system-wide proxy is found, we **skip user-specific checks**
if ($SystemProxySettings -and ($SystemProxySettings.ProxyEnable -eq 1 -or $SystemProxySettings.AutoConfigURL)) {
    Write-Host "Using system-wide proxy."

    if ($SystemProxySettings.ProxyEnable -eq 1 -and $SystemProxySettings.ProxyServer) {
        $proxyAddress = $SystemProxySettings.ProxyServer.Trim()
        if ($proxyAddress -notmatch "^(http|https)://") {
            $proxyAddress = "http://$proxyAddress"
        }
        netsh winhttp set proxy proxy-server="$proxyAddress"
        [System.Net.WebRequest]::DefaultWebProxy = New-Object System.Net.WebProxy($proxyAddress, $true)
        [System.Net.WebRequest]::DefaultWebProxy.Credentials = [System.Net.CredentialCache]::DefaultNetworkCredentials
        Write-Host "✅ Static Proxy set: $proxyAddress"
    }
    elseif ($SystemProxySettings.AutoConfigURL) {
        $pacUrl = $SystemProxySettings.AutoConfigURL.Trim()
        Write-Host "🌍 PAC file detected: $pacUrl"
        
        try {
            $pacContent = Invoke-WebRequest -Uri $pacUrl -UseBasicParsing -ErrorAction Stop
            Write-Host "📄 PAC file retrieved successfully."

            # Extract proxy settings from PAC file
            $pacText = [System.Text.Encoding]::UTF8.GetString($pacContent.Content)
            $ProxyPattern = "(?i)\b(PROXY|SOCKS5?)\s+([\w\.-]+):(\d+)\b"
            $ProxyMatches = [regex]::Matches($pacText, $ProxyPattern)

            if ($ProxyMatches.Count -gt 0) {
                $proxies = $ProxyMatches | ForEach-Object { "$($_.Groups[2].Value):$($_.Groups[3].Value)" }
                $lastProxy = $proxies | Select-Object -Last 1

                if ($lastProxy -and $lastProxy -notmatch "^http") {
                    $lastProxy = "http://$lastProxy"
                }
                netsh winhttp set proxy proxy-server="$lastProxy"
                [System.Net.WebRequest]::DefaultWebProxy = New-Object System.Net.WebProxy($lastProxy, $true)
                [System.Net.WebRequest]::DefaultWebProxy.Credentials = [System.Net.CredentialCache]::DefaultNetworkCredentials
                Write-Host "✅ Proxy set from PAC file: $lastProxy"
            }
            else {
                Write-Host "⚠️ No valid proxies found in PAC file."
                [System.Net.WebRequest]::DefaultWebProxy = $null
                netsh winhttp reset proxy
            }
        } catch {
            Write-Host "❌ Failed to retrieve PAC file: $_"
            [System.Net.WebRequest]::DefaultWebProxy = $null
            netsh winhttp reset proxy
        }
    }
exit 0
}

# Step 2: Check Currently Logged-in User
$LoggedInUser = Get-WmiObject -Class Win32_ComputerSystem | Select-Object -ExpandProperty UserName
$UserSID = $null

if ($LoggedInUser) {
    $LoggedInUserShort = $LoggedInUser -replace '^.*\\'  # Remove domain or computer name
    Write-Host "Detected Logged-in User: $LoggedInUserShort"

    # Find the corresponding SID
    $UserSID = (Get-Item "Registry::HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows NT\CurrentVersion\ProfileList\*") |
        Where-Object { $_.GetValue("ProfileImagePath") -match "\\$LoggedInUserShort$" } |
        Select-Object -ExpandProperty PSChildName -First 1
}

# Step 3: If no logged-in user, fallback to last created real user profile
if (-not $UserSID) {
    Write-Host "No interactive user detected. Falling back to last created user profile."

    $Profiles = Get-ChildItem "Registry::HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows NT\CurrentVersion\ProfileList" |
        ForEach-Object {
            $ProfileSID = $_.PSChildName
            $ProfilePath = $_.GetValue("ProfileImagePath")

            # Skip SYSTEM, LOCAL SERVICE, and NETWORK SERVICE
            if ($ProfileSID -notmatch "S-1-5-(18|19|20)") {
                [PSCustomObject]@{
                    SID         = $ProfileSID
                    ProfilePath = $ProfilePath
                }
            }
        } | Sort-Object SID -Descending | Select-Object -First 1  # Get last created SID

    if ($Profiles) {
        $UserSID = $Profiles.SID
        Write-Host "Falling back to last real user: $($Profiles.ProfilePath)"
    } else {
        Write-Host "No real user profiles found!"
        [System.Net.WebRequest]::DefaultWebProxy = $null
        netsh winhttp reset proxy
        exit 0
    }
}

# Step 4: Define Registry Paths
$UserHivePath = "Registry::HKEY_USERS\$UserSID\Software\Microsoft\Windows\CurrentVersion\Internet Settings"
$GPOPath = "Registry::HKEY_USERS\$UserSID\Software\Policies\Microsoft\Windows\CurrentVersion\Internet Settings"

Write-Host "Using User SID: $UserSID"

# Step 5: Check for GPO-Enforced Proxy First
$proxySettings = Get-ItemProperty -Path $GPOPath -ErrorAction SilentlyContinue
$GPOEnforced = $false
if ($proxySettings) {
    Write-Host "GPO Proxy settings detected!"
    $GPOEnforced = $true
} else {
    # Step 6: If no GPO proxy, check user-defined proxy settings
    $proxySettings = Get-ItemProperty -Path $UserHivePath -ErrorAction SilentlyContinue
}

if (-not $proxySettings) {
    Write-Host "No proxy settings found for user."
    [System.Net.WebRequest]::DefaultWebProxy = $null
    netsh winhttp reset proxy
    exit 0
}

# Step 7: Detect Static Proxy (Manual)
if ($proxySettings.ProxyEnable -eq 1 -and $proxySettings.ProxyServer) {
    $proxyAddress = $proxySettings.ProxyServer.Trim()
    Write-Host "Proxy Detected: $proxyAddress (Source: $(if ($GPOEnforced) { 'GPO' } else { 'User' }))"

    if ($proxyAddress -notmatch "^(http|https)://") {
        $proxyAddress = "http://$proxyAddress"
    }

    try {
        netsh winhttp set proxy proxy-server="$proxyAddress"
        [System.Net.WebRequest]::DefaultWebProxy = New-Object System.Net.WebProxy($proxyAddress, $true)
        [System.Net.WebRequest]::DefaultWebProxy.Credentials = [System.Net.CredentialCache]::DefaultNetworkCredentials
        Write-Host "Proxy configured successfully."
    } catch {
        Write-Host "Failed to set proxy: $_"
        [System.Net.WebRequest]::DefaultWebProxy = $null
        netsh winhttp reset proxy
    }
}

# Step 8: PAC File Handling
elseif ($proxySettings.AutoConfigURL) {
    $pacUrl = $proxySettings.AutoConfigURL.Trim()
    Write-Host "Using PAC file: $pacUrl"

    try {
        $pacContent = Invoke-WebRequest -Uri $pacUrl -UseBasicParsing -ErrorAction Stop
        Write-Host "PAC file retrieved successfully."

        #$pacText = [System.Text.Encoding]::UTF8.GetString($pacContent.Content)
                  if ($pacContent.Content -is [byte[]]) {
            $pacText = [System.Text.Encoding]::UTF8.GetString($pacContent.Content)
        } else {
            $pacText = $pacContent.Content
        }

        if ($pacText.Length -gt 0) {
            # Define regex pattern to capture "PROXY" or "SOCKS5" followed by hostname/IP and port
            $ProxyPattern = "(?i)\b(PROXY|SOCKS5?)\s+([\w\.-]+):(\d+)\b"


            # Extract proxy matches from PAC file content
            $ProxyMatches = [regex]::Matches($pacText, $ProxyPattern)

            if ($ProxyMatches.Count -gt 0) {
                # Process matches correctly
                $proxies = $ProxyMatches | ForEach-Object {
                    "$($_.Groups[2].Value):$($_.Groups[3].Value)"
                }

                # Get the last valid proxy found
                $lastProxy = $proxies | Select-Object -Last 1

                Write-Host "Last Proxy Found: $lastProxy"

                # Ensure the last proxy is formatted correctly
                if ($lastProxy -and $lastProxy -notmatch "^http") {
                    $lastProxy = "http://$lastProxy"
                }

                # Set the proxy
                netsh winhttp set proxy proxy-server="$lastProxy"
                [System.Net.WebRequest]::DefaultWebProxy = New-Object System.Net.WebProxy($lastProxy, $true)
                [System.Net.WebRequest]::DefaultWebProxy.Credentials = [System.Net.CredentialCache]::DefaultNetworkCredentials
                Write-Host "Proxy set successfully from PAC file."
            } else {
                Write-Host "No valid proxies found in PAC file."
                [System.Net.WebRequest]::DefaultWebProxy = $null
                netsh winhttp reset proxy
            }
        } else {
            Write-Host "PAC file is empty."
            [System.Net.WebRequest]::DefaultWebProxy = $null
            netsh winhttp reset proxy
        }
    }
    catch {
        Write-Host "Failed to retrieve PAC file: $_"
        [System.Net.WebRequest]::DefaultWebProxy = $null
        netsh winhttp reset proxy
    }
}
else {
    Write-Host "No proxy configured, using direct connection."
}

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

# Get the current year dynamically
$currentYear = (Get-Date).Year

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
    $testStartDate = Get-Date "$currentYear-03-1"  # Approximate fallback
    $testEndDate = Get-Date "$currentYear-04-30"
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
    $testStartDate = Get-Date "$currentYear-03-1"  # Approximate fallback
    $testEndDate = Get-Date "$currentYear-04-30"
}
}
# --- Now use these dates for update logic ---
$currentDate = Get-Date

# If today falls in the test window, log and exit
if ($currentDate -ge $testStartDate -and $currentDate -le $testEndDate) {
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

# Read the last update date from the file
if (Test-Path $lastUpdateFile) {
    $lastUpdateString = (Get-Content $lastUpdateFile) -match "\S" | Select-Object -Last 1
    $lastUpdate = [datetime]::ParseExact($lastUpdateString, "dddd, d MMMM yyyy h:mm:ss tt", $null)
    $daysSinceLastUpdate = ($currentDate - $lastUpdate).Days

    if ($daysSinceLastUpdate -ge $updateIntervalDays) {
        $updateNeeded = $true
    }
} else {
    $updateNeeded = $true
}

# Perform update if needed
if ($updateNeeded) {
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
    (New-Object -ComObject Shell.Application).UndoMinimizeAll()
    
    Write-Host "Icon refresh complete."
    
} 

    $currentDate | Out-File -FilePath $lastUpdateFile -Encoding utf8
    Write-Host "Update completed. Next update will be checked in $updateIntervalDays days."
} else {
    Write-Host "No update needed. Last update was within the required interval."
}

if ($Updatetasktoo) {
    Write-Host "Self updating the scheduled task is set. Updating scheduled task."
    
    $scriptBlock = @'
        Start-Sleep 5
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
        irm -UseBasicParsing -Uri "$scheduledtaskurl" | iex
'@
    Start-Process "powershell.exe" -WindowStyle Hidden -ArgumentList "-NoProfile -ExecutionPolicy Bypass -Command $scriptBlock"
}

Stop-Transcript
