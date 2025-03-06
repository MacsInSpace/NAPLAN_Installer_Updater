# Install NAPLAN Update Scheduled Task
# Run this with 
# You may need to enable TLS for secure downloads on PS version 5ish
# [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12;
# irm -UseBasicParsing -Uri "https://raw.githubusercontent.com/MacsInSpace/NAPLAN_Installer_Updater/refs/heads/testing/Windows/bin/NAPLANscheduledtask.ps1" | iex

Start-Transcript -Path "$env:windir\Temp\NaplanInstallScheduledTask.log" -Append

# Install NAPLAN Update Scheduled Task
$TaskName = "InstallNaplan"
$BranchName = "testing"
$TaskDescription = "Installs the latest version of Naplan"
$ScriptURL = "https://raw.githubusercontent.com/MacsInSpace/NAPLAN_Installer_Updater/refs/heads/$BranchName/Windows/bin/InstallNaplan.ps1"

# Create the script file to run the command
# Define the PowerShell script as a string
$PowerShellCommand = @"
Start-Transcript -Path "$env:windir\Temp\NaplantestingScheduledTask.log" -Append

[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

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

Write-Host "Running live Naplan installer scheduled task..."
try {
    Invoke-WebRequest -UseBasicParsing -Uri $ScriptURL | Invoke-Expression
    } catch {
    Write-Host "Scheduled Task failed to retrieve or execute the script: $_"
        Stop-Transcript;exit 1
}
Stop-Transcript
"@

# Encode the command in Base64
$EncodedCommand = [Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes($PowerShellCommand))

# Define the scheduled task command
$FullCommand = "powershell.exe -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -EncodedCommand $EncodedCommand"

# Create Scheduled Task Action
$Action = New-ScheduledTaskAction -Execute "cmd.exe" -Argument "/c $FullCommand"

# Create Triggers
$Triggers = @(
    $(New-ScheduledTaskTrigger -Daily -At (Get-Date -Hour (Get-Random -Minimum 9 -Maximum 16) -Minute (Get-Random -Minimum 0 -Maximum 59) -Second 0)),  # Runs daily at random time
    $(New-ScheduledTaskTrigger -AtStartup)  # Runs at startup if missed
)

# Define Task Settings
$Settings = New-ScheduledTaskSettingsSet `
    -AllowStartIfOnBatteries `
    -DontStopIfGoingOnBatteries `
    -StartWhenAvailable `
    -ExecutionTimeLimit (New-TimeSpan -Minutes 30) `
    -RunOnlyIfNetworkAvailable `
    -RestartCount 3 `
    -RestartInterval (New-TimeSpan -Minutes 60) `
    -MultipleInstances IgnoreNew

# Check if the Scheduled Task already exists
$ExistingTask = Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue

if ($ExistingTask) {
    Write-Host "Task '$TaskName' already exists. Updating..."
    Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false
} else {
    Write-Host "Creating scheduled task '$TaskName'..."
}

# Enable logging for Task Scheduler
wevtutil set-log Microsoft-Windows-TaskScheduler/Operational /enabled:true

# Set to run as SYSTEM
$Principal = New-ScheduledTaskPrincipal -UserId "SYSTEM" -LogonType ServiceAccount -RunLevel Highest

Register-ScheduledTask -TaskName $TaskName -Description $TaskDescription -Action $Action -Trigger $Triggers -Settings $Settings -Principal $Principal -Force

if ($ExistingTask) {
    Write-Host "Scheduled task '$TaskName' has been updated."
    Stop-Transcript
} else {
    # New task starts immediately
    Write-Host "Scheduled task '$TaskName' has been added and will start now."
    Stop-Transcript
    Start-Sleep 2
    # Start the scheduled task in a detached process
    Start-Process -FilePath "schtasks.exe" -ArgumentList "/Run /TN `"$TaskName`"" -WindowStyle Hidden

}

