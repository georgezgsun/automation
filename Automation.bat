Echo This will setup the automation test client on the target box
netsh wlan connect name=ACI-CopTrax2 interface=WiFi
ping localhost -n 10
schtasks /Delete /TN Welcome /F
C:
CD C:\CopTraxAutomation
Start C:\CopTraxAutomation\CopTraxAutomationClient.exe
exit                