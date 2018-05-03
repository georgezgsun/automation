Echo This will setup the automation test client on the target box
ping localhost -n 10
schtasks /Delete /TN Welcome /F
C:
CD C:\CopTraxAutomation
Start C:\CopTraxAutomation\CopTraxAutomationClient.exe
exit