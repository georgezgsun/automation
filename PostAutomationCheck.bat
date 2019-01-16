@Echo off
TITLE CopTrax Final check

:: Set the Welcome screen to be prompt next time
schtasks /Create /SC ONLOGON /TN "ACI\CopTrax Welcome" /TR "C:\CopTrax Support\Tools\CopTraxWelcome\CopTraxWelcome.exe" /F /RL HIGHEST

CLS
Echo This batch assists to check the CopTrax DVR after the burn-in automation test.

:CHECK
Echo Current configuration is
Dir "C:\CopTrax Support\*.flg"
Echo Please check wheather the CopTrax App and the Body Worn Camera fit this configuration

Echo Type 1 in case the configuration fit and you want to check the camera
Echo Type 2 in case you want to configure the DVR manually to 062-124-01 or WSP
Echo Type 3 in case you want to configure the DVR manually to 062-124-00 or Universal
CHOICE /N /C:123 /M "MAKE YOUR CHOICE (1, 2, or 3)"%1
IF ERRORLEVEL == 3 GOTO UNIVERSAL
IF ERRORLEVEL == 2 GOTO WSP

:: Kill the CopTrax process first
Taskkill /IM IncaXPCApp.exe /F
C:
CD "C:\CopTrax Support\Tools\ManufacturingTool"
ManufacturingTest.exe
Echo The final checking has completed. In case the DVR has any problems, please return it to the engineering team.
Echo Press any key to reboot the DVR. Turn the power off when you see the Welcome screen.
pause
rmdir /S /Q "C:\CopTrax Support\Tools\ManufacturingTool" || (Echo Oops when deleting the manufacture tool. && pause)
Echo ncpa.cpl > "C:\CopTrax Support\Tools\Automation.bat" || (Echo Oops when creating new batch file. && pause)
Shutdown -r -t 0
Exit

:WSP
:: Kill the CopTrax process first
Taskkill /IM IncaXPCApp.exe /F

:: Write configuration file
(Echo release=WSP & Echo.) > "C:\Program Files (x86)"\IncaX\CopTrax\CopTrax.config
Del /S /F /Q "C:\CopTrax Support\*.flg"
COPY NUL "C:\CopTrax Support\062-124-01 SN PASSED.flg"
schtasks /Delete /TN "BWC Manager Startup" /F
CLS
Echo The CopTrax App has been configured to 062-124-01 or WSP release.
Echo The Body Worn Camera Manager is configured not to startup.
Echo Press any key to reboot the DVR. Please check the re-configure result after reboot.
pause
Shutdown -r -t 0
Exit

:UNIVERSAL
:: Kill the CopTrax process first
Taskkill /IM IncaXPCApp.exe /F

:: Write configuration file
(Echo release=Universal & Echo.) > "C:\Program Files (x86)"\IncaX\CopTrax\CopTrax.config
Del /S /F /Q "C:\CopTrax Support\*.flg"
COPY NUL "C:\CopTrax Support\062-124-00 SN PASSED.flg"
schtasks /Create /SC ONLOGON /TN "BWC Manager Startup" /TR "C:\Program Files\Applied Concepts Inc\CopTrax Body Camera Manager\MobileCam.exe" /F
CLS
Echo The CopTrax App has been configured to 062-124-00 or Universal release.
Echo The Body Worn Camera Manager is configured to startup.
Echo Press any key to reboot the DVR. Please check the re-configure result after reboot.
pause
Shutdown -r -t 0
Exit
