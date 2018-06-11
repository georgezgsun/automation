Echo This will setup the automation test client on the target box
:: start Wi-Fi connection
netsh wlan connect name=ACI-CopTrax2 interface=WiFi

:: pause for a couple of seconds
ping localhost -n 10

:: start automation test
C:
CD C:\CopTraxAutomation
Start C:\CopTraxAutomation\CopTraxAutomationClient.exe
exit                