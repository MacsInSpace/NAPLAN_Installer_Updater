# NAPLAN-UPDATER-SCRIPT  (marker checked by the scheduled task runner - do not remove)
#
# Installs or updates the NAP Locked Down Browser on Windows.
#
# Run once, manually ("just install/update the latest"), in an elevated PowerShell:
#   [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
#   irm -UseBasicParsing -Uri "https://raw.githubusercontent.com/MacsInSpace/NAPLAN_Installer_Updater/main/Windows/bin/InstallNaplan.ps1" | iex
#
# With options:
#   & ([scriptblock]::Create((irm -UseBasicParsing -Uri ".../Windows/bin/InstallNaplan.ps1"))) -Force
#
# Options:
#   -Scheduled          Used by the scheduled task. Checks daily in the lead-up to a
#                       test window and weekly for the rest of the year.
#   -Force              Reinstall even if the installed version is already current.
#   -IgnoreTestWindow   Allow replacing an installed browser during a test window.
#                       (Never used by the scheduled task. Think twice.)
#   -FallbackMsi        Optional path (e.g. an SMB share) to an MSI to use when the
#                       ACARA site cannot be reached and no browser is installed.
#
# Rules this script always follows:
#   * The new MSI is downloaded and its signature verified BEFORE the old browser
#     is touched.
#   * An installed browser is never replaced during a NAPLAN test window, and
#     never while the browser is running.
#   * A device with NO browser installed gets one, even during a test window.

param(
    [switch]$Scheduled,
    [switch]$Force,
    [switch]$IgnoreTestWindow,
    [string]$RepoBase = 'https://raw.githubusercontent.com/MacsInSpace/NAPLAN_Installer_Updater/main',
    [string]$FallbackMsi = ''
)

# ---------------------------------------------------------------------------
# Settings
# ---------------------------------------------------------------------------
$NapCfg = @{
    LdbPage       = 'https://www.assessform.edu.au/naplan-online/locked-down-browser'
    KeyDatesUrl   = 'https://www.nap.edu.au/naplan/key-dates'
    AllowedHostRe = '^https://([A-Za-z0-9-]+\.)*assessform\.edu\.au/'
    SignerMatch   = '*JANISON SOLUTIONS PTY LTD*'
    LeadUpDays    = 60     # check daily this many days before a test window
    WeeklyDays    = 7      # otherwise check this often
    WindowsMaxAge = 7      # days before the cached test windows are refreshed
    FirewallRule  = 'NAPLockedDownBrowserOutbound'
    TaskName      = 'InstallNaplan'
    UserAgent     = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36'
    StoragePath   = Join-Path $env:ProgramData 'Naplan'
}
$NapCfg.TempDir       = Join-Path $NapCfg.StoragePath 'Temp'
$NapCfg.LogFile       = Join-Path $NapCfg.StoragePath 'NaplanUpdater.log'
$NapCfg.LastCheckFile = Join-Path $NapCfg.StoragePath 'NaplanLastCheck.txt'
$NapCfg.WindowsFile   = Join-Path $NapCfg.StoragePath 'NaplanTestWindows.txt'
$NapCfg.Months        = 'January','February','March','April','May','June','July','August','September','October','November','December'

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------
function Write-NapLog {
    param([string]$Message, [string]$Level = 'INFO')
    $line = '{0} [{1}] {2}' -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $Level, $Message
    Write-Host $line
    try { Add-Content -Path $NapCfg.LogFile -Value $line -Encoding UTF8 -ErrorAction Stop } catch { }
}

function Protect-NapStorage {
    # C:\ProgramData lets ordinary users create files by default. This folder holds
    # scripts that run as SYSTEM, so lock it down: SYSTEM + Administrators full,
    # Users read-only. SIDs are used so this works on non-English Windows.
    foreach ($dir in $NapCfg.StoragePath, $NapCfg.TempDir) {
        if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
    }
    $p = $NapCfg.StoragePath
    & icacls.exe $p /setowner '*S-1-5-32-544' /T /C /Q 2>&1 | Out-Null
    & icacls.exe $p /inheritance:r /grant:r '*S-1-5-18:(OI)(CI)F' '*S-1-5-32-544:(OI)(CI)F' '*S-1-5-32-545:(OI)(CI)RX' /C /Q 2>&1 | Out-Null
    & icacls.exe (Join-Path $p '*') /reset /T /C /Q 2>&1 | Out-Null
}

