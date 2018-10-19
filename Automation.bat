Echo This will start the automation test client on the target box
:: Setup the network connection
netsh interface ip set address "CopTrax" dhcp
timeout /t 10
ping ENGR-CX456K2

C:
CD C:\CopTraxAutomation
Start C:\CopTraxAutomation\CopTraxAutomationClient.exe
exit                