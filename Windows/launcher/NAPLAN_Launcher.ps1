
# Function to check if NAPLAN LDB is running
function Test-NaplanLDBRunning {
    $process = Get-Process | Where-Object { $_.ProcessName -match "NAP Locked Down Browser" }
    return $process -ne $null
}

# Function to check if system volume is unmuted and set it to 75%
function Set-Volume {
    $volume = (Get-VolumeMixer).MasterVolume
    if ($volume -eq 0) {
        Write-Host "Unmuting volume..."
        (Get-VolumeMixer).Mute = $false
    }
    Write-Host "Setting volume to 75%..."
    (Get-VolumeMixer).MasterVolume = 75
}

# Function to check internet connectivity
function Test-Internet {
    $ping = Test-Connection -ComputerName 8.8.8.8 -Count 1 -Quiet
    if (-not $ping) {
        [System.Windows.Forms.MessageBox]::Show("No internet connection detected. Please check your connection and try again.", "Internet Check", 0, 48)
    }
    return $ping
}

# Function to check battery level
function Test-BatteryLevel {
    $battery = Get-WmiObject Win32_Battery | Select-Object -ExpandProperty EstimatedChargeRemaining
    $charging = Get-WmiObject Win32_Battery | Select-Object -ExpandProperty BatteryStatus

    if ($battery -lt 50 -and $charging -ne 2) {
        [System.Windows.Forms.MessageBox]::Show("Battery is below 50%. Please plug in your charger.", "Battery Check", 0, 48)
        return $false
    }
    return $true
}

# Function to check screen resolution
function Test-Resolution {
    $screen = [System.Windows.Forms.Screen]::PrimaryScreen.Bounds
    $minWidth = 1024
    $minHeight = 768

    if ($screen.Width -lt $minWidth -or $screen.Height -lt $minHeight) {
        [System.Windows.Forms.MessageBox]::Show("Screen resolution is below recommended settings. Adjust resolution before launching.", "Resolution Check", 0, 48)
        return $false
    }
    return $true
}

# Function to prompt for headphones
function Prompt-Headphones {
    [System.Windows.Forms.MessageBox]::Show("Please plug in your headphones now.", "Audio Check", 0, 64)
}

# MAIN SCRIPT EXECUTION
Add-Type -TypeDefinition @"
using System;
using System.Runtime.InteropServices;
public class VolumeMixer {
    [DllImport("user32.dll")]
    public static extern bool PostMessage(IntPtr hWnd, uint Msg, IntPtr wParam, IntPtr lParam);
}
"@ -Name "VolumeMixer" -Namespace "System"

if (Test-NaplanLDBRunning) {
    Write-Host "NAPLAN LDB is already running."
    exit 1
}

Set-Volume
if (-not (Test-Internet)) { exit 1 }
if (-not (Test-BatteryLevel)) { exit 1 }
if (-not (Test-Resolution)) { exit 1 }

Prompt-Headphones

# Launch NAPLAN LDB
Start-Process "C:\Program Files (x86)\NAP Locked Down Browser\NAP Locked Down Browser.exe"
