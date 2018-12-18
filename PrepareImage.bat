::*****************************************************************
::* Image builder for CopTrax Austin, version 2.8.5               *
::* --------------------------------------------------------------*
::*               __   _,--="=--,_   __                           *
::*              /  \."    .-.    "./  \                          *
::*             /  ,/  _   : :   _  \/` \                         *
::*             \  `| /o\  :_:  /o\ |\__/                         *
::*              `-'| :="~` _ `~"=: |                             *
::*                 \`     (_)     `/                             *
::*          .-"-.   \      |      /   .-"-.                      *
::*.--------{     }--|  /,.-'-.,\  |--{     }--------.            *
::* )      (_)_)_)  \_/`~-===-~`\_/  (_(_(_)         (            *
::*( By: George Sun, Duc T. Nguyen, and My Lien Vuong )           *
::* )2018/12                                         (            *
::*'--------------------------------------------------'           *
::*****************************************************************

@ECHO off
TITLE Image builder for CopTrax Austin, version 2.8.5
SETLOCAL EnableDelayedExpansion

ECHO Warning! This will help to update the DVR to golden image 2.8.5 with log.
:: Check IF we are running as Admin
FSUTIL dirty query %SystemDrive% >nul
IF ERRORLEVEL 1 (ECHO This batch file need to be run as Admin. && PAUSE && EXIT /B)

:: PAUSE for a couple of seconds
TIMEOUT /t 5
SET me=%~n0
SET log=C:\CopTrax Support\%me%.log
ECHO %date% Image builder 2.8.5 > "%log%"

:: update the welcome screen, manufacture tool and automation folders
CD /d %~dp0
RMDIR /S /Q "C:\CopTrax Support\Manufacturing Test -01"
RMDIR /S /Q "C:\CopTrax Support\ManufacturingTool"
RMDIR /S /Q "C:\CopTrax Support\CopTraxWelcome"
RMDIR /S /Q "C:\CopTrax Support\Tools\CopTraxWelcome"
RMDIR /S /Q C:\CopTraxAutomation
CALL :log Deleted the current version of Manufacture Tool, Automation tool, and CopTrac Welcome.

MKDIR "C:\CopTrax Support\Tools\Manufacturing Test -01"
COPY /Y "Manufacturing Test -01\*.*" "C:\CopTrax Support\Tools\Manufacturing Test -01" && (CALL :log Copied the latest Manufacture Tool to "C:\CopTrax Support\Tools\Manufacturing Test -01\".) || (CALL :log Cannot copy Manufactering Tool. && EXIT /B 1)

MKDIR C:\CopTraxAutomation
MKDIR C:\CopTraxAutomation\tmp
COPY /Y CopTraxAutomation\*.* C:\CopTraxAutomation && (CALL :log Copied the latest Automation Tool to C:\CopTraxAutomation\.) || (CALL :log Cannot copy Automation. && EXIT /B 1)

MKDIR "C:\CopTrax Support\Tools\CopTraxWelcome"
COPY /Y CopTraxWelcome\*.* "C:\CopTrax Support\Tools\CopTraxWelcome" && (CALL :log Copied the latest CorTrax Welcome to C:\CopTrax Support\Tools\CopTraxWelcome\.) || (CALL :log Cannot copy CorTrax Welcome. && EXIT /B 1)
MKDIR "C:\CopTrax Support\Tools\CopTraxWelcome\Localization"
COPY /Y CopTraxWelcome\Localization\*.* "C:\CopTrax Support\Tools\CopTraxWelcome\Localization" (CALL :log Copied the latest localization setting of CorTrax Welcome to C:\CopTrax Support\Tools\CopTraxWelcome\Localization\.)|| (CALL :log Cannot copy the localization setting of CorTrax Welcome. && EXIT /B 1)
CALL :log Copied the CopTrax Welcome.

COPY /Y /V IncaXPCApp.exe.config "C:\Program Files (x86)\IncaX\CopTrax\IncaXPCApp.exe.config" && (CALL :log Restored the languange of CopTrax App to English.)
COPY /Y /V MobileCam.exe.config "C:\Program Files\Applied Concepts Inc\CopTrax Body Camera Manager\MobileCam.exe.config" && (CALL :log Restored the languange of Body Camera to English.)

:: Copy the selected files to C:\CopTrax Support\Tools folder
COPY /Y /V C:\CopTraxAutomation\Cleanup.bat "C:\CopTrax Support\Tools" && (CALL :log Copied Cleanup.bat to C:\CopTrax Support\Tools\.) || (CALL :log Cannot copy Cleanup.bat && EXIT /B 1)
COPY /Y /V C:\CopTraxAutomation\PreAutomationCheck.bat "C:\CopTrax Support\Tools\Automation.bat"  && (CALL :log Copied PreAutomationCheck.bat to replace C:\CopTrax Support\Tools\Automation.bat.) || (CALL :log Cannot copy PreAutomationCheck.bat. && EXIT /B 1)

:: kill the CopTrax and clear the profile
TASKKILL /IM IncaXPCApp.exe /F && (CALL :log Cleared the running process of CopTrax App.) || (CALL :log No running CopTrax App is found.)

RMDIR /S /Q "C:\Users\coptraxadmin\AppData\Local\IncaX_Limited\"
MKDIR "C:\Users\coptraxadmin\AppData\Local\IncaX_Limited\"
DEL /Q C:\ProgramData\*coptrax*
CALL :log Cleaned all the user profile and settings.

:: DELete the video file trailers
DEL /S /F /Q C:\CopTrax-Backup\*.*
DEL /S /F /Q C:\Users\coptraxadmin\Documents\CopTraxTemp\*.*
RMDIR /S /Q "C:\Users\coptraxadmin\AppData\Local\coptrax\auto1\"
RMDIR /S /Q "C:\Users\coptraxadmin\AppData\Local\coptrax\auto2\"
RMDIR /S /Q "C:\Users\coptraxadmin\AppData\Local\coptrax\auto3\"
RMDIR /S /Q "C:\Users\coptraxadmin\AppData\Local\coptrax\auto4\"
CALL :log Deleted all video files from users folder.

:: prepare the Wi-Fi profile, modIFy the autostart scheduler tasks
NETSH wlan Delete profile name="ACI-CopTrax"
NETSH wlan Delete profile name="ACI-CopTrax1"
NETSH wlan Delete profile name="ACI-CopTrax2"
NETSH wlan add profile filename="C:\CopTraxAutomation\ACI-CopTrax.xml" || (CALL :log Cannot create Wi-Fi profile of ACI-CopTrax. && EXIT /B 1)
NETSH wlan add profile filename="C:\CopTraxAutomation\ACI-CopTrax2.xml" || (CALL :log Cannot create Wi-Fi profile of ACI-CopTrax2. && EXIT /B 1)
::NETSH interface ip set address "CopTrax" static 10.25.50.100 255.255.255.0 || (CALL :log Cannot restore static setting for Ethernet. && EXIT /B 1)
CALL :log Setup the Wi-Fi profiles and restore static setting for Ethernet.

SCHTASKS /DELETE /TN Automation /F || (CALL :log Cannot DELete the previous Automation scheduler. && EXIT /B 1)
SCHTASKS /CREATE /SC ONLOGON /TN "ACI\CopTrax Welcome" /TR "C:\CopTrax Support\Tools\CopTraxWelcome\CopTraxWelcome.exe" /F /RL HIGHEST || (CALL :log Cannot create scheduler task for CopTrax Welcome. && EXIT /B 1)
CALL :log Setup the scheduler tasks of CopTrax Welcome.

:: update the registery key
REGEDIT.EXE /S "C:\CopTraxAutomation\SetupAutoEndTasks.reg" || (CALL :log Cannot modIFy the registry key. && EXIT /B 1)
CALL :log Updated the registery key.

:: try to empty the temp sub-folder
RMDIR /S /Q %temp%
CALL :log The temp folder at "%temp%" has been cleaned.
ECHO The log is saved at "%log%".

:: PAUSE to check the results
CALL :log The image has been prepared.
ENDLOCAL
PAUSE
EXIT /B 0

:: A function to write to a log file and write to stdout
:log
ECHO %time% : %* >> "%log%"
ECHO %*
EXIT /B 0
