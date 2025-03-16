@echo off
rem
rem DATE 2025-03-14
rem version 0.6.0
rem
rem NAPNuke.bat File to remove all known versions of Naplan off a device.
rem Starts with graceful removal by invoking the windows uninstall process
rem but then brute-force removes files, registry keys and service configurations for broken installations.
rem Also resets a number of registry entries that the browser sets during operation but doesnt
rem always fix on exit.
rem a followup installation of the current browser version should then be possible.
rem
rem find uninstall keys at HKEY_LOCAL_MACHINE\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\
rem
rem run graceful msiexec uninstall process for all known versions.
rem
rem old testing version 2016/17
MsiExec.exe /X{96441ACD-EBF0-4355-9A6C-634FA4B4D4A5} /qn
rem wpad version 2018
MsiExec.exe /X{936DA4FF-CA28-4EFE-839C-0FE1F11F6C53} /qn
rem non wpad version 2018
MsiExec.exe /X{437FE330-1798-4A96-8BEE-388D7DDED9EC} /qn
rem 2019 version
MsiExec.exe /X{19A923B0-A305-41D2-A001-84865587FF03} /qn
rem 2020 version
MsiExec.exe /X{D344F921-1999-4FE5-A3D7-BC87211DDFEF} /qn
rem 2021 version
MsiExec.exe /X{D6051B85-FDAA-4A9F-AD47-E1D54897CEF5} /qn
rem late jan 2022 version 2.5.0
MsiExec.exe /X{5B2AA702-93C9-41D8-924E-5EDB646BD50F} /qn
rem jan 23 version v5.0.569 Should not be in production environment
MsiExec.exe /X{1DC4C729-D48C-493E-887A-34BF10EE3128} /qn
rem jan 23 version v5.1.0 Should not be in production environment
MsiExec.exe /X{95FCC227-0BE6-4FE7-9832-992769641C4D} /qn
rem jan 23 version 5.2.2
MsiExec.exe /X{29E46A31-A0A6-4E2A-91F5-B5F8248B4716} /qn
rem jan 24 version 5.6.15
MsiExec.exe /X{8A4846B5-DF7E-442F-992E-60FE5228D31A} /qn
rem nov 24 version 5.8.19
MsiExec.exe /X{74C4ACE7-0DEC-44FB-B366-C4573FB80D52} /qn
rem Feb 25 version 5.9.2
MsiExec.exe /X{3090BF31-F857-466E-9A75-9DBA6E506B83} /qn

rem
rem need further information regarding other exe installation versions.
rem exe based installation of 2.5.0
"C:\ProgramData\Package Cache\{a666099a-8347-47c9-a753-5240e7dc7a1f}\JanisonNaplanBootstrapper.exe" /uninstall /silent

rem Explicitly delete the registry keys that prevent over the top installation if msi installer is broken.
rem only more recent versions listed.
rem
rem 2.2.2 2019
rem Computer\HKEY_CLASSES_ROOT\Installer\Products\0B329A91503A2D140A1048685578FF30
REG DELETE HKCR\Installer\Products\0B329A91503A2D140A1048685578FF30 /f
rem 2.4.4 2020
rem Computer\HKEY_CLASSES_ROOT\Installer\Products\129F443D99915EF43A7DCB7812D1FDFE
REG DELETE HKCR\Installer\Products\129F443D99915EF43A7DCB7812D1FDFE /f
rem 2.4.6 2021
rem Computer\HKEY_CLASSES_ROOT\Installer\Products\58B1506DAADFF9A4DA741E5D8479EC5F
REG DELETE HKCR\Installer\Products\58B1506DAADFF9A4DA741E5D8479EC5F /f
rem 2.5.0 2022
rem Computer\HKEY_CLASSES_ROOT\Installer\Products\207AA2B59C398D1429E4E5BD46B65DF0
REG DELETE HKCR\Installer\Products\207AA2B59C398D1429E4E5BD46B65DF0 /f
rem 5.0.569
rem Computer\HKEY_CLASSES_ROOT\Installer\Products\927C4CD1C84DE39488A743FB01EE1382
REG DELETE HKCR\Installer\Products\927C4CD1C84DE39488A743FB01EE1382 /f
rem 5.1.0
rem Computer\HKEY_CLASSES_ROOT\Installer\Products\722CCF596EB07EF4892399729646C1D4
REG DELETE HKCR\Installer\Products\722CCF596EB07EF4892399729646C1D4 /f
rem 5.2.2
rem Computer\HKEY_CLASSES_ROOT\Installer\Products\13A64E926A0AA2E4195F5B8F42B87461
REG DELETE HKCR\Installer\Products\13A64E926A0AA2E4195F5B8F42B87461 /f
rem version 5.6.15
rem Computer\HKEY_CLASSES_ROOT\Installer\Products\5B6484A8E7FDF24499E206EF25823DA1
REG DELETE HKCR\Installer\Products\5B6484A8E7FDF24499E206EF25823DA1 /f
rem version 5.8.19
rem Computer\HKEY_CLASSES_ROOT\Installer\Products\7ECA4C47CED0BF443B664C75F38BD025
REG DELETE HKCR\Installer\Products\7ECA4C47CED0BF443B664C75F38BD025 /f
rem version 5.9.2
rem Computer\HKEY_CLASSES_ROOT\Installer\Products\13FB0903758FE664A957D9ABE605B638
REG DELETE HKCR\Installer\Products\13FB0903758FE664A957D9ABE605B638 /f

