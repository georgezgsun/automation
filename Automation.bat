Echo This will setup the automation test client on the target box
ping localhost -n 5
C:
CD C:\CopTraxAutomation
copy /Y /V C:\CopTraxAutomation\Cleanup.bat "C:\CopTrax Support\Tools"
netsh wlan add profile filename="C:\CopTraxAutomation\ACI-CopTrax1.xml"
netsh wlan add profile filename="C:\CopTraxAutomation\ACI-CopTrax2.xml"
schtasks /Create /XML C:\CopTraxAutomation\autorun.xml /TN Automation
start /d C:\CopTraxAutomation CopTraxAutomationClient.exe
exit