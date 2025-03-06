# Install NAPLAN Update Scheduled Task
# Run this with 
# You may need to enable TLS for secure downloads on PS version 5ish
# [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12;
# irm -UseBasicParsing -Uri "https://raw.githubusercontent.com/MacsInSpace/NAPLAN_Installer_Updater/refs/heads/testing/Windows/bin/NAPLANscheduledtask.ps1" | iex

Start-Transcript -Path "C:\Windows\Temp\NaplantestingScheduledTask.log" -Append

# Install NAPLAN Update Scheduled Task
$TaskName = "InstallNaplan"
$TaskDescription = "Installs the latest version of Naplan"
$ScriptURL = "https://raw.githubusercontent.com/MacsInSpace/NAPLAN_Installer_Updater/refs/heads/testing/Windows/bin/InstallNaplan.ps1"

# 🔹 Create the script file to run the command
# Define the PowerShell script as a string
$PowerShellCommand = @"
#Start-Transcript -Path "C:\Windows\Temp\NaplantestingScheduledTask.log" -Append

[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

Write-Host "Running live Naplan installer scheduled task..."
try {
    Invoke-WebRequest -UseBasicParsing -Uri $ScriptURL | Invoke-Expression
    } catch {
    Write-Host "Scheduled Task failed to retrieve or execute the script: $_"
        Stop-Transcript;exit 1
}
#Stop-Transcript
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

} else {
    # New task starts immediately
    Write-Host "Scheduled task '$TaskName' has been added and will start once now."
    Stop-Transcript
    Start-Sleep 2
    Start-ScheduledTask -TaskName $TaskName
}

exit 0

