Echo Warning! This will cleanup the automation test trails
:: wait 10 s
ping localhost -n 10

:: kill the CopTrax and clear the profile
Taskkill /IM IncaXPCApp.exe /F
rmdir /S /Q "C:\Users\coptraxadmin\AppData\Local\IncaX_Limited\"
mkdir "C:\Users\coptraxadmin\AppData\Local\IncaX_Limited\"
Del /Q C:\ProgramData\*coptrax*

:: Kill the firmware monitor.exe
Taskkill /IM FirmwareMonitor.exe /F

:: modify the autostart scheduler tasks, delete the automation and create the welcome screen. Allready achieved in automation.
schtasks /Delete /TN Automation /F
schtasks /Create /SC ONLOGON /TN "ACI\CopTrax Welcome" /TR "C:\CopTrax Support\Tools\CopTraxWelcome\CopTraxWelcome.exe" /F /RL HIGHEST

:: prepare the post automation batch file
copy /Y /V C:\CopTraxAutomation\PostAutomationCheck.bat "C:\CopTrax Support\Tools\Automation.bat"

:: delete the file trailers
Del /S /F /Q F:\*.mp4
Del /S /F /Q G:\*.mp4
Del /S /F /Q H:\*.mp4
Del /S /F /Q I:\*.mp4
Del /S /F /Q C:\CopTrax-Backup\*.*
Del /S /F /Q C:\Users\coptraxadmin\Documents\CopTraxTemp\*.*
Del /S /F /Q "C:\CopTrax Support\*.log"
Del /S /F /Q "C:\CopTrax Support\*.msi"
rmdir /S /Q C:\CoptraxAutomation
rmdir /S /Q "C:\Users\coptraxadmin\AppData\Local\coptrax\auto1"
rmdir /S /Q "C:\Users\coptraxadmin\AppData\Local\coptrax\auto2"
rmdir /S /Q "C:\Users\coptraxadmin\AppData\Local\coptrax\auto3"
rmdir /S /Q "C:\Users\coptraxadmin\AppData\Local\coptrax\auto4"

:: try to empty the temp sub-folder
rd /s /q %temp%

:: delete the Wi-Fi profiles
netsh wlan delete profile name="ACI-CopTrax"
netsh wlan delete profile name="ACI-CopTrax1"
netsh wlan delete profile name="ACI-CopTrax2"
netsh interface ip set address "CopTrax" static 10.25.50.100 255.255.255.0
WMIC computersystem where name="%computername%" call rename name="CopTrax"

:: start the welcome screen
shutdown.exe -r -t 0