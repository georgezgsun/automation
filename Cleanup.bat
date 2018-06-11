Echo Warning! This will cleanup the automation test trails
:: wait 10 s
ping localhost -n 10

:: kill the CopTrax and clear the profile
Taskkill /IM IncaXPCApp.exe /F
rmdir /S /Q "C:\Users\coptraxadmin\AppData\Local\IncaX_Limited\"
mkdir "C:\Users\coptraxadmin\AppData\Local\IncaX_Limited\"
Del /Q C:\ProgramData\*coptrax*

:: modify the autostart scheduler tasks, delete the automation and create the welcome screen. Allready achieved in automation.
schtasks /Delete /TN Automation /F

:: delete the file trailers
Del /S /F /Q F:\*.mp4
Del /S /F /Q G:\*.mp4
Del /S /F /Q H:\*.mp4
Del /S /F /Q I:\*.mp4
Del /S /F /Q C:\CopTrax-Backup\*.*
rmdir /S /Q C:\CoptraxAutomation\
rmdir /S /Q "C:\Users\coptraxadmin\AppData\Local\coptrax\auto1\"
rmdir /S /Q "C:\Users\coptraxadmin\AppData\Local\coptrax\auto2\"
rmdir /S /Q "C:\Users\coptraxadmin\AppData\Local\coptrax\auto3\"
rmdir /S /Q "C:\Users\coptraxadmin\AppData\Local\coptrax\auto4\"

:: delete the Wi-Fi profiles
netsh wlan delete profile name="ACI-CopTrax1"
netsh wlan delete profile name="ACI-CopTrax2"

:: start the welcome screen
cd "C:\CopTrax Support\Tools\CopTraxWelcome
Start CopTraxWelcome.exe
Exit
