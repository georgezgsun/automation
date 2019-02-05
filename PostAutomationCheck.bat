@Echo off
TITLE CopTrax Final check

CLS
Echo This batch assists to check the CopTrax DVR after the burn-in automation test.

:: Check if we are running as Admin
FSUTIL dirty query %SystemDrive% >nul
IF ERRORLEVEL 1 (ECHO This batch file need to be run as Admin. && PAUSE && EXIT /B)

SET me=FinalCheck
SET log=C:\CopTrax Support\%me%.log
ECHO %date%  %~0 >> "%log%"

:CHECK
Echo Current configuration is
Dir "C:\CopTrax Support\*.flg"
Dir "C:\CopTrax Support\*.flg" >> "%log%"
Echo Please check wheather the CopTrax App and the Body Worn Camera fit this configuration

Echo Type 1 in case the configuration fit and you want to check the camera
Echo Type 2 to configure the DVR manually to 062-124-01 or WSP
Echo Type 3 to configure the DVR manually to 062-124-00 or Universal
Echo Type 4 to cancel the final check
CHOICE /N /C:1234 /M "MAKE YOUR CHOICE (1, 2, 3 or 4)"%1
IF ERRORLEVEL == 4 GOTO BYPASS
IF ERRORLEVEL == 3 GOTO UNIVERSAL
IF ERRORLEVEL == 2 GOTO WSP

CALL :log Confirmed the configuration is correct.

:: Kill the CopTrax process first
Taskkill /IM IncaXPCApp.exe /F && (CALL :log Killed the CopTrax App to leave the room for Manufacturing tool.)
C:
CD "C:\CopTrax Support\Tools\ManufacturingTool"
CALL :log Start Cameras checking.
ManufacturingTest.exe
CALL :log PASSED the test on cameras.

CD \
rmdir /S /Q "C:\CopTrax Support\Tools\ManufacturingTool" && (CALL :log Deleted the manufacture tool.) || (CALL :log Oops when deleting the manufacture tool. && pause)
Echo ncpa.cpl > "C:\CopTrax Support\Tools\Automation.bat" && (CALL :log Updated the Welcome Screen batch file) || (CALL :log Cannot update the Welcome Screen batch file. && pause)

:: Set the Welcome screen to be prompt next time
schtasks /Delete /TN Automation /F 
schtasks /Create /SC ONLOGON /TN "ACI\CopTrax Welcome" /TR "C:\CopTrax Support\Tools\CopTraxWelcome\CopTraxWelcome.exe" /F /RL HIGHEST
CALL :log Deleted the Final Check and set the Welcome Screen to be luanched at next reboot.

CALL :log The final checking has completed. In case the DVR has any problems, please return it to the engineering team.
Echo Press any key to reboot the DVR. Turn the power off when you see the Welcome screen.
pause

Shutdown -r -t 0
Exit

:WSP
CALL :log Required to configure this DVR to WSP.
:: Kill the CopTrax process first
Taskkill /IM IncaXPCApp.exe /F

:: Write configuration file
(Echo release=WSP& Echo.) > "C:\Program Files (x86)\IncaX\CopTrax\CopTrax.config" && CALL :log Changed the configuration to WSP. 
Del /S /F /Q "C:\CopTrax Support\*.flg"
COPY NUL "C:\CopTrax Support\062-124-01 SN PASSED.flg" && CALL :log Changed the flag file.
schtasks /Delete /TN "BWC Manager Startup" /F && CALL :log Disabled the Body Camera.
CLS
CALL :log The CopTrax App has been configured to 062-124-01 or WSP release.
CALL :log The Body Worn Camera Manager is configured not to startup.
CALL :log Restarting the CopTrax App. Please check the re-configure result.
START /D "C:\Program Files (x86)\IncaX\CopTrax" IncaXPCApp.exe
pause
GOTO CHECK
Exit

:UNIVERSAL
CALL :log Required to configure this DVR to Universal.
:: Kill the CopTrax process first
Taskkill /IM IncaXPCApp.exe /F

:: Write configuration file
(Echo release=Universal& Echo.) > "C:\Program Files (x86)\IncaX\CopTrax\CopTrax.config" && CALL :log Changed the configuration to Universal. 
Del /S /F /Q "C:\CopTrax Support\*.flg"
COPY NUL "C:\CopTrax Support\062-124-00 SN PASSED.flg" && CALL :log Changed the flag file.
schtasks /Create /SC ONLOGON /TN "BWC Manager Startup" /TR "C:\Program Files\Applied Concepts Inc\CopTrax Body Camera Manager\MobileCam.exe" /F && CALL :log Enabled the Body Camera.
CLS
CALL :log The CopTrax App has been configured to 062-124-00 or Universal release.
CALL :log The Body Worn Camera Manager is configured to startup.
CALL :log Restarting the CopTrax App. Please check the re-configure result.
START /D "C:\Program Files (x86)\IncaX\CopTrax" IncaXPCApp.exe
pause
GOTO CHECK
Exit

:: Bypass the final check, no welcome screen
:BYPASS
CALL :log Required to bypass the final check.
CD /
rmdir /S /Q "C:\CopTrax Support\Tools\ManufacturingTool" && (CALL :log Deleted the manufacture tool.) || (CALL :log Oops when deleting the manufacture tool. && pause)
Echo ncpa.cpl > "C:\CopTrax Support\Tools\Automation.bat" && (CALL :log Updated the Welcome Screen batch file) || (CALL :log Cannot update the Welcome Screen batch file. && pause)

SCHTASKS /Delete /TN Automation /F
SCHTASKS /Delete /TN "ACI\CopTrax Welcome" /F
CALL :log Deleted the Final Check and the Welcome Screen auto-luanch.
Exit

:: A function to write to a log file and write to stdout
:log
ECHO %time% : %* >> "%log%"
ECHO %*
EXIT /B 0
