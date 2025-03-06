# Get the system proxy settings from the registry
$proxySettings = Get-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Internet Settings"

# Check if a static proxy is enabled
if ($proxySettings.ProxyEnable -eq 1) {
    $proxyAddress = $proxySettings.ProxyServer
    Write-Host "🌐 Using system proxy: $proxyAddress"

    # Set PowerShell to use the detected proxy
    [System.Net.WebRequest]::DefaultWebProxy = New-Object System.Net.WebProxy($proxyAddress, $true)
    [System.Net.WebRequest]::DefaultWebProxy.Credentials = [System.Net.CredentialCache]::DefaultNetworkCredentials

}
elseif ($proxySettings.AutoConfigURL) {
    $pacUrl = $proxySettings.AutoConfigURL
    Write-Host "🌐 Using PAC file: $pacUrl"

    # Try to download the PAC file (parsing not implemented)
    try {
        $pacContent = Invoke-WebRequest -Uri $pacUrl -UseBasicParsing
        Write-Host "✅ PAC file retrieved successfully."
        $pacText = [System.Text.Encoding]::UTF8.GetString($pacContent.Content)
        # Extract all occurrences of 'PROXY <IP/Domain>:<Port>' or 'SOCKS <IP/Domain>:<Port>'
        $proxies = [regex]::Matches($pacText, "(?i)(PROXY|SOCKS5?)\s+([\w\.-]+):(\d+)") | 
        ForEach-Object { "$($_.Groups[2].Value):$($_.Groups[3].Value)" }
        # Get the last proxy found
        $lastProxy = $proxies | Select-Object -Last 1
        if ($lastProxy) {
            Write-Host "🌐 Last Proxy Found: $lastProxy"
            # Set PowerShell to use the detected proxy
            [System.Net.WebRequest]::DefaultWebProxy = New-Object System.Net.WebProxy($lastProxy, $true)
            [System.Net.WebRequest]::DefaultWebProxy.Credentials = [System.Net.CredentialCache]::DefaultNetworkCredentials
        }
        else {
            Write-Host "❌ No proxies found in PAC file."
        }
        
    }
    catch {
        Write-Host "❌ Failed to retrieve PAC file."
    }

}
else {
    Write-Host "✅ No proxy configured, using direct connection."
}
