[System.Net.WebRequest]::DefaultWebProxy = $null

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
            [System.Net.WebRequest]::DefaultWebProxy = New-Object System.Net.WebProxy($proxyAddress, $true)
            [System.Net.WebRequest]::DefaultWebProxy.Credentials = [System.Net.CredentialCache]::DefaultNetworkCredentials
            Write-Host "Proxy configured successfully (System-wide)."
        } catch {
            Write-Host "Failed to set system-wide proxy: $_"
        }
    }
    elseif ($SystemProxySettings.AutoConfigURL) {
        $pacUrl = $SystemProxySettings.AutoConfigURL.Trim()
        Write-Host "Using System-wide PAC file: $pacUrl"
        $proxySettings = $SystemProxySettings
    }
}

# If system-wide proxy is found, we **skip user-specific checks**
if ($proxySettingsgs) {
    Write-Host "Using System-wide Proxy settings. Skipping user-specific lookup."
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
        [System.Net.WebRequest]::DefaultWebProxy = New-Object System.Net.WebProxy($proxyAddress, $true)
        [System.Net.WebRequest]::DefaultWebProxy.Credentials = [System.Net.CredentialCache]::DefaultNetworkCredentials
        Write-Host "Proxy configured successfully."
    } catch {
        Write-Host "Failed to set proxy: $_"
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
                [System.Net.WebRequest]::DefaultWebProxy = New-Object System.Net.WebProxy($lastProxy, $true)
                [System.Net.WebRequest]::DefaultWebProxy.Credentials = [System.Net.CredentialCache]::DefaultNetworkCredentials
                Write-Host "Proxy set successfully from PAC file."
            } else {
                Write-Host "No valid proxies found in PAC file."
            }
        } else {
            Write-Host "PAC file is empty."
        }
    }
    catch {
        Write-Host "Failed to retrieve PAC file: $_"
    }
}
else {
    Write-Host "No proxy configured, using direct connection."
}
