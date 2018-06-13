Echo Warning! This will help to update the golden image
:: pause for a couple of seconds
ping localhost -n 5

:: update the welcome screen, validation tool and automation folders
cd /d %~dp0
rd /s /q "C:\CopTrax Support\Tools\CopTraxWelcome"
mkdir "C:\CopTrax Support\Tools\CopTraxWelcome"
copy /Y CopTraxWelcome\*.* "C:\CopTrax Support\Tools\CopTraxWelcome"
rd /s /q "C:\CopTrax Support\CopTraxIIValidation"
mkdir "C:\CopTrax Support\CopTraxIIValidation"
copy /Y CopTraxIIValidation\*.* "C:\CopTrax Support\CopTraxIIValidation"
rd /s /q C:\CopTraxAutomation
mkdir C:\CopTraxAutomation
mkdir C:\CopTraxAutomation\tmp
copy /Y CopTraxAutomation\*.* C:\CopTraxAutomation

:: copy the files to C:\CopTrax Support\Tools folder
C:
CD C:\CopTraxAutomation
copy /Y /V C:\CopTraxAutomation\Cleanup.bat "C:\CopTrax Support\Tools"
copy /Y /V C:\CopTraxAutomation\Automation.bat "C:\CopTrax Support\Tools"

:: kill the CopTrax and clear the profile
Taskkill /IM IncaXPCApp.exe /F
rmdir /S /Q "C:\Users\coptraxadmin\AppData\Local\IncaX_Limited\"
mkdir "C:\Users\coptraxadmin\AppData\Local\IncaX_Limited\"
Del /Q C:\ProgramData\*coptrax*

:: prepare the Wi-Fi profile, modify the autostart scheduler tasks
netsh wlan add profile filename="C:\CopTraxAutomation\ACI-CopTrax2.xml"
schtasks /Delete /TN Automation /F
schtasks /Delete /TN Welcome /F
schtasks /Create /SC ONLOGON /TN "ACI\CopTrax Welcome" /TR "C:\CopTrax Support\Tools\CopTraxWelcome\CopTraxWelcome.exe" /F /RL HIGHEST

:: update the registery key
regedit.exe /s "C:\CopTraxAutomation\SetupAutoEndTasks.reg"

:: pause to check the results
pause