Rem delete uninstall keys for broken installations (same reg location as uninstall strings.)
rem find keys at HKEY_LOCAL_MACHINE\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\
rem old testing version 2016/17
REG DELETE HKLM\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\{96441ACD-EBF0-4355-9A6C-634FA4B4D4A5} /f
rem wpad version 2018
REG DELETE HKLM\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\{936DA4FF-CA28-4EFE-839C-0FE1F11F6C53} /f
rem non wpad version 2018
REG DELETE HKLM\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\{437FE330-1798-4A96-8BEE-388D7DDED9EC} /f
rem 2019 version
REG DELETE HKLM\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\{19A923B0-A305-41D2-A001-84865587FF03} /f
rem 2020 version
REG DELETE HKLM\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\{D344F921-1999-4FE5-A3D7-BC87211DDFEF} /f
rem 2021 version
REG DELETE HKLM\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\{D6051B85-FDAA-4A9F-AD47-E1D54897CEF5} /f
rem 2.5.0 uninstall key
REG DELETE HKLM\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\{5B2AA702-93C9-41D8-924E-5EDB646BD50F} /f
rem jan 23 version v5.0.569
REG DELETE HKLM\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\{1DC4C729-D48C-493E-887A-34BF10EE3128} /f
rem jan 23 version v5.1.0
REG DELETE HKLM\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\{95FCC227-0BE6-4FE7-9832-992769641C4D} /f
rem jan 23 version 5.2.2
REG DELETE HKLM\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\{29E46A31-A0A6-4E2A-91F5-B5F8248B4716} /f
rem jan 24 version 5.6.15
REG DELETE HKLM\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\{8A4846B5-DF7E-442F-992E-60FE5228D31A} /f
rem nov 24 version 5.8.19
REG DELETE HKLM\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\{74C4ACE7-0DEC-44FB-B366-C4573FB80D52} /f
rem Feb 25 version 5.9.2
REG DELETE HKLM\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\{3090BF31-F857-466E-9A75-9DBA6E506B83} /f

rem delete miscellaneous reg keys
REG DELETE HKCR\napldb /f
REG DELETE HKCU\SOFTWARE\Janison /f
REG DELETE HKLM\SOFTWARE\Classes\napldb /f
REG DELETE "HKEY_USERS\.DEFAULT\Software\NAP Locked down browser" /f
REG DELETE HKLM\SOFTWARE\WOW6432Node\Microsoft\Tracing\SafeExamBrowser_RASAPI32 /f
REG DELETE HKLM\SOFTWARE\WOW6432Node\Microsoft\Tracing\SafeExamBrowser_RASMANCS /f
rem remove the lock to taskmanager that is not cleanly removed if naplan fails to exit gracefully
REG DELETE HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System /v DisableTaskMgr /f
REG DELETE HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System /v DisableLockWorkstation /f

rem
rem repair touch related settings if they already exist.
rem
rem Values may only apply to certain Lenovo devices. Naplan sets these to value 0. Revert to value 1
rem
reg query "HKCU\SOFTWARE\Microsoft\Wisp\Touch" /v "TouchGate" >nul 2>&1
IF %ERRORLEVEL% EQU 0 (
reg add "HKCU\SOFTWARE\Microsoft\Wisp\Touch" /v "TouchGate" /t REG_DWORD /d "1" /f
)
reg query "HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\PrecisionTouchPad" /v "ThreeFingerSlideEnabled" >nul 2>&1
IF %ERRORLEVEL% EQU 0 (
reg add "HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\PrecisionTouchPad" /v "ThreeFingerSlideEnabled" /t REG_DWORD /d "1" /f
)
reg query "HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\PrecisionTouchPad" /v "FourFingerSlideEnabled" >nul 2>&1
IF %ERRORLEVEL% EQU 0 (
reg add "HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\PrecisionTouchPad" /v "FourFingerSlideEnabled" /t REG_DWORD /d "1" /f
)


rem kill the running service to prevent file locks

rem net stop SEBWindowsService
rem net stop NAPLDBService
taskkill /f /fi "SERVICES eq SEBWindowsService"
taskkill /f /fi "SERVICES eq NAPLDBService"

rem kill the service and any remaining reg entries
sc delete NAPLDBService
sc delete SEBWindowsService
rem reg key location:
rem Computer\HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Services\NAPLDBService
REG DELETE HKLM\SYSTEM\CurrentControlSet\Services\NAPLDBService /f
REG DELETE HKLM\SYSTEM\CurrentControlSet\Services\SEBWindowsService /f

rem delete %appdata% folders from all users
md c:\flags
Dir /b c:\users > c:\flags\userlist.txt

for /f %%B in (c:\flags\userlist.txt) do (
rmdir /s /q "C:\Users\"%%B"\AppData\Local\NAP Locked down browser"
rmdir /s /q "C:\Users\"%%B"\AppData\Roaming\NAP Locked down browser"
)

del c:\flags\userlist.txt


rem delete files and shortcuts.
del "C:\Program Files (x86)\NAP Locked down browser\SebWindowsServiceWCF\"*.* /q
rmdir /s /q "C:\Program Files (x86)\NAP Locked down browser"
DEL /s /q "C:\Users\Public\Desktop\NAP*.lnk"
DEL /s /q %userprofile%\Desktop\NAP*.lnk
DEL /s /q "%allusersprofile%\Microsoft\Windows\Start Menu\Programs\NAP*.lnk"
rem DEL /s /q "C:\ProgramData\Microsoft\Windows\Start Menu\Programs\NAP*.lnk"
rem
rem
rem
