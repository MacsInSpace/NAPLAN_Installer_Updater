# Uninstall NAPLAN Update Scheduled Task
# Run this with 
# You may need to enable TLS for secure downloads on PS version 5ish
# [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12;
# irm -UseBasicParsing -Uri "https://raw.githubusercontent.com/MacsInSpace/NAPLAN_Installer_Updater/refs/heads/main/Windows/bin/NukeNAPLANScheduledTask.ps1" | iex

Start-Transcript -Path "C:\Windows\Temp\NaplanNukeScheduledTask.log" -Append

$TaskName = "InstallNaplan"
$BranchName = "main"

# Check if the task exists
$task = Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue

if ($task) {
    Write-Host "Task '$TaskName' found. Removing..."
    Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false
} else {
    Write-Host "Task '$TaskName' does not exist. Skipping removal."
}

[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12;irm -UseBasicParsing -Uri "https://raw.githubusercontent.com/MacsInSpace/NAPLAN_Installer_Updater/refs/heads/$BranchName/Windows/bin/NAPLANnuke.ps1" | iex

$RuleName = "NAPLockedDownBrowserOutbound"

# Check if the rule exists before removing it
$ruleExists = Get-NetFirewallRule -DisplayName $RuleName -ErrorAction SilentlyContinue

if ($ruleExists) {
    Remove-NetFirewallRule -DisplayName $RuleName
    Write-Host "Firewall rule '$RuleName' has been removed."
} else {
    Write-Host "Firewall rule '$RuleName' does not exist. No action taken."
}

# Define paths
$StoragePath = Join-Path $env:ProgramData "Naplan"

# Run Proxy Script if it exists
if (Test-Path "$StoragePath") {
    try {
        Write-Host "Removing Path: $StoragePath"
        Stop-Transcript
        Remove-Item -Path $StoragePath -Recurse -Force
    } catch {
        Write-Host "Failed to remove $StoragePath"
    }
} else {
    Write-Host "Nothing found at: $StoragePath. Skipping removal."
    Stop-Transcript
}

Stop-Transcript
