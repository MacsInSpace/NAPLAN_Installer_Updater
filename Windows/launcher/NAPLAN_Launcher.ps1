# NAPLAN-LAUNCHER-SCRIPT  (marker checked by Install_Launcher.ps1 - do not remove)
#
# Pre-flight checks, then starts the NAP Locked Down Browser.
# Started by the "NAPLAN <year> Launcher" desktop shortcut (via NAPLAN_Launcher.cmd).
# Runs as the logged-in student; needs no admin rights.
#
# Checks, in order:
#   1. The browser is installed and not already running.
#   2. Volume is unmuted and set to 75%.
#   3. The assessment platform can be reached.
#   4. Battery is at least 50%, or the charger is plugged in.
#   5. The screen meets ACARA's minimum resolution (1024 x 768).
#   6. Reminds the student to plug in headphones.

$MinWidth       = 1024     # ACARA minimum: https://www.assessform.edu.au/naplan-online/device-requirements
$MinHeight      = 768
$MinBattery     = 50
$VolumePercent  = 75
$PlatformUrl    = 'https://www.assessform.edu.au/'
$Title          = 'NAPLAN Launcher'

# Message boxes and screen size both need Windows Forms loaded.
Add-Type -AssemblyName System.Windows.Forms

function Show-Message {
    param([string]$Text, [ValidateSet('Information', 'Warning', 'Error')][string]$Icon = 'Warning')
    # Owned by an invisible always-on-top window so the message cannot end up
    # hidden behind other windows.
    $owner = New-Object System.Windows.Forms.Form
    $owner.TopMost = $true
    [void][System.Windows.Forms.MessageBox]::Show($owner, $Text, $Title, 'OK', $Icon)
    $owner.Dispose()
}

function Get-BrowserExe {
    $roots = @()
    $keys = 'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*',
            'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*'
    foreach ($entry in @(Get-ItemProperty -Path $keys -ErrorAction SilentlyContinue |
            Where-Object { $_.DisplayName -like 'NAP Locked Down Browser*' -and $_.InstallLocation })) {
        $roots += $entry.InstallLocation
    }
    if (${env:ProgramFiles(x86)}) { $roots += Join-Path ${env:ProgramFiles(x86)} 'NAP Locked Down Browser' }
    $roots += Join-Path $env:ProgramFiles 'NAP Locked Down Browser'
    foreach ($root in $roots) {
        $exe = Join-Path $root 'NAP Locked Down Browser.exe'
        if (Test-Path $exe) { return $exe }
    }
    return $null
}

function Test-BrowserRunning {
    return [bool](Get-Process -Name 'NAP Locked Down Browser' -ErrorAction SilentlyContinue)
}

function Set-Volume {
    param([ValidateRange(0, 100)][int]$Percent)
    # Core Audio API. Credit: Rohan Beckett (Melbourne).
    if (-not ('Audio' -as [type])) {
        Add-Type -Language CSharp -TypeDefinition @"
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
    }
    [Audio]::Mute = $false
    [Audio]::Volume = [math]::Round($Percent / 100, 2)
}

function Test-Platform {
    # A real HTTPS request through the system proxy. Ping is not used: many
    # school networks block it even when the internet is working.
    try {
        [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12
        $request = [Net.WebRequest]::Create($PlatformUrl)
        $request.Method = 'HEAD'
        $request.Timeout = 15000
        $request.UserAgent = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64)'
        if ($request.Proxy) { $request.Proxy.Credentials = [Net.CredentialCache]::DefaultNetworkCredentials }
        $response = $request.GetResponse()
        $response.Close()
        return $true
    } catch [Net.WebException] {
        # Any HTTP answer (even an error status) proves the site was reached.
        if ($_.Exception.Response) { return $true }
        return $false
    } catch {
        return $false
    }
}

function Test-Battery {
    # Returns $false only when on battery AND below the minimum. Desktops pass.
    $batteries = @(Get-CimInstance Win32_Battery -ErrorAction SilentlyContinue)
    if ($batteries.Count -eq 0) { return $true }
    if ([System.Windows.Forms.SystemInformation]::PowerStatus.PowerLineStatus -eq 'Online') { return $true }
    $charge = ($batteries | Measure-Object -Property EstimatedChargeRemaining -Maximum).Maximum
    return (-not $charge) -or ($charge -ge $MinBattery)
}

function Get-ScreenPixels {
    # Real pixels of the primary display. Screen.Bounds reports a scaled-down
    # size when Windows display scaling is above 100%, so ask the video
    # controller first.
    $video = Get-CimInstance Win32_VideoController -ErrorAction SilentlyContinue |
        Where-Object { $_.CurrentHorizontalResolution -gt 0 } | Select-Object -First 1
    if ($video) { return @([int]$video.CurrentHorizontalResolution, [int]$video.CurrentVerticalResolution) }
    $bounds = [System.Windows.Forms.Screen]::PrimaryScreen.Bounds
    return @($bounds.Width, $bounds.Height)
}

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------
$exe = Get-BrowserExe
if (-not $exe) {
    Show-Message 'The NAP Locked Down Browser is not installed on this device. Please see your teacher or IT support.' 'Error'
    exit 1
}

if (Test-BrowserRunning) {
    Show-Message 'The NAP Locked Down Browser is already open.' 'Information'
    exit 1
}

try { Set-Volume -Percent $VolumePercent } catch { }   # no audio device is not a reason to stop

if (-not (Test-Platform)) {
    Show-Message 'Cannot reach the NAPLAN assessment platform. Please check your internet connection and try again.'
    exit 1
}

if (-not (Test-Battery)) {
    Show-Message "Battery is below $MinBattery%. Please plug in your charger, then try again."
    exit 1
}

$screen = Get-ScreenPixels
if ($screen[0] -lt $MinWidth -or $screen[1] -lt $MinHeight) {
    Show-Message ("Screen resolution is {0} x {1}, below the minimum of {2} x {3}. Please see your teacher or IT support." -f $screen[0], $screen[1], $MinWidth, $MinHeight)
    exit 1
}

Show-Message 'Please plug in your headphones now, then click OK to start.' 'Information'

Start-Process -FilePath $exe
exit 0
