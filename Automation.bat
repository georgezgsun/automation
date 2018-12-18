Echo This will setup the automation test client on the target box
netsh interface ip set address "CopTrax" dhcp
timeout /t 10
ping ENGR-CX456K2 -n 5

C:
CD C:\CopTraxAutomation
Start C:\CopTraxAutomation\CopTraxAutomationClient.exe
exit                