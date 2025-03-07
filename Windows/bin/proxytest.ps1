# Reset any existing proxy settings
netsh winhttp reset proxy
[System.Net.WebRequest]::DefaultWebProxy = $null


# Unset any existing PowerShell proxy
[System.Net.WebRequest]::DefaultWebProxy = $null

# Step 1: Get Last Created Real User Profile from Registry
$Profiles = Get-ChildItem "Registry::HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows NT\CurrentVersion\ProfileList" |
    ForEach-Object {
        $UserSID = $_.PSChildName
        $ProfilePath = $_.GetValue("ProfileImagePath")

        # Skip SYSTEM, LOCAL SERVICE, and NETWORK SERVICE
        if ($UserSID -notmatch "S-1-5-(18|19|20)") {
            [PSCustomObject]@{
                SID         = $UserSID
                ProfilePath = $ProfilePath
            }
        }
    } | Sort-Object SID -Descending | Select-Object -First 1  # Get last created SID

if (-not $Profiles) {
    Write-Host "No real user profiles found."
    exit 0
}

$UserSID = $Profiles.SID
$UserHivePath = "Registry::HKEY_USERS\$UserSID\Software\Microsoft\Windows\CurrentVersion\Internet Settings"
$GPOPath = "Registry::HKEY_USERS\$UserSID\Software\Policies\Microsoft\Windows\CurrentVersion\Internet Settings"

Write-Host "Detected Last Real User: $($Profiles.ProfilePath)"
Write-Host "User SID: $UserSID"

# Step 2: Check for GPO-Enforced Proxy First
$proxySettings = Get-ItemProperty -Path $GPOPath -ErrorAction SilentlyContinue
$GPOEnforced = $false
if ($proxySettings) {
    Write-Host "GPO Proxy settings detected."
    $GPOEnforced = $true
} else {
    # Step 3: If no GPO proxy, check user-defined proxy settings
    $proxySettings = Get-ItemProperty -Path $UserHivePath -ErrorAction SilentlyContinue
}

if (-not $proxySettings) {
    Write-Host "No proxy settings found for user."
    exit 0
}

# Step 4: Detect Static Proxy (Manual)
if ($proxySettings.ProxyEnable -eq 1 -and $proxySettings.ProxyServer) {
    $proxyAddress = $proxySettings.ProxyServer.Trim()
    Write-Host "Proxy Detected: $proxyAddress (Source: $(if ($GPOEnforced) { 'GPO' } else { 'User' }))"

    if ($proxyAddress -notmatch "^(http|https)://") {
        $proxyAddress = "http://$proxyAddress"
    }

    # Set PowerShell to use the detected proxy
    try {
        # Set the proxy
        netsh winhttp set proxy proxy-server="$proxyAddress"
        [System.Net.WebRequest]::DefaultWebProxy = New-Object System.Net.WebProxy($lastProxy, $true)
        [System.Net.WebRequest]::DefaultWebProxy.Credentials = [System.Net.CredentialCache]::DefaultNetworkCredentials
        Write-Host "Proxy configured successfully."
    } catch {
        Write-Host "Failed to set proxy: $_"
    }
}
# Step 5: PAC File Handling
elseif ($proxySettings.AutoConfigURL) {
    $pacUrl = $proxySettings.AutoConfigURL.Trim()
    Write-Host "Using PAC file: $pacUrl"

    try {
        $pacContent = Invoke-WebRequest -Uri $pacUrl -UseBasicParsing -ErrorAction Stop
        Write-Host "PAC file retrieved successfully."

        $pacText = [System.Text.Encoding]::UTF8.GetString($pacContent.Content)
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
                netsh winhttp set proxy proxy-server="$proxyAddress"
                [System.Net.WebRequest]::DefaultWebProxy = New-Object System.Net.WebProxy($lastProxy, $true)
                [System.Net.WebRequest]::DefaultWebProxy.Credentials = [System.Net.CredentialCache]::DefaultNetworkCredentials
                Write-Host "Proxy set successfully from PAC file."
            }
            else {
                Write-Host "No valid proxies found in PAC file."
            }
        }
        else {
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
