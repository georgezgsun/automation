::**********************************************************
::*   Image builder for CopTrax Austin, version 3.0.0      *
::*--------------------------------------------------------*
::*                __   _,--="=--,_   __                   *
::*               /  \."    .-.    "./  \                  *
::*              /  ,/  _   : :   _  \/` \                 *
::*              \  `| /o\  :_:  /o\ |\__/                 *
::*               `-'| :="~` _ `~"=: |                     *
::*                  \`     (_)     `/                     *
::*           .-"-.   \      |      /   .-"-.              *
::*.---------{     }--|  /,.-'-.,\  |--{     }--------.    *
::* )       (_)_)_)  \_/`~-===-~`\_/  (_(_(_)         (    *
::*(  By: George Sun And Duc T. Nguyen, 2020/01        )   *
::* ) Applied Concepts Inc.                           (    *
::*'---------------------------------------------------'   *
::**********************************************************

::Tasks list for updating 3.0.0 to 3.0.1
:: Task 1: Update automation client to 3.0.1, which has the correct scheduler task setup. ## Manually Done.
:: Task 2: Update CopTraxCam.exe.config to enableBWCM sync with coptrax. ## Manually Done
:: Task 3: Update the IncaXPCApp.exe.config in Automation\Configures\IRoom to have the default audio and video devices specified as
::            <setting name="deviceName" serializeAs="String">
::                <value>Covert MS</value>
::            </setting>
::            <setting name="audioDeviceName" serializeAs="String">
::                <value>Microphone (UM02)</value>

::Task list migrate from 2.8.7 to 3.0.0
:: Task 1: Get Interview Room configurations copied ## Manually Done
:: Task 2: Get Maufacturer Tool downgrade to their prefered version ## verify v1102 is the same production line
:: Task 3: Get TeamViewer server upgraded. Maunally setup.
:: Task 4: Get Intel Wi-Fi adapter setting ## Manually Done
:: Task 5: Get ID Monitor specified   ## Manually Done
:: Task 6: Get scroll bar size enlarged  ## Embedded in the CTapp release.


@ECHO off
TITLE Image builder for CopTrax Austin, version 3.0.0
SETLOCAL EnableDelayedExpansion

CLS
ECHO Warning! This will help to update the DVR to golden image 3.0.0 with log.
:: Check IF we are running as Admin
FSUTIL dirty query %SystemDrive% >nul
IF ERRORLEVEL 1 (ECHO This batch file need to be run as Admin. && PAUSE && EXIT /B)

:: Setup the environment variables
SET Automation=C:\CopTraxAutomation
SET Support=C:\CopTrax Support
SET Tools=%Support%\Tools
SET Welcome=%Tools%\CopTraxWelcome
SET ManufactureTool=%Tools%\ManufacturingTool
SET ValidationTool=%Support%\CopTraxIIValidation
SET IRoom=%Support%\Configures\CT-IRoom

:: PAUSE for a couple of seconds
TIMEOUT /t 5
SET me=%~n0
SET log=%Support%\%me%.log
ECHO %date% Image builder 2.8.5 > "%log%"

:: Update the manufacture tool and automation folders
CD /d %~dp0
FOR /D %%I IN ("%Support%\Manufact*") DO (RMDIR /S /Q "%%I" && CALL :log Deleted the user profile in sub-folder %%I. || CALL :log Oops on deleting %%I.)
FOR /D %%I IN ("%Tools%\Manufact*") DO (RMDIR /S /Q "%%I" && CALL :log Deleted the user profile in sub-folder %%I. || CALL :log Oops on deleting %%I.)

RMDIR /S /Q "%Automation%" && CALL :log Deleted the current version of Automation Tool at %Automation% || CALL :log Oops on deleting Automation Tool.

:: No updrage on Validation tool
::RMDIR /S /Q "%ValidationTool%" && CALL :log Deleted the current version of Validation Tool at %ValidationTool% || CALL :log Oops on deleting Validation Tool 
at %ValidationTool%.
::MKDIR "%ValidationTool%" && (CALL :log Create new subfolder %ValidationTool% for validation tool.) || (CALL :log Cannot create subfolder "%ValidationTool%" for Validation Tool. && PAUSE && EXIT /B 1)
::COPY /Y "CopTraxIIValidation\*.*" "%ValidationTool%" && (CALL :log Copied the latest Validation Tool to %ValidationTool%.) || (CALL :log Cannot copy Validation Tool. && PAUSE && EXIT /B 1)

:: Downgrade the Manuafacturing Tool
MKDIR "%ManufactureTool%"
COPY /Y "Manufacturing Test -01\*.*" "%ManufactureTool%" && (CALL :log Copied the latest Manufacture Tool to %ManufactureTool%.) || (CALL :log Cannot copy Manufactering Tool. && PAUSE && EXIT /B 1)

:: Update the automation
MKDIR "%Automation%"
MKDIR "%Automation%\tmp"
COPY /Y CopTraxAutomation\*.* "%Automation%" && (CALL :log Copied the latest Automation Tool to %Automation%.) || (CALL :log Cannot copy Automation. && PAUSE && EXIT /B 1)

:: No upgrade on Welcome screen
::RMDIR /S /Q "%Welcome%" && CALL :log Deleted the current version of CopTrax Welcome at %Welcome% || CALL :log Oops on deleting Welcome screen.
::MKDIR "%Welcome%"
::MKDIR "%Welcome%\Localization"
::COPY /Y CopTraxWelcome\*.* "%Welcome%" && (CALL :log Copied the latest CorTrax Welcome to %Welcome%.) || (CALL :log Cannot copy CorTrax Welcome. && PAUSE && EXIT /B 1)
::COPY /Y CopTraxWelcome\Localization\*.* "%Welcome%\Localization" && (CALL :log Copied the latest Localization of Welcome to %Welcome%\Localization.) || (CALL :log Cannot copy CorTrax Welcome localization. && PAUSE && EXIT /B 1)

:: Update the Configurations for IRoom
RMDIR /S /Q "%Support%\Configurations" && CALL :log Deleted the current version of Configurations at %Support% || CALL :log Oops on deleting Configurations folder at %Support%.
MKDIR "%IRoom%"
COPY /Y Configures\IRoom\*.* "%IRoom%" && (CALL :log Copied the Interview room files to %IRoom%)
::Restore the launguage of CopTrax App and Body Camera App.
COPY /Y /V IncaXPCApp.exe.config "%ProgramFiles(x86)%\IncaX\CopTrax\IncaXPCApp.exe.config" && (CALL :log Restored the languange of CopTrax App to English.)
COPY /Y /V MobileCam.exe.config "%ProgramFiles%\Applied Concepts Inc\CopTrax Body Camera Manager\MobileCam.exe.config" && (CALL :log Restored the languange of Body Camera to English.)

COPY /Y /V "%Automation%\Cleanup.bat" "%Tools%" && (CALL :log Copied Cleanup.bat to %Tools%.) || (CALL :log Cannot copy Cleanup.bat && PAUSE && EXIT /B 1)
COPY /Y /V "PreAutomationCheck.bat" "%Tools%\Automation.bat" && (CALL :log Copied PreAutomationCheck.bat to replace %Tools%\Automation.bat.) || (CALL :log Cannot copy PreAutomationCheck.bat to "%Tools%\Automation.bat". && PAUSE && EXIT /B 1)
COPY /Y /V CopTraxBoxII.lnk C:\Users\coptraxadmin\Desktop\Utilities && (CALL :log Copied the link of validation tool to the folder of utilities.) || (CALL :log Cannot copy the link of validation tool CopTraxBoxII.lnk C:\Users\coptraxadmin\Desktop\Utilities. && PAUSE && EXIT /B 1)
DEL /Q "C:\Users\coptraxadmin\Desktop\Utilities\Manufacturing Tool.lnk" && (CALL :log Deleted the link of manufacture tool in Utilities.) || (CALL :log Cannot find or delete the link of manufacture tool.)

:: Kill the CopTrax and clear the profile
TASKKILL /IM IncaXPCApp.exe /F && (CALL :log Cleared the running process of CopTrax App.) || (CALL :log No running CopTrax App is found.)
FOR /D %%I IN ("%LocalAppData%\IncaX_Limited\*") DO (RMDIR /S /Q "%%I" && CALL :log Deleted the user profile in sub-folder %%I.)
::RMDIR /S /Q "%LocalAppData%\IncaX_Limited\"
::MKDIR "%LocalAppData%\IncaX_Limited\"
DEL /Q "%ProgramData%\*coptrax*" 
CALL :log Cleaned all the user profile and settings.

:: Delete the video file trailers
DEL /S /F /Q C:\CopTrax-Backup\*.*
DEL /S /F /Q C:\Users\coptraxadmin\Documents\CopTraxTemp\*.*
FOR /D %%I IN ( "%LocalAppData%\coptrax\auto*" ) Do (RMDIR /S /Q "%%I" && CALL :log Deleted the video files in %%I.)
FOR /D %%I IN ( "%LocalAppData%\coptrax\cop*" ) Do (RMDIR /S /Q "%%I" && CALL :log Deleted the video files in %%I.)
::RMDIR /S /Q "%LocalAppData%\coptrax\auto1"
::RMDIR /S /Q "%LocalAppData%\coptrax\auto2"
RMDIR /S /Q "%LocalAppData%\coptrax\cop1"
RMDIR /S /Q "%LocalAppData%\coptrax\cop2"
CALL :log All video files in users folder have been deleted.

:: prepare the Wi-Fi profile, modIFy the autostart scheduler tasks
NETSH wlan Delete profile name="ACI-CopTrax"
NETSH wlan Delete profile name="ACI-CopTrax1"
NETSH wlan Delete profile name="ACI-CopTrax2"
NETSH wlan add profile filename="C:\CopTraxAutomation\ACI-CopTrax.xml" && (CALL :log Setup the Wi-Fi profile of ACI-CopTrax.) || (CALL :log Cannot create Wi-Fi profile of ACI-CopTrax. && PAUSE && EXIT /B 1)
NETSH wlan add profile filename="C:\CopTraxAutomation\ACI-CopTrax2.xml" && (CALL :log Setup the Wi-Fi profile of ACI-CopTrax2.) || (CALL :log Cannot create Wi-Fi profile of ACI-CopTrax2. && PAUSE && EXIT /B 1)
NETSH interface ip set address "CopTrax" static 10.25.50.100 255.255.255.0 && (CALL :log Setup the Ethernet to static IP address.) || (CALL :log Cannot restore static setting for Ethernet. && EXIT /B 1)
CALL :log All the Wi-Fi profiles and the Ethernet have been setup.

SCHTASKS /DELETE /TN Automation /F || CALL :log Cannot Delete the previous Automation scheduler.
SCHTASKS /CREATE /SC ONLOGON /TN "ACI\CopTrax Welcome" /TR "%Welcome%\CopTraxWelcome.exe" /F /RL HIGHEST || (CALL :log Cannot create scheduler task for CopTrax Welcome. && PAUSE && EXIT /B 1)
SCHTASKS /CREATE /SC ONLOGON /TN "BWC Manager Startup" /TR "C:\Program Files\Applied Concepts Inc\CopTrax Body Camera Manager\CoptraxCam.exe" /F /RL HIGHEST' || (CALL :log Cannot create scheduler task for BWC Manager. && PAUSE && EXIT /B 1)
CALL :log Setup the scheduler tasks for CopTrax Welcome and BWC Manager.

:: update the registery key
::REGEDIT.EXE /S "%Automation%\SetupAutoEndTasks.reg" || (CALL :log Cannot modIFy the registry key. && EXIT /B 1)
::CALL :log Updated the registery key.

:: delete the memory leaking service provide by RunSwUSB
::SC config RunSwUSB start= demand
::CALL :log Configured the service RunSwUSB to be started on demand.

:: try to modify the settings of Intel Wi-Fi Adapter
::CD "C:\CopTrax Support\Tools"
::SetIntelWifiOption.exe
::CALL :log Modify the settings of Intel Wi-Fi Adapter

:: try to empty the temp sub-folder
RMDIR /S /Q "%temp%"
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
