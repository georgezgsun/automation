rdEcho Warning! This will help to update the golden image
:: pause for a couple of seconds
timeout /t 5

:: update the welcome screen, manufacture tool and automation folders
cd /d %~dp0
rd /s /q "C:\CopTrax Support\Manufacturing Test -01"
rd /s /q "C:\CopTrax Support\ManufacturingTool"
rd /s /q "C:\CopTrax Support\CopTraxWelcome"
rd /s /q "C:\CopTrax Support\Tools\CopTraxWelcome"
rd /s /q C:\CopTraxAutomation

mkdir "C:\CopTrax Support\Tools\Manufacturing Test -01"
copy /Y "Manufacturing Test -01\*.*" "C:\CopTrax Support\Tools\Manufacturing Test -01"
mkdir C:\CopTraxAutomation
mkdir C:\CopTraxAutomation\tmp
copy /Y CopTraxAutomation\*.* C:\CopTraxAutomation
mkdir "C:\CopTrax Support\Tools\CopTraxWelcome"
copy /Y CopTraxWelcome\*.* "C:\CopTrax Support\Tools\CopTraxWelcome"
mkdir "C:\CopTrax Support\Tools\CopTraxWelcome\Localization"
copy /Y CopTraxWelcome\Localization\*.* "C:\CopTrax Support\Tools\CopTraxWelcome\Localization"
copy /Y /V IncaXPCApp.exe.config "C:\Program Files (x86)\IncaX\CopTrax\IncaXPCApp.exe.config"
copy /Y /V MobileCam.exe.config "C:\Program Files\Applied Concepts Inc\CopTrax Body Camera Manager\MobileCam.exe.config"
copy /Y /V CopTrax.lnk "C:\Program Files (x86)\IncaX\CopTrax"
copy /Y /V CopTrax.lnk "C:\Users\Public\Desktop"

:: copy the files to C:\CopTrax Support\Tools folder
copy /Y /V C:\CopTraxAutomation\Cleanup.bat "C:\CopTrax Support\Tools"
copy /Y /V C:\CopTraxAutomation\PreAutomationCheck.bat "C:\CopTrax Support\Tools\Automation.bat"
copy /Y /V StartCopTrax.bat "C:\CopTrax Support\Tools"

:: kill the CopTrax and clear the profile
Taskkill /IM IncaXPCApp.exe /F
rmdir /S /Q "C:\Users\coptraxadmin\AppData\Local\IncaX_Limited\"
mkdir "C:\Users\coptraxadmin\AppData\Local\IncaX_Limited\"
Del /Q C:\ProgramData\*coptrax*

:: delete the video file trailers
Del /S /F /Q C:\CopTrax-Backup\*.*
Del /S /F /Q C:\Users\coptraxadmin\Documents\CopTraxTemp\*.*
rmdir /S /Q "C:\Users\coptraxadmin\AppData\Local\coptrax\auto1\"
rmdir /S /Q "C:\Users\coptraxadmin\AppData\Local\coptrax\auto2\"
rmdir /S /Q "C:\Users\coptraxadmin\AppData\Local\coptrax\auto3\"
rmdir /S /Q "C:\Users\coptraxadmin\AppData\Local\coptrax\auto4\"

:: prepare the Wi-Fi profile, modify the autostart scheduler tasks
netsh wlan delete profile name="ACI-CopTrax"
netsh wlan delete profile name="ACI-CopTrax1"
netsh wlan delete profile name="ACI-CopTrax2"
netsh wlan add profile filename="C:\CopTraxAutomation\ACI-CopTrax.xml"
netsh wlan add profile filename="C:\CopTraxAutomation\ACI-CopTrax2.xml"
netsh interface ip set address "CopTrax" static 10.25.50.100 255.255.255.0
schtasks /Delete /TN Automation /F
schtasks /Create /SC ONLOGON /TN "ACI\CopTrax Welcome" /TR "C:\CopTrax Support\Tools\CopTraxWelcome\CopTraxWelcome.exe" /F /RL HIGHEST

:: update the registery key
regedit.exe /s "C:\CopTraxAutomation\SetupAutoEndTasks.reg"

:: try to empty the temp sub-folder
rd /s /q %temp%

:: pause to check the results
:: sync64.exe -acceptteula
pause

