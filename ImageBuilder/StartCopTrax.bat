Echo This will setup the automation test client on the target box
timeout /t 1
taskkill /IM "Explorer.exe" /F

C:
CD "C:\Program Files (x86)\IncaX\CopTrax"
IncaXPCApp.exe
Start Explorer.exe
Exit