Echo Warning! This will cleanup the automation test trails
ping localhost -n 10
Taskkill /IM IncaXPCApp.exe /F
schtasks /Delete /TN Automation /F
schtasks /Create /SC ONLOGON /TN "Welcome" /TR "C:\CopTrax Support\Tools\CopTraxWelcome\CopTraxWelcome.exe" /F /RL HIGHEST
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
rmdir /S /Q "C:\Users\coptraxadmin\AppData\Local\IncaX_Limited\"
mkdir "C:\Users\coptraxadmin\AppData\Local\IncaX_Limited\"
Del /Q C:\ProgramData\*coptrax*
netsh wlan delete profile name="ACI-CopTrax1"
netsh wlan delete profile name="ACI-CopTrax2"
regedit.exe /s "C:\CopTrax Support\Tools\SetupAutoEndTasks.reg"
cd "C:\CopTrax Support\Tools\CopTraxWelcome
Start CopTraxWelcome.exe
Exit
