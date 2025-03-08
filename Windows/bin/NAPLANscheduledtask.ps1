# Function to check if a transcript is running
function Start-ConditionalTranscript {
    if ($global:transcript -eq $true) {
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
    $global:transcript = $false
}

# Call the function to conditionally start transcript
Start-ConditionalTranscript

# Install NAPLAN Update Scheduled Task
$TaskName = "InstallNaplan"
$BranchName = "testing"
$TaskDescription = "Installs the latest version of Naplan"
$ScriptURL = "https://raw.githubusercontent.com/MacsInSpace/NAPLAN_Installer_Updater/refs/heads/$BranchName/Windows/bin/InstallNaplan.ps1"
$ProxyURL = "https://raw.githubusercontent.com/MacsInSpace/NAPLAN_Installer_Updater/refs/heads/$BranchName/Windows/bin/proxy.ps1"

# Define the storage path
$StoragePath = Join-Path $env:ProgramData "Naplan"
$ProxyScriptPath = Join-Path $StoragePath "proxy.ps1"

# Ensure the directory exists
if (-not (Test-Path $StoragePath)) {
    New-Item -ItemType Directory -Path $StoragePath -Force | Out-Null
    Write-Host "Created directory: $StoragePath"
}

# Set permissions (SYSTEM and Administrators: FullControl)
$acl = Get-Acl $StoragePath
$rule = New-Object System.Security.AccessControl.FileSystemAccessRule("SYSTEM", "FullControl", "ContainerInherit, ObjectInherit", "None", "Allow")
$acl.AddAccessRule($rule)

$rule = New-Object System.Security.AccessControl.FileSystemAccessRule("Administrators", "FullControl", "ContainerInherit, ObjectInherit", "None", "Allow")
$acl.AddAccessRule($rule)

Set-Acl -Path $StoragePath -AclObject $acl
Write-Host "Permissions set: SYSTEM and Administrators have FullControl"

# Download the proxy script
try {
    Invoke-WebRequest -Uri $ProxyURL -OutFile $ProxyScriptPath -UseBasicParsing
    Write-Host "Proxy script downloaded successfully: $ProxyScriptPath"
} catch {
    Write-Host "Failed to download proxy script: $_"
}

# Create the script file to run the command
$PowerShellCommand = @"
Write-Host `"Running live Naplan installer scheduled task...`"

# Function to check if a transcript is running
function Start-ConditionalTranscript {
    if (`$global:transcript -eq `$true) {
        Write-Host `"Transcript is already running. Skipping Start-Transcript.`"
    } else {
        Start-Transcript -Path `"`$env:windir\Temp\NaplanInstallScheduledTask.log`" -Append
        `$global:transcript = `$true  # Mark transcript as active
    }
}

# Function to stop transcript safely
function Stop-ConditionalTranscript {
    try {
        Stop-Transcript
    } catch {
        Write-Host `"No active transcript to stop.`"
    }
    `$global:transcript = `$false
}

# Call the function to conditionally start transcript
Start-ConditionalTranscript

# Ensure TLS 1.2 is used for secure connections
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

# Define paths
`$StoragePath = Join-Path `$env:ProgramData `"Naplan`"
`$ProxyScriptPath = Join-Path `$StoragePath `"proxy.ps1`"

# Run Proxy Script if it exists
if (Test-Path `"`$ProxyScriptPath`") {
    try {
        Write-Host `"Executing Proxy Script: `$ProxyScriptPath`"
        Start-Process -FilePath `"powershell.exe`" -ArgumentList `"-ExecutionPolicy Bypass  -NoNewWindow -WindowStyle Hidden -File `$ProxyScriptPath`"
    } catch {
        Write-Host `"Failed to execute proxy script: `$_`"
        exit 1
    }
} else {
    Write-Host `"Proxy script not found at: `$ProxyScriptPath. Skipping.`"
}

# Run the main NAPLAN script
try {
    Write-Host `"Fetching and running NAPLAN installer script...`"
    Invoke-WebRequest -UseBasicParsing -Uri `""$ScriptURL"`" | Invoke-Expression
} catch {
    Write-Host `"Scheduled Task failed to retrieve or execute the script: `$_`"
    exit 1
}
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

if (Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue) {
    Write-Host "Scheduled task '$TaskName' has been updated."
    Stop-Transcript
} else {
    # New task starts immediately
    Write-Host "Scheduled task '$TaskName' has been added and will start shortly."
    Start-Sleep 3
    
    # Start the scheduled task in a detached process
    Start-Process -FilePath "schtasks.exe" -ArgumentList "/Run /TN `"$TaskName`"" -WindowStyle Hidden
}

# Stop the transcript only if it was started
Stop-ConditionalTranscript
