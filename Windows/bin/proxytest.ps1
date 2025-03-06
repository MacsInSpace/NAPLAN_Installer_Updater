# Reset any existing proxy settings
[System.Net.WebRequest]::DefaultWebProxy = $null

# Get the system proxy settings from the registry
# $proxySettings = Get-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Internet Settings" -ErrorAction SilentlyContinue

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
    } | Sort-Object SID -Descending | Select-Object -First 1

if ($Profiles.SID) {
    $UserProxyPath = "Registry::HKEY_USERS\$($Profiles.SID)\Software\Microsoft\Windows\CurrentVersion\Internet Settings"
    $ProxySettings = Get-ItemProperty -Path $UserProxyPath -ErrorAction SilentlyContinue
} else {
    Write-Host "Unable to determine the most recent real user."
}

if (-not $proxySettings) {
    Write-Host "⚠️ Failed to retrieve proxy settings from registry. Using direct connection."
    exit 0
}

# Check if a static proxy is enabled
if ($proxySettings.ProxyEnable -eq 1 -and $proxySettings.ProxyServer) {
    $proxyAddress = $proxySettings.ProxyServer.Trim()

    Write-Host "🌐 System Proxy Detected: $proxyAddress"

    # Ensure the proxy URL has the correct format
    if ($proxyAddress -notmatch "^(http|https)://") {
        $proxyAddress = "http://$proxyAddress"
    }

    try {
        [System.Net.WebRequest]::DefaultWebProxy = New-Object System.Net.WebProxy($proxyAddress, $true)
        [System.Net.WebRequest]::DefaultWebProxy.Credentials = [System.Net.CredentialCache]::DefaultNetworkCredentials
        Write-Host "✅ Proxy configured successfully."
    } catch {
        Write-Host "❌ Failed to set proxy: $_"
    }
}
elseif ($proxySettings.AutoConfigURL) {
    $pacUrl = $proxySettings.AutoConfigURL.Trim()
    Write-Host "🌍 Using PAC file: $pacUrl"

    try {
        $pacContent = Invoke-WebRequest -Uri $pacUrl -UseBasicParsing -ErrorAction Stop
        Write-Host "📄 PAC file retrieved successfully."

        $pacText = [System.Text.Encoding]::UTF8.GetString($pacContent.Content).Trim()

        if ($pacText.Length -gt 0) {
            # Regex pattern to extract PROXY/SOCKS5 settings
            $ProxyPattern = "(?i)\b(PROXY|SOCKS5?)\s+([\w\.-]+):(\d+)\b"
            $ProxyMatches = [regex]::Matches($pacText, $ProxyPattern)

            if ($ProxyMatches.Count -gt 0) {
                # Process matches correctly
                $proxies = $ProxyMatches | ForEach-Object { "$($_.Groups[2].Value):$($_.Groups[3].Value)" }

                # Get the last valid proxy found
                $lastProxy = $proxies | Select-Object -Last 1

                Write-Host "🔎 Last Proxy Found: $lastProxy"

                # Ensure correct URL format
                if ($lastProxy -and $lastProxy -notmatch "^http") {
                    $lastProxy = "http://$lastProxy"
                }

                try {
                    [System.Net.WebRequest]::DefaultWebProxy = New-Object System.Net.WebProxy($lastProxy, $true)
                    [System.Net.WebRequest]::DefaultWebProxy.Credentials = [System.Net.CredentialCache]::DefaultNetworkCredentials
                    Write-Host "✅ Proxy set successfully from PAC file."
                } catch {
                    Write-Host "❌ Failed to apply proxy settings: $_"
                }
            }
            else {
                Write-Host "⚠️ No valid proxies found in PAC file."
            }
        }
        else {
            Write-Host "⚠️ PAC file is empty."
        }
    }
    catch {
        Write-Host "❌ Failed to retrieve PAC file: $_"
    }
}
else {
    Write-Host "🚀 No proxy configured, using direct connection."
}
