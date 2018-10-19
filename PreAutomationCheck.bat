@Echo off

:: Set the Welcome screen to be prompt next time
schtasks /Create /SC ONLOGON /TN "ACI\CopTrax Welcome" /TR "C:\CopTrax Support\Tools\CopTraxWelcome\CopTraxWelcome.exe" /F /RL HIGHEST

:: Change the host name of the DVR temporally
setlocal
set RAND=%random%
set NEWNAME=Coptrax-%RAND%
WMIC computersystem where name="%computername%" call rename name="%NEWNAME%"

CLS
Echo Welcome to CopTrax DVR Manufacture Test And Configuration
Echo CopTrax Display Checking
Echo

:DISPLAY
Echo Please check the CopTrax display. 
Echo Type 1 in case you cannot see the bars of CopTrax.
Echo Type 2 in case the bars displayed and you want to continue to manufacture tool test.
CHOICE /N /C:12 /M "PICK A NUMBER (1,2)"%1
IF ERRORLEVEL == 2 GOTO MANUFACTURE
Taskkill /IM IncaXPCApp.exe /F
START /d "C:\Program Files (x86)"\IncaX\CopTrax IncaXPCApp.exe
GOTO DISPLAY

:MANUFACTURE
:: kill the CopTrax process to leave rooms for validation tools and manufacture tools
CLS
Taskkill /IM IncaXPCApp.exe /F

C:
CD "C:\CopTrax Support\tools\Manufacturing Test -01"
ManufacturingTest.exe

CD "C:\CopTrax Support\CopTraxIIValidation"
CopTraxBoxII.exe


CLS
netsh wlan disconnect interface="Wi-Fi 2"
Echo Now it is time to test Wi-Fi connection

:PRIVATE1
Echo Let's try Wi-Fi 1 with private hotspot
netsh wlan connect name=ACI-CopTrax2 interface=WiFi
GOTO PING1

:PUBLIC1
Echo Let's try Wi-Fi 1 with public hotspot
netsh wlan connect name=ACI-CopTrax interface=WiFi

:PING1
Echo Let's ping an external website at www.cnn.com.
timeout /t 10
ping www.cnn.com -n 5
Echo Let's ping an internal website at automation server
ping ENGR-CX456K2 -n 5

Echo Type 1 in case you want to try Wi-Fi 1 test again with private hotspot.
Echo Type 2 in case you want to try Wi-Fi 1 test again with public hotspot again.
Echo Type 3 in case the Wi-Fi test passed and you want to activiate the Windows.
Echo Type 4 in case the Wi-Fi test passed and you want to skip the Windows activation.
CHOICE /N /C:1234 /M "PICK A NUMBER (1,2,3, or 4)"%1
IF ERRORLEVEL == 4 GOTO PRIVATE2
IF ERRORLEVEL == 3 GOTO ACTIVATION
IF ERRORLEVEL == 2 GOTO PUBLIC1
GOTO PRIVATE1

:ACTIVATION
CLS
Echo Now activating the Windows....
cscript c:\windows\system32\slmgr.vbs -ato
Echo Type 1 in case you want to try the activation again.
Echo Type 2 in case the activiation has passed.
CHOICE /N /C:12 /M "PICK A NUMBER (1,2)"%1
IF ERRORLEVEL == 2 GOTO PRIVATE2
GOTO ACTIVATION

:PRIVATE2
CLS
Echo Let's try Wi-Fi 2 with private hotspot
netsh wlan disconnect interface=WiFi
netsh wlan connect name=ACI-CopTrax2 interface="Wi-Fi 2"
GOTO PING2

:PUBLIC2
Echo Let's try Wi-Fi 2 with public hotspot
netsh wlan connect name=ACI-CopTrax interface="Wi-Fi 2"

:PING2
Echo Let's ping an external website at www.cnn.com
timeout /t 10
ping www.cnn.com -n 5
Echo Let's ping an internal website at automation server
ping ENGR-CX456K2 -n 5

Echo Type 1 in case you want to try Wi-Fi 2 test again with private hotspot.
Echo Type 2 in case you want to try Wi-Fi 2 test again with public hotspot.
Echo Type 3 in case the Wi-Fi 2 test has passed.
CHOICE /N /C:123 /M "PICK A NUMBER (1,2,3)"%1
IF ERRORLEVEL == 3 GOTO END
IF ERRORLEVEL == 2 GOTO PUBLIC2
GOTO PRIVATE2

:END
CLS

:: Delete the Welcome Screen task and add the automation task
schtasks /Delete /TN "ACI\CopTrax Welcome" /F
schtasks /Create /SC ONLOGON /TN Automation /TR C:\CopTraxAutomation\automation.bat /F /RL HIGHEST

Echo All the tests passed.
Echo Press any key to end the test for this DVR and turn it to burn-in rack test.
pause


