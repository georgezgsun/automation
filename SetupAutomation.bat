Echo This will setup the automation test client on the target box
ping localhost -n 5
Taskkill /IM IncaXPCApp.exe /F
C:
CD C:\CopTraxAutomation
copy /Y /V C:\CopTraxAutomation\Cleanup.bat "C:\CopTrax Support\Tools"
copy /Y /V C:\CopTraxAutomation\Automation.bat "C:\CopTrax Support\Tools"
netsh wlan add profile filename="C:\CopTraxAutomation\ACI-CopTrax1.xml"
netsh wlan add profile filename="C:\CopTraxAutomation\ACI-CopTrax2.xml"
schtasks /Delete /TN Automation /F
schtasks /Delete /TN Welcome /F
cd /d "C:\CopTrax Support\Tools\CopTraxWelcome"
EnableWelcomeScreen.exe

