# Get the system proxy settings from the registry
$proxySettings = Get-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Internet Settings"

# Check if a static proxy is enabled
if ($proxySettings.ProxyEnable -eq 1) {
    $proxyAddress = $proxySettings.ProxyServer
    Write-Host "🌐 Using system proxy: $proxyAddress"

    # Set PowerShell to use the detected proxy
    [System.Net.WebRequest]::DefaultWebProxy = New-Object System.Net.WebProxy($proxyAddress, $true)
    [System.Net.WebRequest]::DefaultWebProxy.Credentials = [System.Net.CredentialCache]::DefaultNetworkCredentials

} elseif ($proxySettings.AutoConfigURL) {
    $pacUrl = $proxySettings.AutoConfigURL
    Write-Host "🌐 Using PAC file: $pacUrl"

    # Try to download the PAC file (parsing not implemented)
try {
    $pacContent = Invoke-WebRequest -Uri $pacUrl -UseBasicParsing -ErrorAction Stop
    $pacText = [System.Text.Encoding]::UTF8.GetString($pacContent.Content)

    # Debugging: Print first 500 characters of PAC file
    Write-Host "PAC File Content (first 500 chars):"
    Write-Host $pacText.Substring(0, [math]::Min(500, $pacText.Length))

} catch {
    Write-Host "❌ Failed to retrieve PAC file: $_"
    exit 1
}

# Extract all proxy occurrences
$matches = [regex]::Matches($pacText, "(?i)(PROXY|SOCKS5?)\s+([\w\.-]+):(\d+)")

if ($matches.Count -gt 0) {
    # Get the last full match (proxy name/IP + port)
    $lastProxy = "$($matches[$matches.Count - 1].Groups[2].Value):$($matches[$matches.Count - 1].Groups[3].Value)"
    Write-Host "🌐 Last Proxy Found: $lastProxy"
} else {
    Write-Host "❌ No valid proxies found in PAC file."
}
        
    } catch {
        Write-Host "❌ Failed to retrieve PAC file."
    }

} else {
    Write-Host "✅ No proxy configured, using direct connection."
}














try {
    $pacContent = Invoke-WebRequest -Uri $pacUrl -UseBasicParsing -ErrorAction Stop
    $pacText = [System.Text.Encoding]::UTF8.GetString($pacContent.Content)

    # Debugging: Print first 500 characters of PAC file
    Write-Host "PAC File Content (first 500 chars):"
    Write-Host $pacText.Substring(0, [math]::Min(500, $pacText.Length))

} catch {
    Write-Host "❌ Failed to retrieve PAC file: $_"
    exit 1
}

# Extract all proxy occurrences
$matches = [regex]::Matches($pacText, "(?i)(PROXY|SOCKS5?)\s+([\w\.-]+):(\d+)")

if ($matches.Count -gt 0) {
    # Get the last full match (proxy name/IP + port)
    $lastProxy = "$($matches[$matches.Count - 1].Groups[2].Value):$($matches[$matches.Count - 1].Groups[3].Value)"
    Write-Host "🌐 Last Proxy Found: $lastProxy"
} else {
    Write-Host "❌ No valid proxies found in PAC file."
}