function Invoke-NapRetry {
    param([scriptblock]$Action, [int]$Tries = 3, [int]$DelaySeconds = 10)
    for ($i = 1; $i -le $Tries; $i++) {
        try { return (& $Action) }
        catch {
            if ($i -eq $Tries) { throw }
            Start-Sleep -Seconds $DelaySeconds
        }
    }
}

function Get-NapWebText {
    param([string]$Url)
    Invoke-NapRetry {
        (Invoke-WebRequest -UseBasicParsing -Uri $Url -TimeoutSec 60 -UserAgent $NapCfg.UserAgent -ErrorAction Stop).Content
    }
}

function ConvertTo-NapVersion {
    # '5.11.0' and '5.11.0.0' must compare equal, so pad to four parts.
    param([string]$Text)
    try {
        $parts = @($Text.Trim() -split '\.' | ForEach-Object { [int]$_ })
        while ($parts.Count -lt 4) { $parts += 0 }
        return [version]($parts[0..3] -join '.')
    } catch { return $null }
}

function Get-NapInstalled {
    # Callers must wrap this in @(): Windows PowerShell 5.1 unrolls a single result,
    # and .Count on a lone registry object is empty there.
    # The browser is a 32-bit MSI, so it normally registers under WOW6432Node.
    $keys = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*',
            'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*'
    @(Get-ItemProperty -Path $keys -ErrorAction SilentlyContinue |
        Where-Object { $_.DisplayName -like 'NAP Locked Down Browser*' -and $_.PSChildName -match '^\{[0-9A-Fa-f-]{36}\}$' })
}

