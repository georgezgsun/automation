::*****************************************************************
::* Pre-automation check for CopTrax Austin, version 2.8.6        *
::*---------------------------------------------------------------*
::*                 __   _,--="=--,_   __                         *
::*                /  \."    .-.    "./  \                        *
::*               /  ,/  _   : :   _  \/` \                       *
::*               \  `| /o\  :_:  /o\ |\__/                       *
::*                `-'| :="~` _ `~"=: |                           *
::*                   \`     (_)     `/                           *
::*            .-"-.   \      |      /   .-"-.                    *
::*.---------{     }--|  /,.-'-.,\  |--{     }---------.          *
::* )       (_)_)_)  \_/`~-===-~`\_/  (_(_(_)          (          *
::*( By: George Sun, 2019/2                             )         *
::* )Applied Concept Inc.                              (          *
::*'----------------------------------------------------'         *
::*****************************************************************
@ECHO off
TITLE CopTrax Board Test
SETLOCAL EnableDelayedExpansion

CLS
ECHO This is the Board level test of CopTrax.
:: Check if we are running as Admin
FSUTIL dirty query %SystemDrive% >nul
IF ERRORLEVEL 1 (ECHO This batch file need to be run as Admin. && PAUSE && EXIT /B)

:: PAUSE for a couple of seconds
ECHO Starts in 5s.
TIMEOUT /t 5
SET me=BoardTest
SET log=C:\CopTrax Support\%me%.log
ECHO %date%  %~0 > "%log%"

ECHO Checking for the patch.bat exist
IF EXIST D:\Patch.bat (CALL :log Found a patch in thumb drive. Launch it. && CALL D:\Patch.bat)
IF EXIST E:\Patch.bat (CALL :log Found a patch in thumb drive. Launch it. && CALL E:\Patch.bat)
IF EXIST F:\Patch.bat (CALL :log Found a patch in thumb drive. Launch it. && CALL F:\Patch.bat)

:: Set the Welcome screen to be prompt next time
SCHTASKS /Create /SC ONLOGON /TN "ACI\CopTrax Welcome" /TR "C:\CopTrax Support\Tools\CopTraxWelcome\CopTraxWelcome.exe" /F /RL HIGHEST
CALL :log Setup the scheduler task of Welcome Screen.

:: Change the host name of the DVR temporally
::SET RAND=%random%
SET NEWNAME=Coptrax-%random%
WMIC computersystem where name="%computername%" call rename name="%NEWNAME%"
CALL :log Change the hostname of this DVR to %NEWNAME%.

:DISPLAY
ECHO Please check the CopTrax display.
ECHO Type 1 in case you cannot see the bars of CopTrax.
ECHO Type 2 in case the bars displayed and you want to continue to manufacture tool test.
CHOICE /N /C:12 /M "PICK A NUMBER (1 or 2)"%1
IF ERRORLEVEL 2 GOTO MANUFACTURE
CALL :log The display resolution of current CopTrax App is in-correct.
TASKKILL /IM IncaXPCApp.exe /F
START /d "C:\Program Files (x86)"\IncaX\CopTrax IncaXPCApp.exe
CALL :log Restart the CopTrax App to adjust the resolution.
GOTO DISPLAY

:MANUFACTURE
:: kill the CopTrax process to leave rooms for validation tools and manufacture tools
ECHO.
CALL :log Welcome to CopTrax DVR Manufacture Test And Configuration.
TASKKILL /IM IncaXPCApp.exe /F && (CALL :log Killed the CopTrax process to leave rooms for validation tools and manufacture tools.) || (CALL :log No CopTrax is running.)

C:
CD "C:\CopTrax Support\tools\ManufacturingTool"
ManufacturingTest.exe
CALL :log Complete the test with Manufacture Tool.

CD "C:\CopTrax Support\CopTraxIIValidation"
CopTraxBoxII.exe
CALL :log Turned off the heartbeat of the PIC using Validation Tool.

ECHO.
CALL :log Start Wi-Fi test.
CALL :log Now test Wi-Fi 1. Turn the WI-Fi 2 off first.
NETSH wlan disconnect interface="Wi-Fi 2"
SET WIFIProfile=ACI-CopTrax2

:PING1
IF !WIFIProfile! == ACI-CopTrax (SET WIFIProfile=ACI-CopTrax2) ELSE (SET WIFIProfile=ACI-CopTrax)
CALL :log Connecting Wi-Fi 1 to !WIFIProfile!.
NETSH wlan connect name=!WIFIProfile! interface=WiFi
ECHO Please wait for a while to let the Wi-Fi connected.
TIMEOUT /t 5

CALL :log Ping an external website at www.cnn.com.
PING www.cnn.com
IF ERRORLEVEL 1 ( CALL :log Ping failed. & GOTO PING1 )
CALL :log Ping an internal website at automation server.
PING ENGR-CX456K2
IF ERRORLEVEL 1 ( CALL :log Ping failed. & GOTO PING1 )
CALL :log PASSED Wi-Fi Test on Wi-Fi 1. Now testing Wi-Fi 2. Turn the WI-Fi 1 off first.

:PING2
IF !WIFIProfile! == ACI-CopTrax (SET WIFIProfile=ACI-CopTrax2) ELSE (SET WIFIProfile=ACI-CopTrax)
NETSH wlan connect name=!WIFIProfile! interface="WiFi 2"
CALL :log Connecting Wi-Fi 2 to !WIFIProfile!.
ECHO Please wait for a while to let the Wi-Fi connected.
TIMEOUT /t 5

CALL :log Ping an external website at www.cnn.com.
PING www.cnn.com
IF ERRORLEVEL 1 ( CALL :log Ping to www.cnn.com failed. & GOTO PING2 )
CALL :log Ping an internal website at automation server.
PING ENGR-CX456K2
IF ERRORLEVEL 1 ( CALL :log Ping to ENGR-CX456K2 failed. & GOTO PING2 )
CALL :log PASSED Wi-Fi Test on Wi-Fi 2.
ECHO.

:ACTIVIATION
ECHO.
ECHO Type 1 to activiate the Windows.
ECHO Type 2 to skip the Windows activation and do more tests manually.
CHOICE /N /C:12 /M "PICK A NUMBER (1 or 2)"%1
IF ERRORLEVEL 2 (CALL :log Board test end without passed. & Explorer.exe & Exit /B 1)

ECHO Now activating the Windows....
cscript c:\windows\system32\slmgr.vbs -ato
IF ERRORLEVEL 1 (CALL :log FAILED to activiate the Windows & GOTO ACTIVATION)
CALL :log Windows has been successfully activiated.
TIMEOUT /t 3

ECHO.
ECHO Type 1 to remove the RealTek Driver and finish the Board test.
ECHO Type 2 to retry activiation.
CHOICE /N /C:12 /M "PICK A NUMBER (1 or 2)"%1
IF ERRORLEVEL 2 GOTO ACTIVIATION

:: Delete the Welcome Screen task and add the automation task
SCHTASKS /Delete /TN "ACI\CopTrax Welcome" /F && (CALL :log Deleted the scheduler task for Welcome Screen.)
SCHTASKS /Create /SC ONLOGON /TN Automation /TR C:\CopTraxAutomation\automation.bat /F /RL HIGHEST && (CALL :log Added the task for automation.)
"C:\Program Files (x86)\InstallShield Installation Information\{9C049509-055C-4CFF-A116-1D12312225EB}\Install.exe" -uninst
CALL :log Removed the Realtek Driver. All the board tests passed.
ENDLOCAL
EXIT /B 0

:: A function to write to a log file and write to stdout
:log
ECHO %time% : %* >> "%log%"
ECHO %*
EXIT /B 0
