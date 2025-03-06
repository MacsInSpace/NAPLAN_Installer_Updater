# Get the system proxy settings from the registry
$proxySettings = Get-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Internet Settings"

# Check if a static proxy is enabled
if ($proxySettings.ProxyEnable -eq 1) {
    $proxyAddress = $proxySettings.ProxyServer
    Write-Host "🌐 Using system proxy: $proxyAddress"

    # Ensure the proxy URL is in a valid format (add http:// if missing)
    if ($proxyAddress -notmatch "^http") {
        $proxyAddress = "http://$proxyAddress"
    }

    # Set PowerShell to use the detected proxy
    [System.Net.WebRequest]::DefaultWebProxy = New-Object System.Net.WebProxy($proxyAddress, $true)
    [System.Net.WebRequest]::DefaultWebProxy.Credentials = [System.Net.CredentialCache]::DefaultNetworkCredentials

}
elseif ($proxySettings.AutoConfigURL) {
    $pacUrl = $proxySettings.AutoConfigURL
    Write-Host "Using PAC file: $pacUrl"

    # Try to download the PAC file (parsing not implemented)
    try {
        $pacContent = Invoke-WebRequest -Uri $pacUrl -UseBasicParsing -ErrorAction Stop
        Write-Host "PAC file retrieved successfully."

        # Decode the PAC file content
        $pacText = [System.Text.Encoding]::UTF8.GetString($pacContent.Content)

        # Ensure PAC file is not empty before running regex
        if ($pacText.Length -gt 0) {
            # Extract all proxy occurrences
            $proxies = [regex]::Matches($pacText, "(?i)(PROXY|SOCKS5?)\s+([\w\.-]+):(\d+)") | 
            ForEach-Object { "$($_.Groups[2].Value):$($_.Groups[3].Value)" }

            # Get the last proxy found
            if ($proxies.Count -gt 0) {
                $lastProxy = $proxies | Select-Object -Last 1
                Write-Host "Last Proxy Found: $lastProxy"

                # Ensure the last proxy has the correct URL format (add http:// if missing)
                if ($lastProxy -notmatch "^http") {
                    $lastProxy = "http://$lastProxy"
                }

                # Set PowerShell to use the detected proxy
                [System.Net.WebRequest]::DefaultWebProxy = New-Object System.Net.WebProxy($lastProxy, $true)
                [System.Net.WebRequest]::DefaultWebProxy.Credentials = [System.Net.CredentialCache]::DefaultNetworkCredentials
            }
            else {
                Write-Host "No proxies found in PAC file."
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