function Get-NapInstallDir {
    param($Installed)
    foreach ($entry in @($Installed)) {
        if ($entry.InstallLocation -and (Test-Path $entry.InstallLocation)) { return $entry.InstallLocation.TrimEnd('\') }
    }
    $pf = if (${env:ProgramFiles(x86)}) { ${env:ProgramFiles(x86)} } else { $env:ProgramFiles }
    return (Join-Path $pf 'NAP Locked Down Browser')
}

function Test-NapBrowserRunning {
    param([string]$InstallDir)
    # The browser installs a background Windows service (NAPLDBService ->
    # JanisonReplayService.exe) that runs all the time, so service processes do
    # not count. Anything else running from the folder means a student has it open.
    $prefix = $InstallDir.TrimEnd('\') + '\'
    $servicePids = @(Get-CimInstance Win32_Service -ErrorAction SilentlyContinue |
        Where-Object { $_.ProcessId -gt 0 } | ForEach-Object { $_.ProcessId })
    $procs = @(Get-CimInstance Win32_Process -ErrorAction SilentlyContinue |
        Where-Object { $_.ExecutablePath -and $_.ExecutablePath.StartsWith($prefix, [StringComparison]::OrdinalIgnoreCase) -and
                       $servicePids -notcontains $_.ProcessId })
    return ($procs.Count -gt 0)
}

function Get-NapWindowsFromHtml {
    # The ACARA page lists a year in one table cell and "10-22 March" in the next,
    # so the year is carried forward from the most recent cell holding only a year.
    param([string]$Html)
    $text = [regex]::Replace($Html, '(?s)<(script|style)\b.*?</\1>', '')
    $text = [regex]::Replace($text, '<[^>]+>', "`n")
    $text = [System.Net.WebUtility]::HtmlDecode($text).Replace([string][char]0xA0, ' ')
    $monthRe = $NapCfg.Months -join '|'
    $year = $null
    $out = @()
    foreach ($raw in ($text -split "`n")) {
        $line = $raw.Trim()
        if ($line -match '^(20\d\d)$') { $year = [int]$Matches[1]; continue }
        if ($year -and $line -match "(\d{1,2})\s*\p{Pd}\s*(\d{1,2})\s+($monthRe)") {
            $d1 = [int]$Matches[1]; $d2 = [int]$Matches[2]
            $month = [array]::IndexOf($NapCfg.Months, $Matches[3]) + 1
            if ($d1 -ge 1 -and $d1 -le $d2 -and $d2 -le 31) {
                $out += ('{0:D4}{1:D2}{2:D2} {0:D4}{1:D2}{3:D2}' -f $year, $month, $d1, $d2)
            }
        }
    }
    return $out
}

function Get-NapWindowsFromJson {
    param([string]$Json)
    $out = @()
    foreach ($w in @((ConvertFrom-Json $Json).windows)) {
        if ($w.start -match '^(\d{4})-(\d{2})-(\d{2})$') { $s = $Matches[1] + $Matches[2] + $Matches[3] } else { continue }
        if ($w.end -match '^(\d{4})-(\d{2})-(\d{2})$') { $e = $Matches[1] + $Matches[2] + $Matches[3] } else { continue }
        $out += "$s $e"
    }
    return $out
}

function Get-NapTestWindows {
    # Returns objects with Start/End [datetime]. Cached for a week; sources are the
    # ACARA key-dates page plus this repo's conf/dates.json; falls back to "all of March".
    $file = $NapCfg.WindowsFile
    $fresh = (Test-Path $file) -and ((Get-Item $file).Length -gt 0) -and
             (((Get-Date) - (Get-Item $file).LastWriteTime).TotalDays -lt $NapCfg.WindowsMaxAge)
    if (-not $fresh) {
        $lines = @()
        try { $lines += Get-NapWindowsFromHtml (Get-NapWebText $NapCfg.KeyDatesUrl) }
        catch { Write-NapLog "Could not read the ACARA key dates page: $($_.Exception.Message)" 'WARN' }
        try { $lines += Get-NapWindowsFromJson (Get-NapWebText "$RepoBase/conf/dates.json") }
        catch { Write-NapLog "Could not read conf/dates.json: $($_.Exception.Message)" 'WARN' }

        $thisYear = (Get-Date).Year
        $min = '{0}0101' -f ($thisYear - 1); $max = '{0}1231' -f ($thisYear + 5)
        $lines = @($lines | Where-Object { $_ -match '^\d{8} \d{8}$' } |
            Where-Object { $p = $_ -split ' '; $p[0] -ge $min -and $p[1] -le $max -and $p[0] -le $p[1] } | Sort-Object -Unique)

        if ($lines.Count -gt 0) {
            Set-Content -Path $file -Value $lines -Encoding ASCII
            Write-NapLog ("Test windows refreshed: " + ($lines -join '; '))
        } elseif ((Test-Path $file) -and (Get-Item $file).Length -gt 0) {
            Write-NapLog 'Could not refresh test windows; using the cached list.' 'WARN'
        } else {
            Write-NapLog 'Could not load test windows; assuming all of March.' 'WARN'
            $lines = @(('{0}0301 {0}0331' -f $thisYear), ('{0}0301 {0}0331' -f ($thisYear + 1)))
            Set-Content -Path $file -Value $lines -Encoding ASCII
            # Old timestamp so the next run tries the real sources again.
            (Get-Item $file).LastWriteTime = (Get-Date).AddDays(-30)
        }
    }
    $result = @()
    foreach ($line in @(Get-Content $file -ErrorAction SilentlyContinue)) {
        if ($line -match '^(\d{8}) (\d{8})$') {
            $result += [pscustomobject]@{
                Start = [datetime]::ParseExact($Matches[1], 'yyyyMMdd', [Globalization.CultureInfo]::InvariantCulture)
                End   = [datetime]::ParseExact($Matches[2], 'yyyyMMdd', [Globalization.CultureInfo]::InvariantCulture)
            }
        }
    }
    return $result
}

function Get-NapLatestMsi {
    # Returns @{ Url; Version } for the highest-versioned .msi link on the ACARA page.
    $resp = Invoke-NapRetry {
        Invoke-WebRequest -UseBasicParsing -Uri $NapCfg.LdbPage -TimeoutSec 60 -UserAgent $NapCfg.UserAgent -ErrorAction Stop
    }
    $urls = @()
    $urls += @($resp.Links | ForEach-Object { $_.href } | Where-Object { $_ -match '\.msi$' })
    $urls += @([regex]::Matches($resp.Content, 'https://[^"''<> ]+\.msi') | ForEach-Object { $_.Value })
    $best = $null
    foreach ($url in ($urls | Sort-Object -Unique)) {
        $decoded = [System.Uri]::UnescapeDataString($url)
        if ($decoded -match '(\d+(?:\.\d+)+)\.msi$') {
            $ver = ConvertTo-NapVersion $Matches[1]
            if ($ver -and ((-not $best) -or $ver -gt $best.Version)) {
                $best = @{ Url = $url; Version = $ver; VersionText = $Matches[1] }
            }
        }
    }
    return $best
}

function Invoke-NapMsi {
    param([string]$Arguments)
    $p = Start-Process -FilePath 'msiexec.exe' -ArgumentList $Arguments -Wait -PassThru -NoNewWindow
    return $p.ExitCode
}

function Invoke-NapNuke {
    Write-NapLog 'Running the deep clean (NAPLANnuke.ps1)...'
    try {
        $nuke = Invoke-NapRetry { Invoke-RestMethod -UseBasicParsing -Uri "$RepoBase/Windows/bin/NAPLANnuke.ps1" -ErrorAction Stop }
        & ([scriptblock]::Create($nuke)) | Out-Null
    } catch { Write-NapLog "Deep clean failed: $($_.Exception.Message)" 'WARN' }
}

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------
function Invoke-NapUpdate {
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $isAdmin = (New-Object Security.Principal.WindowsPrincipal($identity)).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    if (-not $isAdmin) {
        Write-Host 'This script must be run as Administrator. Open PowerShell with "Run as administrator" and try again.' -ForegroundColor Red
        return 1
    }
    # Anything running as SYSTEM (the scheduled task, including tasks installed by
    # older versions of this project) is treated as a scheduled run.
    $isScheduled = $Scheduled -or $identity.IsSystem

    [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12
    $ProgressPreference = 'SilentlyContinue'

    Protect-NapStorage
    if ((Test-Path $NapCfg.LogFile) -and (Get-Item $NapCfg.LogFile).Length -gt 1MB) {
        Move-Item $NapCfg.LogFile ($NapCfg.LogFile + '.old') -Force -ErrorAction SilentlyContinue
    }

    # One run at a time.
    $mutex = New-Object Threading.Mutex($false, 'Global\NaplanUpdater')
    $haveMutex = $false
    try { $haveMutex = $mutex.WaitOne(0) } catch [Threading.AbandonedMutexException] { $haveMutex = $true }
    if (-not $haveMutex) { Write-NapLog 'Another run is in progress. Exiting.'; return 0 }

    $msi = $null
    try {
        Write-NapLog "---- NAPLAN LDB updater starting (scheduled=$isScheduled force=$Force) ----"

        $installed = @(Get-NapInstalled)
        $installedVersion = $null
        if ($installed.Count -gt 0) {
            $installedVersion = ConvertTo-NapVersion ([string]$installed[0].DisplayVersion)
            Write-NapLog ("Installed version: {0} {1}" -f $installed[0].DisplayVersion, (($installed | ForEach-Object { $_.PSChildName }) -join ' '))
        } else {
            Write-NapLog 'Installed version: none'
        }
        $installDir = Get-NapInstallDir $installed

        # --- test windows ---------------------------------------------------
        $today = (Get-Date).Date
        $inWindow = $false; $inLeadUp = $false
        foreach ($w in @(Get-NapTestWindows)) {
            if ($today -ge $w.Start -and $today -le $w.End) {
                $inWindow = $true
                Write-NapLog ("Today is inside a test window ({0:dd/MM/yyyy} to {1:dd/MM/yyyy})." -f $w.Start, $w.End)
            }
            if ($today -ge $w.Start.AddDays(-$NapCfg.LeadUpDays) -and $today -lt $w.Start) {
                $inLeadUp = $true
                Write-NapLog ("Today is in the lead-up to the test window starting {0:dd/MM/yyyy}." -f $w.Start)
            }
        }

        # --- rule: never replace an installed browser during a test window ----
        if ($installed.Count -gt 0 -and $inWindow) {
            if ($IgnoreTestWindow -and -not $isScheduled) {
                Write-NapLog 'Inside a test window, but -IgnoreTestWindow was given. Continuing.' 'WARN'
            } else {
                Write-NapLog 'Browser is installed and we are inside a test window. Not touching it.'
                return 0
            }
        }

        # --- cadence (scheduled runs only) ---------------------------------------
        if ($isScheduled -and -not $Force -and $installed.Count -gt 0 -and -not $inLeadUp -and (Test-Path $NapCfg.LastCheckFile)) {
            try {
                $last = [datetime]::ParseExact((Get-Content $NapCfg.LastCheckFile -TotalCount 1).Trim(), 'yyyyMMdd', [Globalization.CultureInfo]::InvariantCulture)
                $age = ($today - $last).Days
                if ($age -ge 0 -and $age -lt $NapCfg.WeeklyDays) {
                    Write-NapLog "Last successful check was $age day(s) ago; next check is weekly outside the lead-up. Nothing to do."
                    return 0
                }
            } catch { }
        }

        # --- what is the latest version? --------------------------------------------
        $latest = $null
        try { $latest = Get-NapLatestMsi }
        catch { Write-NapLog "Could not load $($NapCfg.LdbPage): $($_.Exception.Message)" 'ERROR' }

        $source = $null     # path or URL the MSI will come from
        if ($latest) {
            if ($latest.Url -notmatch $NapCfg.AllowedHostRe) {
                Write-NapLog "Download link is not on assessform.edu.au, refusing: $($latest.Url)" 'ERROR'
                return 1
            }
            Write-NapLog "Latest version online: $($latest.VersionText) ($($latest.Url))"
            if ($installedVersion -and $installedVersion -eq $latest.Version -and -not $Force) {
                Write-NapLog 'Already up to date.'
                Set-Content -Path $NapCfg.LastCheckFile -Value (Get-Date -Format 'yyyyMMdd')
                return 0
            }
            $source = $latest.Url
        } elseif ($FallbackMsi -and $installed.Count -eq 0 -and (Test-Path $FallbackMsi)) {
            Write-NapLog "ACARA site unreachable and nothing installed; using fallback MSI $FallbackMsi" 'WARN'
            $source = $FallbackMsi
        } else {
            Write-NapLog 'No download link found (site unreachable or page layout changed). Nothing was changed; will try again next run.' 'ERROR'
            return 1
        }

        # --- rule: never touch a running browser ----------------------------------------
        if ($installed.Count -gt 0 -and (Test-NapBrowserRunning $installDir)) {
            Write-NapLog 'The browser is running right now. Not touching it; will try again next run.'
            return 0
        }

        # --- download and verify BEFORE touching anything -----------------------------------
        Get-ChildItem $NapCfg.TempDir -ErrorAction SilentlyContinue | Remove-Item -Recurse -Force -ErrorAction SilentlyContinue
        $msi = Join-Path $NapCfg.TempDir 'Naplan_Setup.msi'
        try {
            if ($source -match '^https://') {
                Write-NapLog 'Downloading MSI...'
                Invoke-NapRetry -Tries 3 -DelaySeconds 20 -Action {
                    $wc = New-Object Net.WebClient
                    $wc.Headers['User-Agent'] = $NapCfg.UserAgent
                    try { $wc.DownloadFile($source, $msi) } finally { $wc.Dispose() }
                } | Out-Null
            } else {
                Copy-Item -Path $source -Destination $msi -Force -ErrorAction Stop
            }
        } catch {
            Write-NapLog "Download failed: $($_.Exception.Message). Nothing was changed." 'ERROR'
            return 1
        }

        $sig = Get-AuthenticodeSignature -FilePath $msi
        if ($sig.Status -ne 'Valid' -or $sig.SignerCertificate.Subject -notlike $NapCfg.SignerMatch) {
            Write-NapLog "MSI signature check failed (status: $($sig.Status); signer: $($sig.SignerCertificate.Subject)). Nothing was changed." 'ERROR'
            return 1
        }
        Write-NapLog "MSI signature OK ($($sig.SignerCertificate.Subject -replace ',.*$', ''))."

        # --- remove the old version(s) ---------------------------------------------------------
        foreach ($entry in $installed) {
            Write-NapLog "Removing old version $($entry.DisplayVersion) $($entry.PSChildName)..."
            $code = Invoke-NapMsi "/x $($entry.PSChildName) /qn /norestart"
            if ($code -eq 1618) {
                Write-NapLog 'Another installation is in progress on this PC. Nothing was changed; will try again next run.' 'WARN'
                return 1
            }
            if ($code -notin 0, 1605, 1641, 3010) { Write-NapLog "Uninstall returned $code." 'WARN' }
        }
        if (@(Get-NapInstalled).Count -gt 0) {
            Write-NapLog 'Old version did not uninstall cleanly.' 'WARN'
            Invoke-NapNuke
        }

        # --- install ---------------------------------------------------------------------------------
        $msiLog = Join-Path $NapCfg.StoragePath 'NaplanMsiInstall.log'
        Write-NapLog 'Installing...'
        $code = Invoke-NapMsi "/i `"$msi`" /qn /norestart /l*v `"$msiLog`""
        if ($code -notin 0, 1641, 3010) {
            Write-NapLog "Install returned $code. Running the deep clean and trying once more." 'WARN'
            Invoke-NapNuke
            $code = Invoke-NapMsi "/i `"$msi`" /qn /norestart /l*v `"$msiLog`""
        }
        $now = @(Get-NapInstalled)
        if ($code -notin 0, 1641, 3010 -or $now.Count -eq 0) {
            Write-NapLog "Install FAILED (msiexec exit code $code). See $msiLog." 'ERROR'
            return 1
        }
        Write-NapLog "Installed version is now: $($now[0].DisplayVersion)"
        if ($code -ne 0) { Write-NapLog 'Windows reports a restart is needed to finish the install.' 'WARN' }

        # --- firewall rule ----------------------------------------------------------------------------
        try {
            $exe = Join-Path (Get-NapInstallDir $now) 'NAP Locked Down Browser.exe'
            Get-NetFirewallRule -DisplayName $NapCfg.FirewallRule -ErrorAction SilentlyContinue | Remove-NetFirewallRule -ErrorAction SilentlyContinue
            New-NetFirewallRule -DisplayName $NapCfg.FirewallRule -Description 'Outbound rule for NAP Locked Down Browser' `
                -Program $exe -Direction Outbound -Action Allow -Profile Any -ErrorAction Stop | Out-Null
            Write-NapLog 'Firewall rule set.'
        } catch { Write-NapLog "Could not set the firewall rule: $($_.Exception.Message)" 'WARN' }

        # If the optional launcher is installed, students should use its shortcut,
        # so remove the browser's own desktop shortcut that the MSI just put back.
        if (Test-Path (Join-Path $NapCfg.StoragePath 'NAPLAN_Launcher.ps1')) {
            Get-ChildItem -Path (Join-Path $env:PUBLIC 'Desktop') -Filter 'NAP Locked*.lnk' -File -ErrorAction SilentlyContinue |
                Remove-Item -Force -ErrorAction SilentlyContinue
        }

        # Refresh the icon cache so the new shortcut icon shows (hangs when run as SYSTEM, so skip there).
        if (-not $identity.IsSystem) {
            try { Start-Process -FilePath 'ie4uinit.exe' -ArgumentList '-ClearIconCache' -WindowStyle Hidden } catch { }
        }

        Set-Content -Path $NapCfg.LastCheckFile -Value (Get-Date -Format 'yyyyMMdd')
        Write-NapLog 'Done.'
        return 0
    }
    catch {
        Write-NapLog "Unexpected error: $($_.Exception.Message) at line $($_.InvocationInfo.ScriptLineNumber)" 'ERROR'
        return 1
    }
    finally {
        if ($msi -and (Test-Path $msi)) { Remove-Item $msi -Force -ErrorAction SilentlyContinue }
        try { $mutex.ReleaseMutex() } catch { }
        $mutex.Dispose()
    }
}

function Update-NapLegacyTask {
    # Scheduled tasks installed by older versions of this project ran everything
    # through "cmd.exe /c powershell -EncodedCommand ...". Replace them in place
    # with the current task definition.
    try {
        $task = Get-ScheduledTask -TaskName $NapCfg.TaskName -ErrorAction SilentlyContinue
        if ($task -and $task.Actions[0].Execute -match 'cmd(\.exe)?$') {
            Write-NapLog 'Old-style scheduled task found. Replacing it with the current one.'
            $script = Invoke-NapRetry { Invoke-RestMethod -UseBasicParsing -Uri "$RepoBase/Windows/bin/NAPLANscheduledtask.ps1" -ErrorAction Stop }
            & ([scriptblock]::Create($script)) -RepoBase $RepoBase -NoStart | Out-Null
        }
    } catch { Write-NapLog "Could not replace the old scheduled task: $($_.Exception.Message)" 'WARN' }
}

$NapExitCode = [int](Invoke-NapUpdate | Select-Object -Last 1)
if ([Security.Principal.WindowsIdentity]::GetCurrent().IsSystem) { Update-NapLegacyTask }

# Only end the PowerShell process when running unattended; "exit" in an
# interactive "irm | iex" session would close the admin's window.
if ($Scheduled -or [Security.Principal.WindowsIdentity]::GetCurrent().IsSystem) { exit $NapExitCode }
