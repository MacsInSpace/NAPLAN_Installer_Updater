
# Function to check if NAPLAN LDB is running
function Test-NaplanLDBRunning {
    $process = Get-Process | Where-Object { $_.ProcessName -match "NAP Locked Down Browser" }
    return $process -ne $null
}

# Function to check if system volume is unmuted and set it to 75%
function Set-Volume {
    param (
        [Parameter(Mandatory = $true)]
        [ValidateRange(0, 100)]
        [int]$vol
    )

    # Convert percentage to scalar value (0.0 to 1.0)
    $volumeLevel = [math]::Round($vol / 100, 2)

    # Check if the type is already defined to prevent duplicate addition
    if (-not ("Audio" -as [type])) {
        $code = @"
using System;
using System.Runtime.InteropServices;

[Guid("5CDF2C82-841E-4546-9722-0CF74078229A"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
interface IAudioEndpointVolume {
    int f(); int g(); int h(); int i();
    int SetMasterVolumeLevelScalar(float fLevel, System.Guid pguidEventContext);
    int j();
    int GetMasterVolumeLevelScalar(out float pfLevel);
    int k(); int l(); int m(); int n();
    int SetMute([MarshalAs(UnmanagedType.Bool)] bool bMute, System.Guid pguidEventContext);
    int GetMute(out bool pbMute);
}

[Guid("D666063F-1587-4E43-81F1-B948E807363F"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
interface IMMDevice {
    int Activate(ref System.Guid id, int clsCtx, int activationParams, out IAudioEndpointVolume aev);
}

[Guid("A95664D2-9614-4F35-A746-DE8DB63617E6"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
interface IMMDeviceEnumerator {
    int f();
    int GetDefaultAudioEndpoint(int dataFlow, int role, out IMMDevice endpoint);
}

[ComImport, Guid("BCDE0395-E52F-467C-8E3D-C4579291692E")] class MMDeviceEnumeratorComObject { }

public class Audio {
    static IAudioEndpointVolume Vol() {
        var enumerator = new MMDeviceEnumeratorComObject() as IMMDeviceEnumerator;
        IMMDevice dev = null;
        Marshal.ThrowExceptionForHR(enumerator.GetDefaultAudioEndpoint(0, 1, out dev));
        IAudioEndpointVolume epv = null;
        var epvid = typeof(IAudioEndpointVolume).GUID;
        Marshal.ThrowExceptionForHR(dev.Activate(ref epvid, 23, 0, out epv));
        return epv;
    }

    public static float Volume {
        get { float v = -1; Marshal.ThrowExceptionForHR(Vol().GetMasterVolumeLevelScalar(out v)); return v; }
        set { Marshal.ThrowExceptionForHR(Vol().SetMasterVolumeLevelScalar(value, System.Guid.Empty)); }
    }

    public static bool Mute {
        get { bool mute; Marshal.ThrowExceptionForHR(Vol().GetMute(out mute)); return mute; }
        set { Marshal.ThrowExceptionForHR(Vol().SetMute(value, System.Guid.Empty)); }
    }
}
"@
        Add-Type -TypeDefinition $code -Language CSharp -PassThru | Out-Null
    }

    # Unmute and set volume
    [Audio]::Mute = $false
    [Audio]::Volume = $volumeLevel

    Write-Host "Volume set to $vol%"
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
if ($battery -and $charging) {
    if ($battery -lt 50 -and $charging -ne 2) {
        [System.Windows.Forms.MessageBox]::Show("Battery is below 50%. Please plug in your charger.", "Battery Check", 0, 48)
        return $false
    }
    return $true
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
if (Test-NaplanLDBRunning) {
    Write-Host "NAPLAN LDB is already running."
    exit 1
}

Set-Volume -vol 75
if (-not (Test-Internet)) { exit 1 }
if (-not (Test-BatteryLevel)) { exit 1 }
if (-not (Test-Resolution)) { exit 1 }

Prompt-Headphones

# Launch NAPLAN LDB
Start-Process "C:\Program Files (x86)\NAP Locked Down Browser\NAP Locked Down Browser.exe"
