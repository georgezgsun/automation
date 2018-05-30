#RequireAdmin

#pragma compile(FileVersion, 3.4.10.26)
#pragma compile(FileDescription, Automation test client)
#pragma compile(ProductName, AutomationTest)
#pragma compile(ProductVersion, 2.4)
#pragma compile(CompanyName, 'Stalker')
#pragma compile(Icon, automation.ico)
;
; Test client for CopTrax Version: 3.2
; Language:       AutoIt
; Platform:       Win8
; Script Function:
;   Connect to a test server
;   Wait CopTrax app to , waiting its powerup and connection to the server;
;   Send test commands from the test case to individual target(client);
;	Receive test results from the target(client), verify it passed or failed, log the result;
;	Drop the connection to the client when the test completed.
; Author: George Sun
; Nov., 2017
;

#include <Constants.au3>
#include <File.au3>
#include <ScreenCapture.au3>
#include <Array.au3>
#include <Timers.au3>
#include <Date.au3>
#include <Misc.au3>
#include <StringConstants.au3>
#include <EventLog.au3>

_Singleton('Automation test client')

HotKeySet("{Esc}", "HotKeyPressed") ; Esc to stop testing
HotKeySet("^q", "HotKeyPressed") ; Esc to stop testing
HotKeySet("+!t", "HotKeyPressed") ; Shift-Alt-t to stop CopTrax
HotKeySet("+!s", "HotKeyPressed") ; Shift-Alt-s, to start CopTrax
HotKeySet("+!r", "HotKeyPressed") ; Shift-Alt-r, to restart the automation test client
HotKeySet("!{SPACE}", "HotKeyPressed") ; Alt-Space show the running CopTraxAutomation
HotKeySet("^{SPACE}", "HotKeyPressed") ; Ctrl-Space show the running CopTraxAutomation

Global Const $titleCopTraxMain = "CopTrax II v"	; "CopTrax II v2.x.x"
Global Const $titleAccount = "Account" ; "CopTrax - Login / Create Account"
Global Const $titleInfo = "Action" ; "Menu Action"
Global Const $titleAbout = "About" ; About CopTrax II
Global Const $titleLogin = "Login"
Global Const $titleRadar = "Radar" ; "CopTrax | Radar"
Global Const $titleReview = "Playback" ; "CopTrax | Video Playback"
Global Const $titleSettings = "Setup" ; "CopTrax II Setup"
Global Const $titleStatus = "CopTrax Status" ; "CopTrax Status"
Global Const $titleEndRecord = "Report Taken" ; "Report Taken"
Global Const $titlePhoto = "Information" ; Photo
Global Const $TIMEOUTINSECEND = 150
Global Const $maxSendLength = 100000	; set maximum legth of bytes that a TCPsend command may send

TCPStartup()
Global $ip =  TCPNameToIP("10.0.5.211")
Global $port = 16869
Global $Socket = -1
Global $boxID = "Unknown"
Global $CopTraxAppDir = "C:\Program Files (x86)\IncaX\CopTrax\"
Global $configDir = $CopTraxAppDir
Global $mapDir = @LocalAppDataDir & "\CopTraxEvidenceViewer\"
Global $bwcDir = "C:\Program Files (x86)\VIA\Icon Files"
Global $firmwareVersion = ""
Global $libraryVersion = ""
Global $appVersion = ""
Global $releaseRead = ""
Global $releaseSet = "Unset"
Global $title = "CopTrax II is not up yet"
Global $userName = ""
Global $sentPattern = ""

Global $filesToBeSent = ""
Global $uploadMode = "idle"
Global $fileContent = ""
Global $bytesCounter = 0
Global $workDir = @ScriptDir & "\"
Global $configFile = $workDir & "client.cfg"
Global $logFile = FileOpen( $workDir & "local.log", 1+8)
ReadConfig()
Run(@comSpec & ' /c schtasks /Delete /TN "ACI\CopTrax Welcome" /F')	; Delete the scheduler task for Welcome Screen
Run(@ComSpec & " /c schtasks /Create /SC ONLOGON /TN Automation /TR C:\CopTraxAutomation\automation.bat /F")	; Enable the Automation next time

Global $fileToBeUpdate = $workDir & "tmp\" & @ScriptName
Global $testEnd = FileExists($fileToBeUpdate) ? FileGetVersion(@AutoItExe) <> FileGetVersion($fileToBeUpdate) : False
If FileGetSize($fileToBeUpdate) < 1000000 Then $testEnd = False	; update the client file only when it was completetly downloaded
$fileToBeUpdate = 0
Global $restart = $testEnd
Global Const $mMB = "CopTrax GUI Automation Test"

If $testEnd Then
	MsgBox($MB_OK, $mMB, "Automation test finds new update." & @CRLF & "Restarting now to complete the update.", 2)
	RestartAutomation()
	Exit
EndIf

Global $chunkTime = 30
Global $mCopTrax = 0
Global $pCopTrax = "IncaXPCApp.exe"
Global $hEventLogSystem = _EventLog__Open("", "System")
Global $hEventLogApp = _EventLog__Open("", "Application")
Global $hEventLogCopTrax = _EventLog__Open("", "ACI_CopTrax_Log")
_EventLog__Read($hEventLogSystem, True, False)
_EventLog__Read($hEventLogApp, True, False)
_EventLog__Read($hEventLogCopTrax, True, False)

OnAutoItExitRegister("OnAutoItExit")	; Register OnAutoItExit to be called when the script is closed.
AutoItSetOption ("WinTitleMatchMode", 2)
AutoItSetOption("SendKeyDelay", 100)

If WinExists("", "Open CopTrax") Then	; In case there running the welcome screen, exit
	Exit
EndIf

$Socket = TCPConnect($ip, $port)
Do	; Try to confirm the running of CopTrax App and the network connection to server before running automation
	If Not ProcessExists($pCopTrax) Then
		RunCopTrax()
		MsgBox($MB_OK, $mMB, "Waiting for CopTrax App to run..", 2)
	EndIf

	If $Socket < 0 Then
		MsgBox($MB_OK, $mMB, "Unable connected to server. Please check the network connection or the server.", 2)
		$Socket = TCPConnect($ip, $port)
	EndIf
Until ProcessExists($pCopTrax) And $Socket > 0
MsgBox($MB_OK, $mMB, "Found CopTrax App running. Connected to server at " & $ip & ". Starting automation test." & @CRLF & "Esc to quit.", 5)
FileClose($logFile)
$logFile = 0

If WinExists($titleAccount) Then
	MsgBox($MB_OK, $mMB, "First time run. Try to create a temporal acount.", 2)
	WinActivate($titleAccount)

	If Not CreateNewAccount("auto1", "coptrax") Then
		MsgBox($MB_OK, $mMB, "Something wrong! Have to reboot the box now.", 5)
		Shutdown(2+4)	; force the window to reboot
		Exit
	EndIf
EndIf

While $mCopTrax = 0
	$mCopTrax = WinActivate($titleCopTraxMain)
	If $mCopTrax And Not IsDisplayCorrect() Then
		LogUpload("Coptrax Display malfunction. Restart it")
		ProcessClose($pCopTrax)
		Sleep(1000)
		RunCopTrax()
	EndIf

	If $mCopTrax Then
		$userName = GetUserName()
		If IsRecording() Then
			EndRecording(True)	; stop any recording in progress before automation test
		EndIf
	Else
		MsgBox($MB_OK, $mMB, "CopTrax II is not up yet.", 2)
	EndIf
WEnd

Local $count = 3
While Not StringRegExp($boxID, "[A-Za-z]{2}[0-9]{6}") And ($count > 0)	; try to get the serial number before the start of automation
	MsgBox($MB_OK, $mMB, "Now reading Serial Number from the box.", 2)
	TestSettingsFunction("NULL")
	$count -= 1
WEnd
If $count <= 0 Then
	MsgBox($MB_OK, $mMB, "Cannot read the serial number of the box! Have to quit the automation test now.", 5)
	Exit
EndIf

Local $path0 = @MyDocumentsDir & "\CopTraxTemp"
Local $path1 = GetVideoFilePath()
Local $path2 = $path1 & "\cam2"
Global $videoFilesCam1 = GetVideoFileNum($path1, "*.wmv") + GetVideoFileNum($path0, @MDAY & "*.mp4")
Global $videoFilesCam2 = GetVideoFileNum($path2, "*.wmv") + GetVideoFileNum($path2, "*.avi")
Global $hTimer = TimerInit()	; Begin the timer and store the handler
Global $timeout = 20*1000	; Set the first time out to be 20s later

LogUpload("name " & $boxID & " new " & FileGetVersion(@AutoItExe) & " " & $title & " " & @DesktopWidth & "x" & @DesktopHeight)	; new start of automation test

Local $currentTime
While Not $testEnd
	$currentTime = TimerDiff($hTimer)
	If $mCopTrax = 0 Then
		$mCopTrax = WinActivate($titleCopTraxMain)
		If $mCopTrax <> 0 Then
			$userName = GetUserName()
		EndIf
	EndIf

	If $Socket < 0 Then
		$Socket = TCPConnect($ip, $port)
		$err = @error
		If $Socket > 0 Then
			If $logFile Then
				FileClose($logFile)	; close local log
				$logFile = 0;
			EndIf

			LogUpload("name " & $boxID & " resume " & FileGetVersion(@AutoItExe) & " " & $title & " " & @DesktopWidth & "x" & @DesktopHeight)
			MsgBox($MB_OK, $mMB, "Connected to server.",2)
			$timeout = $currentTime + 1000*$TIMEOUTINSECEND
		Else
	  		If  $currentTime > $timeout Then
				MsgBox($MB_OK, $mMB, "Unable connected to server. Please check the network connection or the server." & @CRLF &"Error code " & $err, 5)
				$timeout = $currentTime + 1000*10	; check the networks connection every 10s.
				TCPCloseSocket($Socket)
				$Socket = -1
				$logFile = FileOpen( $workDir & "local.log", 1+8)
			EndIf
		EndIf
   Else
	  If ListenToNewCommand() Then
		$timeout = $currentTime + 1000 * $TIMEOUTINSECEND
	  EndIf

	  If  $currentTime > $timeout Then
		$Socket = -1
	  EndIf
   EndIf
   Sleep(100)
WEnd

If $restart Then
	If IsRecording() Then
		EndRecording(True)	; stops any recording in progress before automation restart
	EndIf
	LogUpload("The automation test will be restarted.")
	MsgBox($MB_OK, $mMB, "Reatarting the automation test.",2)
	RestartAutomation()
Else
	LogUpload("End of automation test.")
	MsgBox($MB_OK, $mMB, "Testing ends. Bye.",2)
EndIf

If $fileToBeUpdate Then
	FileClose($fileToBeUpdate)
EndIf

_EventLog__Close($hEventLogSystem)
_EventLog__Close($hEventLogApp)
_EventLog__Close($hEventLogCopTrax)

Exit

Func RunValidationTool()
	If Not GetHandleWindowWait("Trigger") Then
		LogUpload("Unable to trigger Validation Tool. Reboot now.")
		Shutdown(2+4)	; force the window to reboot
		Exit
	EndIf

	Local $hWnd = WinActivate("Trigger","")

	ControlClick($hWnd, "", "[NAME:libConnect]")
	Sleep(1000)
	Local $title = WinGetTitle($hwnd) ; CopTraxII -  Library Version:  1.0.1.5, Firmware Version:  2.1.1
	Local $splittedTitle = StringRegExp($title, "([0-9]+\.[0-9]+\.[0-9]+\.?[0-9a-zA-Z]*)", $STR_REGEXPARRAYGLOBALMATCH)
	If IsArray($splittedTitle) And UBound($splittedTitle) = 2 Then
		$libraryVersion = $splittedTitle[0]
		$firmwareVersion = $splittedTitle[1]
	EndIf
	$splittedTitle = StringRegExp(WinGetText($hwnd), "(?:Product: )([A-Za-z]{2}[0-9]{6})")
	If IsArray($splittedTitle) Then
		$userName = $splittedTitle[0]
		LogUpload("Changed the box ID in config file.")
		RenewConfig()
	EndIf

	LogUpload("Reading from validation tool, the serial number of the box is " & $userName & ", the firmware version is " & $firmwareVersion & ", the library version is " & $libraryVersion)

	ControlClick($hWnd, "", "[NAME:radioButton_HBOff]")	; set the heartbeat to off, preventing unnecessary reboot

	WinWaitClose($hwnd)
	Return
EndFunc

Func RestartAutomation()
	Local $filename = $workDir & "RestartClient.bat"
	Local $sourceFile = $workDir & "tmp\" & @ScriptName
	Local $file = FileOpen($filename, $FO_OVERWRITE)
	FileWriteLine($file,"ping localhost -n 10")
	If (FileGetSize($sourcefile) > 1000000) And (_VersionCompare(FileGetVersion(@AutoItExe), FileGetVersion($sourceFile)) < 0) Then
		FileWriteLine($file,"copy /Y " & $sourceFile & " " & @AutoItExe)
	EndIf
	FileWriteLine($file,"del " & $sourceFile)
	FileWriteLine($file, "start  /d " & $workDir & " " & @AutoItExe)
	FileClose($file)

	Run($filename)	; restart the automation test client
EndFunc

Func GetUserName()
	If $mCopTrax = 0 Then Return "Not Ready!"

	$title = WinGetTitle($mCopTrax) ;"CopTrax Status"
	Local $splittedTitle = StringRegExp($title, "[0-9]+\.[0-9]+\.[0-9]+\.?[0-9a-zA-Z]*", $STR_REGEXPARRAYMATCH)
	If $splittedTitle = "" Then Return "Wrong app version!"
	$appVersion = $splittedTitle[0]

	Local $begin = StringInStr($title, "[")
	Local $end = StringInStr($title, "]")
	If $begin And $end Then
		Return StringMid($title, $begin+1, $end-$begin-1)
	Else
		Return "Wrong user name!"
	EndIf
EndFunc

Func QuitCopTrax()
	If Not ProcessExists($pCopTrax) Then
		$mCopTrax = 0
		LogUpload("No CopTrax App is running.")
		Return true
	EndIf

	LogUpload("Try to stop CopTrax App.")

	If Not ReadyForTest() Then Return ProcessClose($pCopTrax)

	If IsRecording() And Not EndRecording(True) Then
		LogUpload("A recording is in progress. Unable to end it. Now force to kill it.")
		$mCopTrax = 0
		Return ProcessClose($pCopTrax)
	EndIf

	AutoItSetOption("SendKeyDelay", 200)
	MouseClick("",960,560)	; click on the info button
	Sleep(400)

	If Not GetHandleWindowWait($titleInfo, "", 10) Then
		MsgBox($MB_OK, $mMB, "Unable to trigger the Info window. " & @CRLF, 5)
		LogUpload("Unable to open the info window by click on the info button.")
		$mCopTrax = 0
		Return ProcessClose($pCopTrax)
	EndIf

	Sleep(500)
	Send("{TAB}{END}{TAB}{ENTER}")	; choose the Administrator
	If Not GetHandleWindowWait($titleLogin, "", 10) Then
		MsgBox($MB_OK, $mMB, "Unable to trigger the Login window.",2)
		LogUpload("Unable to close the Login window by click on Apply button.")
		$mCopTrax = 0
		Return ProcessClose($pCopTrax)
	EndIf

	Send("135799{TAB}{ENTER}")	; type the administator password
	MouseClick("", 500, 150)
	Local $hWnd = $mCopTrax
	$mCopTrax = 0
	Return WinWaitClose($hWnd, "", 10)
EndFunc

Func TestAbout()
	LogUpload("Try to read CopTrax App about info.")

	If Not ReadyForTest() Then Return False

	If IsRecording() Then
		LogUpload("A recording is in progress.")
		Return False
	EndIf

	MouseClick("",960,560)	; click on the info button
	Sleep(400)

	If Not GetHandleWindowWait($titleInfo, "", 10) Then
		MsgBox($MB_OK, $mMB, "Unable to trigger the Info window. " & @CRLF, 5)
		LogUpload("Unable to open the info window by click on the info button.")
		Return False
	EndIf

	Sleep(500)
	Send("{TAB}{HOME}{TAB}{ENTER}")	; choose the Administrator
	Local $hWnd = GetHandleWindowWait($titleAbout, "OK", 5)
	If Not $hWnd Then
		MsgBox($MB_OK, $mMB, "Unable to trigger the About window.",2)
		LogUpload("Unable to close the About window by click on Apply button.")
		Return False
	EndIf

	$releaseRead = ""
	Local $txt = WinGetText($hWnd)
	Local $releaseTemp = StringRegExp($txt, "(?:[0-9]+\.[0-9]+\.[0-9]+\.?[0-9a-zA-Z]* )([a-zA-Z]*)", $STR_REGEXPARRAYGLOBALMATCH)
	If IsArray($releaseTemp) Then
		$releaseRead = $releaseTemp[0]
	EndIf

	TakeScreenCapture("About info of CopTrax II", $hWnd)
	Send("{Enter}")

	Return True
EndFunc

Func TestUserSwitchFunction($arg)
	If Not ReadyForTest() Then  Return False
	If IsRecording() Then
		LogUpload("A recording is in progress.")
		Return False
	EndIf

	Local $username = GetParameter($arg, "username")
	Local $password = GetParameter($arg, "password")

	If Not StringRegExp($username, "([a-zA-Z][a-zA-Z0-9]{4,})") Or Not StringRegExp($password, "([a-zA-Z0-9]{7,})") Then
		MsgBox($MB_OK, $mMB, "username or password format in-correct. " & @CRLF, 5)
		LogUpload("username or password format in-correct. ")
		Return False
	EndIf

	AutoItSetOption("SendKeyDelay", 200)
	MouseClick("",960,560)	; click on the info button
	Sleep(400)

	Local $mTitle = $titleInfo
	If Not GetHandleWindowWait($mTitle, "", 10) Then
		MsgBox($MB_OK, $mMB, "Unable to trigger the info window. " & @CRLF, 5)
		LogUpload("Unable to open the info window by click on the info button.")
		WinClose($mTitle)
		Return False
	EndIf

	Sleep(500)
	Send("{Tab}s{Tab}{Enter}")	; choose switch Account
	Sleep(500)

	Return CreateNewAccount($username, $password)
EndFunc

Func CreateNewAccount($name, $password)
	Local $hWnd = GetHandleWindowWait($titleAccount, "Register", 10)
	Local $hServer = 0
	Local $txt = ""
	If  $hWnd = 0 Then
		MsgBox($MB_OK, $mMB, "Unable to trigger the CopTrax-Login/Create Account window. " & @CRLF, 5)
		If WinExists("CopTrax","OK") Then
			$txt = WinGetText("CopTrax","OK")
			WinClose("CopTrax","OK")
		EndIf
		LogUpload("Unable to trigger the CopTrax-Login/Create Account window. Screen reading are " & $txt)
		Return False
	EndIf

	$txt = WinGetText($hWnd)
	If StringInStr($txt, "Key") Then
		$releaseRead = "Universal"
		ControlClick($hWnd, "", "[REGEXPCLASS:(.*COMBOBOX.*); INSTANCE:1]")
		Send("{END}")
		$hServer = GetHandleWindowWait("Server", "Test")
		If Not $hServer Then
			MsgBox($MB_OK, $mMB, "Unable to open Server Configuration window. " & @CRLF, 5)
			LogUpload("Unable to open Server Configuration window. ")
			WinClose($hWnd)
			Return False
		EndIf

		Sleep(500)
		If Not ControlFocus($hServer, "Test", "[REGEXPCLASS:(.*EDIT.*); INSTANCE:2]") Then
			WinClose($hServer)
			LogUpload("Unable to focus on the Host Name input on handler " & $hServer & ".")
		EndIf
		Send("10.0.6.32")
		ControlCommand($hServer, "", "[INSTANCE:1]", "Check")
		ControlClick($hServer, "", "Test")

		Local $i=0
		Do
			$txt = WinGetText($hServer, "Test")
			$i += 1
			Sleep(1000)
		Until StringInStr($txt, "Connection OK") Or $i > 10

		If $i > 10 Then
			WinClose($hServer)
			LogUpload("Unable to connect to the required server. The text read are " & $txt & @CRLF & ".")
			WinClose($hWnd)
			Return False
		EndIf
		ControlClick("Server", "", "OK")
		WinWaitClose("Server", "", 5)

		Sleep(500)
		Send("{TAB 2}")
	Else
		$releaseRead = "WSP"
	EndIf

	If $testEnd Then Return False

	Send("{End}+{Home}" & $name & "{Tab}")
	Sleep(500)

	Send("{End}+{Home}" & $password & "{Tab}")	; type the user password
	Sleep(500)
	Send("{End}+{Home}" & $password & "{Tab}")	; re-type the user password

	Sleep(2000)
	$txt = WinGetText($hWnd)
	ControlClick($hWnd, "", "Register")
	If WinWaitClose($hWnd,"",10) = 0 Then
		MsgBox($MB_OK, $mMB, "Clickon the Register button to close the window failed.",2)
		LogUpload("Unable to exit by click on the Register button. Messages in windows are " & $txt)
		WinClose($hWnd)
		Return False
	EndIf

	Sleep(1000)
	$txt = "CopTrax"
	If WinExists($txt,"restart") Then
		ControlClick($txt, "restart", "OK")
	EndIf
	LogUpload("New profile has been created. CopTrax will restart. Automation will wait.")

	$mCopTrax = 0
	Local $i = 5
	While WinExists($titleStatus) And ($i > 0)
		Sleep(1000)
		$i -= 1
	WEnd
	If $i <= 0 Then
		LogUpload("The accessories are not ready yet.")
		TakeScreenCapture("Accessories not ready", WinActive($titleStatus))
		Return False
	EndIf

	$mCopTrax = GetHandleWindowWait($titleCopTraxMain)
	If Not $mCopTrax Then
		LogUpload("CopTrax App is unable to restart.")
		Return False
	EndIf

	$userName = GetUserName()
	If $userName <> $name Then
		LogUpload("Unable to switch user. Current user is " & $userName)
		Return False
	Else
		LogUpload("Current user is switched to " & $userName)
	EndIf

	Local $path0 = @MyDocumentsDir & "\CopTraxTemp"
	Local $path1 = GetVideoFilePath()
	Local $path2 = $path1 & "\cam2"

	$videoFilesCam1 = GetVideoFileNum($path1, "*.wmv") + GetVideoFileNum($path0, @MDAY & "*.mp4")
	$videoFilesCam2 = GetVideoFileNum($path2, "*.wmv") + GetVideoFileNum($path2, "*.avi")
	Return True
EndFunc

Func StartRecord($click)
	If Not ReadyForTest() Then  Return False

	LogUpload("Testing start record function.")
	If $click Then
		If IsRecording() Then	; check if a recording in-progress or not
			LogUpload("Another recording is already in progress or have not yet completed.")
			Return False
		Else
			MouseClick("", 960, 80)	; click on the button to start record
		EndIf
	EndIf

	Local $i
	For $i = 1 To 15
		Sleep(1000)	; Wait for 15sec for record begin recording
		If IsRecording() Then	; check if a recording in-progress or not
			LogUpload("Recording start successfully.")
			Return True
		EndIf
	Next
	Return False
EndFunc

Func EndRecording($click)
	LogUpload("Testing stop record function.")

	If $click Then
		If Not ReadyForTest() Then  Return False

		If Not IsRecording() Then	; check if the specified *.mp4 files is modifying
			LogUpload("No recording in progress.")
			Return False
		EndIf

		MsgBox($MB_OK, $mMB, "Testing stop record function.", 2)
		Local $i=0
		Do
			MouseClick("", 960, 80)	; click on the button to stop record
			$i += 1
		Until GetHandleWindowWait($titleEndRecord, "OK") Or ($i > 3)
	EndIf

	Local $hEndRecord = GetHandleWindowWait($titleEndRecord, "OK")
	If $hEndRecord = 0 Then
		If $click Then
			LogUpload("Unable to stop the record by a click on the button. ")
		Else
			LogUpload("Unable to stop the record by light switch button. ")
		EndIf
		MsgBox($MB_OK,  $mMB, "Unable to trigger the end record function",2)
		Return False
	EndIf

	ControlSend($hEndRecord, "", "[REGEXPCLASS:(?i)(.*EDIT.*); INSTANCE:1]", "CopTrax automation test.")
	Sleep(1000)
	ControlClick($hEndRecord,"","OK")
	Sleep(100)

	If WinWaitClose($hEndRecord,"",10)  Then
		Return True
	Else
		MsgBox($MB_OK,  $mMB, "Click on the OK button failed",2)
		LogUpload("Unable to stop the dialog by click on the OK button.")
		WinClose($hEndRecord)
		Return False
	EndIf
EndFunc

Func TestSettingsFunction($arg)
	If Not ReadyForTest() Then  Return False
	If IsRecording() Then
		LogUpload("A recording is in progress. Cannot modify the settings.")
		Return False
	EndIf

	Local $pre = GetParameter($arg, "pre")
	Local $chunk = GetParameter($arg, "chunk")
	Local $cam2 = GetParameter($arg, "cam2")
	Local $cam3 = GetParameter($arg, "cam3")
	Local $keyboard = GetParameter($arg, "keyboard")

	MouseClick("",960, 460)
	LogUpload("Start settings function testing.")

	If GetHandleWindowWait($titleLogin) Then
		Send("135799{TAB}{ENTER}")	; type the administator password
		MouseClick("", 500, 150)
		$releaseRead = "WSP"
	Else
		$releaseRead = "Universal"
	EndIf

	Local $hWnd = GetHandleWindowWait($titleSettings, "", 10)	;"CopTrax II Setup"
	If $hWnd = 0 Then
		MsgBox($MB_OK, $mMB, "Unable to trigger the settings function.", 2)
		LogUpload("Unable to start the settings window.")
		Return False
	EndIf

	Local $positionY = 60
	AutoItSetOption ( "PixelCoordMode", 0 )
	Do
		Local $txt = WinGetText($hWnd)

		If StringInStr($txt, "Capture", 1) Then	; Cameras
			ControlClick($hWnd, "", "Test")
			Switch $pre
				Case "0"
					Send("+{Tab}0{ENTER}")
				Case "15"
					Send("+{Tab}01{ENTER}")
				Case "30"
					Send("+{Tab}3{ENTER}")
				Case "45"
					Send("+{Tab}4{ENTER}")
				Case "60"
					Send("+{Tab}6{ENTER}")
				Case "90"
					Send("+{Tab}9{ENTER}")
				Case "120"
					Send("+{Tab}91{ENTER}")
			EndSwitch

			If StringInStr($cam2, "able") Then
				ControlSend($hWnd, "", "[REGEXPCLASS:(.*COMBOBOX.*); INSTANCE:3]", "2")	; select Camera 2
				sleep(2500)

				If StringInStr($cam2, "enable") Then	; compatible with both enable and enabled
					ClickCheckButton($hWnd, "Enable secondary camera")
					ClickCheckButton($hWnd, "Always record both cameras")
					Sleep(500)
					ControlClick($hWnd, "", "Test")
					Sleep(2000)
				EndIf
				If StringInStr($cam2, "disable") Then	; compatible with both disable and disabled
					ClickCheckButton($hWnd, "Enable secondary camera", False)
					ClickCheckButton($hWnd, "Always record both cameras", False)
				EndIf
			EndIf

			If StringInStr($cam3, "able") Then
				ControlSend($hWnd, "", "[REGEXPCLASS:(.*COMBOBOX.*); INSTANCE:3]", "3")	; select Camera 3
				sleep(2500)

				If StringInStr($cam3, "enable") Then	; compatible with both enable and enabled
					ClickCheckButton($hWnd, "Enable third camera")
					Sleep(500)
					ControlClick($hWnd, "", "Test")
					Sleep(2000)
				EndIf
				If StringInStr($cam3, "disable") Then	; compatible with both disable and disabled
					ClickCheckButton($hWnd, "Enable third camera", False)
				EndIf
			EndIf
		EndIf

		If StringInStr($txt, "Identify", 1) Then	; Hardware Triggers
			ControlClick($hWnd, "", "Identify")
			If Not GetHandleWindowWait("CopTrax", "OK") Then
				LogUpload("Unable to trigger Identify button.")
				WinClose($hWnd)
				Return False
			EndIf

			Local $id = StringTrimLeft(WinGetText("CopTrax", "OK"), 2)
			LogUpload("Identify of current box is " & $id)
			Sleep(1000)
			WinClose("CopTrax", "OK")	; click to close the Identify popup window

			$readTxt = StringRegExp($id, "[0-9]+\.[0-9]+\.[0-9]+\.?[0-9a-zA-Z]*", $STR_REGEXPARRAYGLOBALMATCH)
			If UBound($readTxt) < 2 Then
				$boxID = ""
				$firmwareVersion = ""
				$libraryVersion = ""
				LogUpload("Fatal error. Firmware not responding correctly.")
				WinClose($hWnd)
				Return False
			Else
				$libraryVersion = $readTxt[0]
				$firmwareVersion = $readTxt[1]
			EndIf

			$readTxt =  StringRegExp($id, "([a-zA-Z]{2}[0-9]{6})", $STR_REGEXPARRAYMATCH)
			If $readTxt = "" Then
				$boxID = "WrongSN"
				LogUpload("Fatal error. Firmware not responding correctly.")
				WinClose($hWnd)
				Return False
			EndIf

			Local $readID = $readTxt[0]
			If StringCompare( $readID, $boxID ) <> 0 Then
				LogUpload("Changed the box ID in config file.")
				$boxID = $readID
				RenewConfig()
			EndIf

			$x0 = 310
			For $y0 = 150 To 430 Step 35
				$pColor = PixelGetColor( $x0, $y0, $hWnd )
				If $pColor > 0 Then
					MouseClick("", $x0, $y0)
					LogUpload("Pixel color at (" & $x0 & "," & $y0 & " ) is " & $pColor & ", so click on it.")
				EndIf
				If ($y0 > 200) And ($y0 < 330) Then
					MouseClick("", $x0+317, $y0)
					Send("f")
					Local $j = 1
					Local $m = Round(($y0-220)/35)
					For $j = 1 To $m
						Send("{Down}")
					Next
					Send("{Enter}")
				EndIf
			Next
		EndIf

		If StringInStr($txt, "Visual", 1) Then	; Speed Triggers
			Sleep(1000)
		EndIf

		If StringInStr($txt, "Baud", 1) Then	; GPS & Radar
			ControlClick($hWnd, "", "Test")
			ClickCheckButton($hWnd, "Enable Radar Detection")	; check Enable Radar Detection
			Sleep(1000)
		EndIf

		If StringInStr($txt, "Max", 1) Then	; Upload & Storage
			If $chunk Then
				$chunkTime = CorrectRange(Int($chunk), 0, 60)
				Send("{TAB}{BS 4}" & $chunkTime & "{TAB}")
			EndIf

			ClickCheckButton($hwnd,"Enable auto upload", False)
			Sleep(1000)
		EndIf

		If StringInStr($txt, "Welcome", 1) Then	; Misc
			ClickCheckButton($hwnd,"Enable Welcome App")

			If StringInStr($keyboard, "enable") Then	; compatible with both enable and enabled
				ClickCheckButton($hwnd,"Enable on-screen keyboard")
			EndIf
			If StringInStr($keyboard, "disable") Then	; compatible with both disable and disabled
				ClickCheckButton($hwnd,"Enable on-screen keyboard", False)
			EndIf
		EndIf

		$positionY += 60
		MouseClick("", 60, $positionY)
		Sleep(500)
	Until $positionY > 420
	AutoItSetOption ( "PixelCoordMode", 1 )

	ControlClick($hWnd, "", "Apply")
	If WinWaitClose($hWnd, "", 10) = 0 Then
		MsgBox($MB_OK, $mMB, "Click on the Apply button failed", 2)
		LogUpload("Unable to apply the settings by click on the Apply button.")
		WinClose($hWnd)
		Return False
	EndIf

	Return True
EndFunc

Func ClickCheckButton($hWnd, $button, $check = True)
	Local $aPos = ControlGetPos($hWnd, "", $button)
	If @error Then
		LogUpload("Unable to find the button named " & $button)
		Return
	EndIf

	Local $x0 = $aPos[0] + 8
	Local $y0 = $aPos[1] + $aPos[3]/2 + 27
	Local $pColor = PixelGetColor( $x0, $y0, $hWnd)

	If ($pColor = 0 ) <> $check Then
		ControlClick($hWnd, "", $button)
		LogUpload("Pixel color at (" & $x0 & "," & $y0 & ") is " & $pColor & ", so click on button " & $button)
	EndIf
EndFunc

Func ReadyForTest()
	AutoItSetOption ("WinTitleMatchMode", 2)

	Local $i = 5
	While WinExists($titleStatus) And ($i > 0)
		Sleep(1000)
		$i -= 1
	WEnd
	If $i <= 0 Then
		LogUpload("The accessories are not ready.")
		TakeScreenCapture("Accessories not ready", WinActive($titleStatus))
		Return False
	EndIf

	If WinExists($titleCopTraxMain, "Details") Then
		ControlClick($titleCopTraxMain, "Details", "Details")
		Local $txt = WinGetText($titleCopTraxMain, "Details")
		LogUpload("Unhandled exception has occured in CopTrax II.")
		LogUpload(" The error messages are : " & $txt)
		ControlClick($titleCopTraxMain, "Details", "Quit")
		Return False
	EndIf

	If WinExists($titleLogin) Then
		WinClose($titleLogin)
		Sleep(100)
	EndIf

	If WinExists($titleInfo) Then
		WinClose($titleInfo)
		Sleep(100)
	EndIf

	If WinExists($titleSettings) Then
		WinClose($titleSettings)
		Sleep(100)
	EndIf

	If WinExists("CopTrax","OK") Then
		Local $txt = WinGetText("CopTrax", "OK")
		LogUpload("Encounter an error Window. The messages displayed on the window is " & $txt)
		WinClose("CopTrax","OK")
		Sleep(100)
		If StringInStr($txt, "Full") Then
			LogUpload("Disk Full! No more automation test.")
			$testEnd = True
			$restart = False
			Return False
		EndIf
	EndIf

	$mCopTrax = GetHandleWindowWait($titleCopTraxMain)
	If $mCopTrax Then
		Return True
	EndIf

	LogUpload("Unable to find CopTrax App. Doing intensive investigation on CopTrax with keyword " & $titleCopTraxMain)
	Local $aList = WinList()
	For $i = 1 To $aList[0][0]
		If $aList[$i][0] <> "" And BitAND(WinGetState($aList[$i][1]), 2) Then
			LogUpload("Title: " & $aList[$i][0] & ", Handle: " & $aList[$i][1])
			If StringInStr($aList[$i][0], $titleCopTraxMain) Then
				$mCopTrax = $aList[$i][0]
				WinActivate($mCopTrax)
				Return True
			EndIf
		EndIf
	Next
	LogUpload("The CopTrax is not ready. Got handle of main CopTrax as " & $mCopTrax)
	Return False
EndFunc

Func CheckEventLog()
	Local $aEvent
	Local $rst = True
	Do
		$aEvent = _EventLog__Read($hEventLogSystem, True, True)	;read the event log forwards from last read

		If $aEvent[7] = 1 Then
			LogUpload("Get system error event at " &  $aEvent[4] & " " & $aEvent[5] & ", ID=" & $aEvent[6] & ", " & $aEvent[13])
			If $aEvent[6] = 10110 Then $rst = False
		EndIf
	Until Not $aEvent[0]

	Do
		$aEvent = _EventLog__Read($hEventLogApp, True, True)	;read the event log forwards from last read

		If $aEvent[7] = 1 Then
			LogUpload("Get application error event at " &  $aEvent[4] & " " & $aEvent[5] & ", ID=" & $aEvent[6] & ", " & $aEvent[13])
		EndIf
	Until Not $aEvent[0]

	Do
		$aEvent = _EventLog__Read($hEventLogCopTrax, True, True)	;read the event log forwards from last read

		If $aEvent[7] = 1 Then
			LogUpload("Get CopTrax App error event at " &  $aEvent[4] & " " & $aEvent[5] & ", ID=" & $aEvent[6] & ", " & $aEvent[13])
		EndIf
	Until Not $aEvent[0]

	Return $rst
EndFunc

Func TestCameraSwitchFunction()
	If Not ReadyForTest() Then  Return False

	Local $file1
	Local $file2
	Local $file3
	Local $blue1
	Local $blue2
	Local $blue3
	Local $rst
	Local $picSize = 100000
	Local $blue = 0x090071

	LogUpload("Begin Camera switch function testing.")
	$file1 = TakeScreenCapture("Main Cam1", $mCopTrax)
	$blue1 = PixelGetColor(550, 320, $mCopTrax)
	$rst = ($file1 < $picSize) And ($blue1 <> $blue)

	MouseClick("",960,170)	; click to rear camera2
	Sleep(2000)
	$file2 = TakeScreenCapture("Rear Cam2", $mCopTrax)
	$blue2 = PixelGetColor(550, 320, $mCopTrax)
	$rst = $rst And ($file2 < $picSize) And ($blue2 <> $blue)

	MouseClick("", 200,170)	; click to switch rear camera
	Sleep(2000)
	$file3 = TakeScreenCapture("Rear Cam3", $mCopTrax)
	$blue3 = PixelGetColor(550, 320, $mCopTrax)
	$rst = $rst And ($file3 < $picSize) And ($blue3 <> $blue)

	MouseClick("", 960,170)	; click back to main camera
	Sleep(1000)

	If $rst Then
		LogUpload("Blank screen encountered.")
		Return False
	EndIf

	Return True
EndFunc

Func GetNewFilename()
	Local $char1 = Chr(65+@HOUR)
	Local $char2 = 65+@MIN
	If $char2 > 90 Then
		$char2 = 97 + @MIN - 26
	EndIf
	If $char2 > 122 Then
		$char2 = 48 + @MIN - 26 - 26
	EndIf
	$char2 = Chr($char2)

	Local $Char3 = 65+@SEC
	If $Char3 > 90 Then
		$Char3 = 97 + @SEC - 26
	EndIf
	If $Char3 > 122 Then
		$Char3 = 48 + @SEC - 26 - 26
	EndIf
	$Char3 = Chr($Char3)
	Return $boxID & $Char1 & $Char2 & $Char3
EndFunc

Func TakeScreenCapture($comment, $hWnd)
	Local $filename = GetNewFilename() & ".jpg"
	Local $screenFile = $workDir & "tmp\" & $filename
	If _ScreenCapture_CaptureWnd($screenFile, $hWnd) Then
		LogUpload("Captured " & $comment & " screen file " & $filename & ". It is now on the way sending to server.")
		PushFile($screenFile)
		Return FileGetSize($screenFile)
	Else
		LogUpload("Unable to capture " & $comment & " screen file " & $screenFile & " for window " & $hWnd)
		Return 0
	EndIf
EndFunc

Func TestPhotoFunction()
	If Not ReadyForTest() Then Return False

	LogUpload("Begin Photo function testing.")
	MouseClick("", 960, 350);

	Local $hWnd = GetHandleWindowWait($titleEndRecord, "OK", 5)
	If $hWnd = 0 Then
		$hWnd = GetHandleWindowWait($titlePhoto, "OK", 5)
		If $hWnd = 0 Then
			MsgBox($MB_OK, $mMB, "Click to trigger the Photo function failed.",2)
			LogUpload("Unable to test the Photo function by click on the photo button.")
			Return False
		EndIf
	EndIf

	Sleep(2000)
	ControlClick($hWnd,"","OK")
	Sleep(200)

	If WinWaitClose($hWnd, "", 10) = 0 Then
		MsgBox($MB_OK, $mMB, "Click to close the Photo failed.",2)
		LogUpload("Unable to complete photo taking test by click on the OK button.")
		WinClose($hWnd)
		Return False
	EndIf

	Local $photoPath = GetVideoFilePath() & "\photo"
	If Not FileExists($photoPath) Then
		$photoPath = @LocalAppDataDir & "\coptrax\" & $userName & "\photo"
	EndIf
	Local $photoFile = GetLatestFile($photoPath, "*.jpg")
	Local $filename = GetNewFilename() & ".jpg"
	If $photoFile Then
		LogUpload("Got last photo " & $photoFile & ". It is on the way sending to server as " & $filename & ".")
		$filename = $workDir & "tmp\" & $filename
		FileCopy($photoFile, $filename, 1+8)
		PushFile($filename)
		Return True
	Else

		Return False
	EndIf
EndFunc

Func TestRadarFunction()
	If Not ReadyForTest() Then Return False

	LogUpload("Begin testing RADAR function.")

	Local $testResult = False
	Local $hRadar
	If WinExists($titleRadar) Then
		$hRadar = GetHandleWindowWait($titleRadar)
		TakeScreenCapture("RADAR On", $hRadar)
		$testResult = True
	EndIf

	MouseClick("", 50, 570)
	Sleep(5000)

	If WinExists($titleRadar) Then
		$hRadar = GetHandleWindowWait($titleRadar)
		TakeScreenCapture("RADAR On", $hRadar)
		$testResult = True
	EndIf

	Return $testResult
EndFunc

Func TestReviewFunction()
	If Not ReadyForTest() Then Return False
	If IsRecording() Then
		LogUpload("A recording is in progress.")
		Return False
	EndIf

	LogUpload("Begin Review function testing.")
	MouseClick("", 960, 260);
	Local $hWnd = GetHandleWindowWait($titleReview, "", 10)
	If $hWnd = 0 Then
		MsgBox($MB_OK, $mMB, "Click to trigger the Review function failed.",2)
		LogUpload("Unable to test the review function by click on the review button.")
		Return False
	EndIf
	TakeScreenCapture("Playback from CT2", $hWnd)

	Sleep(5000)
	WinClose($hWnd)
	Sleep(200)

	If WinWaitClose($hWnd, "", 10) = 0 Then
		MsgBox($MB_OK, $mMB, "Click to close the playback window failed.",2)
		LogUpload("Unable to complete the review function test.")
		Return False
	EndIf
	Return True
EndFunc

Func LogUpload($s)
	If $Socket < 0 Then
		MsgBox($MB_OK, $mMB, $s, 2)
		If $logFile Then _FileWriteLog($logFile, $s)
		Return
	EndIf

	If Not TCPSend($Socket, $s & " ") Then
		TCPCloseSocket($Socket)
		$Socket = -1
		If $logFile Then
			_FileWriteLog($logFile, "Cannot Send the message " & $s & " to server. Connection lost.")
		EndIf
		Return
	EndIf

	If StringInStr($s, "FAILED", 1) = 1 Then
		TakeScreenCapture("failure", $mCopTrax)
	EndIf

	If StringInStr($s, "error") Then
		TCPSend($Socket, @CRLF)
	Else
		Sleep(1000)
	EndIf
EndFunc

Func IsRecording()
	If $mCopTrax Then
		Return PixelGetColor(940,100, $mCopTrax) <> 0x038c4a
	Else
		Return False
	EndIf
EndFunc

Func IsDisplayCorrect()
	If $mCopTrax = 0 Then Return False
	Local $color1 = PixelGetColor(925, 120, $mCopTrax)
	Local $color2 = PixelGetColor(1000, 508, $mCopTrax)
	Local $color3 = PixelGetColor(240, 550, $mCopTrax)
	If ($color1 = $color2) And ($color1 = 0xF0F0F0) And ($color3 = 0) Then
		Return True
	Else
		LogUpload("Pixel at (934,122) is of color " & $color1 & ". Pixel at (1016,510) is of color " & $color2 & ". Pixel at (240,550) is of color " & $color3 & ".")
		Return False
	EndIf
EndFunc

Func CheckRecordedFiles($arg)
	LogUpload("Begin to review the records to check the chunk time.")

	Local $fileTypes = ["*.*","*.wmv", "*.jpg", "*.gps", "*.txt", "*.rdr", "*.vm", "*.trax", "*.rp"]
	Local $latestFiles[9+9]
	Local $chk = True

	Local $path0 = @MyDocumentsDir & "\CopTraxTemp"
	Local $path1 = GetVideoFilePath()
	Local $path2 = $path1 & "\cam2"

	Local $total = Int(GetParameter($arg, "total"))
	Local $newAdd = GetParameter($arg, "newadd")
	Local $detailed = GetParameter($arg, "detailed")

	Local $cam1 = GetVideoFileNum($path1, "*.wmv") + GetVideoFileNum($path0, @MDAY & "*.mp4")
	Local $cam2 = GetVideoFileNum($path2, "*.wmv") + GetVideoFileNum($path2, "*.avi")
	Local $newAdd1 = $cam1 - $videoFilesCam1
	Local $newAdd2 = $cam2 - $videoFilesCam2
	$videoFilesCam1 = $cam1
	$videoFilesCam2 = $cam2

	LogUpload("Today the main camera has recorded total " & $cam1 & " video files. The rear camera has recorded total " & $cam2 & " video files.")
	LogUpload("In last period, the main camera has recorded " & $newAdd1 & " new video files. The rear camera has recorded " & $newAdd2 & " new video files.")

	If $total > 0 Then
		If ($total <> $cam1) Or ($total <> $cam2) Then
			Return False
		Else
			return True
		EndIf
	EndIf

	If $newAdd > 0 Then
		If ($newAdd <> $newAdd1) Or ($newAdd <> $newAdd2) Then
			Return False
		Else
			return True
		EndIf
	EndIf

	Local $i
	For	$i = 0 To 8
		$latestFiles[$i] = GetLatestFile($path1, $fileTypes[$i])
		$latestFiles[$i+9] = GetLatestFile($path2, $fileTypes[$i])
	Next

	Local $file0 = GetLatestFile($path1, "*.avi")
	Local $time0 = GetFiletimeFromFilename($file0)
	Local $time1 = GetFiletimeFromFilename($latestFiles[1])
	If $time0 > $time1 Then $latestFiles[1] = $file0
	$file0 = GetLatestFile($path2, "*.avi")
	$time0 = GetFiletimeFromFilename($file0)
	$time1 = GetFiletimeFromFilename($latestFiles[10])
	If $time0 > $time1 Then $latestFiles[10] = $file0

	$time0 = GetFiletimeFromFilename($latestFiles[0])	; $time0 is of format yyyymmddhhmmss
	$time1 = GetFiletimeFromFilename($latestFiles[9])
	If CalculateTimeDiff($time0,$time1) > 0 Then
		$time0 = $time1
	EndIf

	$file0 = GetLatestFile("C:\CopTrax-Backup", "*.avi")
	$time1 = GetFiletimeFromFilename($file0)

	LogUpload($path1 & " " & $time0)
	Local $fileName, $fileSize, $createTime

	For $i = 1 To 17
		If $i = 9 Then
			LogUpload($path2)
			ContinueLoop
		EndIf

		$fileName = $latestFiles[$i]
		$fileSize = FileGetSize($fileName)
		$createTime = GetFiletimeFromFilename($fileName)

		Local $n = $i < 9 ? $i : $i-9
		If $fileSize > 10 Then
			LogUpload("Latest " & $fileTypes[$n] & " was created at " & $createTime & " with size of " & $fileSize)
		EndIf

		If ($i = 1 Or $i = 2 Or $i = 3 Or $i = 10 Or $i = 11 Or $i=12) And (CalculateTimeDiff($createTime, $time0) > 3) Then
			LogUpload("Find key file " & $fileTypes[$n] & " missed in records.")
			$chk = False	; return False when .gps or .wmv or .jpg files were missing,
			If Abs(CalculateTimeDiff($time1, $time0)) < 3 Then
				LogUpload("Find " & $file0 & " in backup folder.")
			EndIf
		EndIf
	Next

	Local $durations = GetDurationTime($latestFiles[1])
	Local $chunk1 = Number(GetParameter($durations, "video"))
	Local $chunk2 = Number(GetParameter($durations, "audio"))
	LogUpload("For " & $latestFiles[1] & ", the video duration is " &  $chunk1 & " s, the audio duration is " & $chunk2 & "s.")
	If $chunk1 > $chunkTime*60 + 10 Then
		$chk = False
		LogUpload("The recorded video duration by Cam1 is longer than the preset chunk time.")
	EndIf

	If $chunk1 - $chunk2 > 10 Then
		$chk = False
		LogUpload("The audio duration is too short when comparing to the video duration.")
	EndIf
	$durations = GetDurationTime($latestFiles[10])
	$chunk1 = GetParameter($durations, "video")
	$chunk2 = GetParameter($durations, "audio")
	LogUpload("For " & $latestFiles[10] & ", the video duration is " &  $chunk1 & " s, the audio duration is " & $chunk2 & "s.")
	If $chunk1 > $chunkTime*60 + 10 Then
		$chk = False
		LogUpload("The recorded video duration by Cam1 is longer than the preset chunk time.")
	EndIf

	Return true
EndFunc

Func GetVideoFileNum($path, $type)
	; List the files only in the directory using the default parameters.
    Local $aFileList = _FileListToArray($path, $type, 1, True)
    If @error = 0 Then
		Return $aFileList[0]
	Else
		Return 0
	EndIf
EndFunc

Func GetVideoFilePath()
	Local $month = ["","Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]
	Return @LocalAppDataDir & "\coptrax\" & $userName & "\" & @MDAY & "-" & $month[@MON] & "-" & @YEAR
EndFunc

Func GetLatestFile($path,$type)
	; List the files only in the directory using the default parameters.
	Local $aFileList = _FileListToArray($path, $type, 1, True)	; return the full path

	If @error > 0 Then Return ""

	Local $i
	Local $latestFile
	Local $date0 = "20170101000000"
	Local $fileDate
	For $i = 1 to $aFileList[0]
		Local $fileDate = GetFiletimeFromFilename($aFileList[$i])	; get last create time in String format
		if CalculateTimeDiff($fileDate, $date0) < 0 Then
			$date0 = $fileDate
			$latestFile = $aFileList[$i]
		EndIf
	Next
	Return $latestFile
EndFunc

Func GetFiletimeFromFilename($file)
   Local $fileData = StringSplit($file, "\")
   Local $netFilename = $fileData[$fileData[0]]	; get net file name without path and extension
   If StringLen($netFilename) < 10 Then Return "00000000000000"
   ; convert ddmmyyyyhhmmss to yyyymmddhhmmss
   Return StringMid($netFilename, 5 , 4 ) & StringMid($netFilename, 3 , 2) & StringMid($netFilename, 1 , 2) & StringMid($netFilename, 9 , 6)
EndFunc   ;==>Example

Func CalculateChunkTime($file)
	Local $createTime = GetFiletimeFromFilename($file)	; get create time from filename
	Local $modifiedTime = FileGetTime($file, 0, 1)	; get modified time from meta data

	Return CalculateTimeDiff($createTime,$modifiedTime)
EndFunc

Func GetDurationTime($file)
	Local $file0 = "audio.aac"
	FileDelete($workDir & $file0)

	Local $batchFile = FileOpen($workDir & "CheckVideoAudio.bat", 2)
	FileWriteLine($batchFile, "Echo Check the latest record for video and audio length.")
	FileWriteLine($batchFile, "C:")
	FileWriteLine($batchFile, "CD " & $workDir)
	FileWriteLine($batchFile, "ffmpeg -i " & $file & " -vn -acodec copy " & $file0)
	FileWriteLine($batchFile, "ffprobe -v error -show_entries format=duration " & $file & " > video.txt")
	FileWriteLine($batchFile, "ffprobe -v error -show_entries format=duration " & $file0 & " > audio.txt")
	FileWriteLine($batchFile, "exit")
	FileClose($batchFile)
	RunWait($workDir & "CheckVideoAudio.bat")

	Local $rstFile = FileOpen($workDir & "video.txt")
	Local $txt = FileRead($rstFile)
	Local $video = StringRegExp($txt, "(?:duration=)([0-9\.]*)", 1)
	Local $videoDuration = "NONE"
	If IsArray($video) Then
		$videoDuration = $video[0]
	EndIf
	FileClose($rstFile)

	$rstFile = FileOpen($workDir & "audio.txt")
	Local $audio = StringRegExp(FileRead($rstFile), "(?:duration=)([0-9\.]*)", 1)
	Local $audioDuration = "NONE"
	If IsArray($audio) Then
		$audioDuration = $audio[0]
	EndIf
	FileClose($rstFile)

	Return "video=" & $videoDuration & " audio=" & $audioDuration
EndFunc

Func CalculateTimeDiff($time1,$time2)
   If (StringLen($time1) <> 14) Or (StringLen($time2) <> 14) Then Return 100000
   Local $t0 = (Number(StringMid($time2, 1, 8)) - Number(StringMid($time1, 1, 8)))*24*3600
   ; get the time difference in format yyyymmddhhmmss
   Local $t1 = Number(StringMid($time1, 9, 2)) * 3600 + Number(StringMid($time1, 11, 2)) * 60 + Number(StringMid($time1, 13, 2))
   Local $t2 = Number(StringMid($time2, 9, 2)) * 3600 + Number(StringMid($time2, 11, 2)) * 60 + Number(StringMid($time2, 13, 2))
   Return $t2 - $t1 + $t0
EndFunc

Func CloseConnection($err)
	TCPCloseSocket($Socket)
	$Socket = -1
	LogUpload("Connection lost with error " & $err)
EndFunc

Func ListenToNewCommand()
	Local $raw
	Local $len
	Local $err

	If $fileToBeUpdate Then
		$raw = TCPRecv($Socket, 1000000, 1)	; In case there is file to be updated, receives in binary mode with long length
		$err = @error
		If $err <> 0 Then	; In case there is error, the connection has lost, restart the automation test
			FileClose($fileToBeUpdate)
			$fileToBeUpdate = 0
			CloseConnection($err)
			Return False
		EndIf

		$len = BinaryLen($raw)
		If $len = 0 Then Return False

		FileWrite($fileToBeUpdate, $raw)
		$bytesCounter -= $len
		LogUpload("Received " & $len & " bytes, write them to files, " & $bytesCounter & " bytes remains.")
		If $bytesCounter < 5 Then
			FileClose($fileToBeUpdate)
			$fileToBeUpdate = 0
			LogUpload("Continue End of file update in client.")
		EndIf
		Return True
	EndIf

	$raw = TCPRecv($Socket, 1000)	; In listen to command mode, receives in text mode with shorter length
	$err = @error
	If $err <> 0 Then	; In case there is error, the connection has lost, restart the automation test
		CloseConnection($err)
		Return False
	EndIf
	If $raw = "" Then Return False

	Local $Recv = StringSplit($raw, " ")
	Switch StringLower($Recv[1])
		Case "runapp" ; get a stop command, going to stop testing and quit
			MsgBox($MB_OK, $mMB, "Re-starting the CopTrax",2)
			RunCopTrax()
			LogUpload("PASSED to start the CopTrax II app.")

		Case "stopapp" ; get a stop command, going to stop testing and quit
			MsgBox($MB_OK, $mMB, "Try to stop CopTrax App.",2)
			If QuitCopTrax() Then
				LogUpload("PASSED to stop CopTrax II app.")
			Else
				LogUpload("FAILED to stop CopTrax II app.")
			EndIf

		Case "startrecord", "record" ; Get a record command. going to test the record function
			If StartRecord(True) Then
				LogUpload("PASSED the test on start record function.")
			Else
				LogUpload("FAILED to start a record.")
			EndIf

		Case "startstop", "lightswitch" ; Get a startstop trigger command
			LogUpload("Got the lightswitch command. Takes seconds to determine what to do next.")
			For $i = 1 To 10
				If WinExists($titleEndRecord, "") Then	ExitLoop; check if an endrecord window pops
				sleep(1000)
			Next
			If WinExists($titleEndRecord, "") Then	; check if an endrecord window pops
				If EndRecording(False) Then
					LogUpload("PASSED the test to end the record by trigger Light switch button.")
				Else
					LogUpload("FAILED to end the record by trigger Light switch button.")
				EndIf
			Else
				MsgBox($MB_OK, $mMB, "Testing the Light switch button trigger a record function",2)
				If StartRecord(False) Then
					LogUpload("PASSED the test to start a record by trigger Light switch button.")
				Else
					LogUpload("FAILED to start a record by trigger Light switch button.")
				EndIf
			EndIf

		Case "endrecord" ; Get a stop record command, going to end the record function
			MsgBox($MB_OK, $mMB, "Testing the end record function",2)
			If EndRecording(True) Then
				LogUpload("PASSED the test on end record function.")
			Else
				LogUpload("FAILED to end record.")
			EndIf

		Case "settings" ; Get a stop setting command, going to test the settings function
			MsgBox($MB_OK, $mMB, "Testing the settings function",2)
			If ($Recv[0] >= 2) And TestSettingsFunction($Recv[2]) Then
				LogUpload("PASSED the test on new settings.")
			Else
				LogUpload("FAILED the test on new settings. " & $Recv[0] & " " & $raw)
			EndIf

		Case "login", "createprofile" ; Get a stop setting command, going to test the settings function
			MsgBox($MB_OK, $mMB, "Testing the user switch function",2)
			If ($Recv[0] >= 2) And TestUserSwitchFunction($Recv[2]) Then
				LogUpload("PASSED the test on user switch function.")
			Else
				LogUpload("FAILED to switch the user.")
			EndIf

		Case "camera" ; Get a stop camera command, going to test the camera switch function
			MsgBox($MB_OK, $mMB, "Testing the camera switch function",2)
			If TestCameraSwitchFunction() Then
				LogUpload("PASSED the test on camera switch function.")
			Else
				LogUpload("FAILED the test on camera switch.")
			EndIf

		Case "photo" ; Get a stop photo command, going to test the photo function
			MsgBox($MB_OK, $mMB, "Testing the photo function",2)
			If TestPhotoFunction() Then
				LogUpload("PASSED the test to take a photo.")
			Else
				LogUpload("FAILED to take a photo.")
			EndIf

		Case "review" ; Get a stop review command, going to test the review function
			MsgBox($MB_OK, $mMB, "Testing the review function",2)
			If TestReviewFunction() Then
				LogUpload("PASSED on the test on review function.")
			Else
				LogUpload("FAILED to review.")
			EndIf

		Case "radar" ; Get a stop review command, going to test the review function
			MsgBox($MB_OK, $mMB, "Testing the radar function",2)
			If TestRadarFunction() Then
				LogUpload("PASSED on the test of show radar function.")
			Else
				LogUpload("FAILED to trigger radar.")
			EndIf

		Case "trigger" ; Get a trigger command, going to test the trigger record function
			MsgBox($MB_OK, $mMB, "Testing the trigger function",2)
			If StartRecord(False) Then
				LogUpload("PASSED the test on trigger a record function.")
			Else
				LogUpload("FAILED to trigger a record.")
			EndIf

		Case "upload"	; upload the specified files to server, all, idle, now, wait have special meaning
			MsgBox($MB_OK, $mMB, "Testing file upload function",2)
			If $Recv[0] >= 2 Then
				LogUpload("PASSED upload setting.")
				UploadFile($Recv[2])
			Else
				LogUpload("FAILED missing parameter to set the file upload.")
			EndIf

		Case "update"	; update the specified files on client with the one on server
			MsgBox($MB_OK, $mMB, "Testing file update function",2)
			If ($Recv[0] >=3) And UpdateFile($Recv[2], Int($Recv[3])) Then
				LogUpload("Continue Got the update command. Ready for to receive.")
			Else
				LogUpload("FAILED to update " & $Recv[2])
			EndIf

		Case "synctime"	; sync the client's time and date with the server
			If ($Recv[0] >= 2) And SyncDateTime($Recv[2]) Then
				LogUpload("PASSED date and time syncing. The client is now " & @YEAR & "/" & @MON & "/" & @MDAY & " " & @HOUR & ":" & @MIN & ":" & @SEC)
			Else
				LogUpload("FAILED to sync date and time.")
			EndIf
			MsgBox($MB_OK, $mMB, "Synchronizing client time to server",2)

		Case "synctmz"	; sync the client's time zone with the server
			MsgBox($MB_OK, $mMB, "Synchronizing client timezone to server's",2)
			If ($Recv[0] >= 2) And SyncTimeZone(StringMid($raw, 9)) Then
				LogUpload("PASSED timezone synchronization.")
			Else
				LogUpload("FAILED to sync timezone to server's.")
			EndIf

		Case "checkrecord"	; checkthe recorded files
			MsgBox($MB_OK, $mMB, "Checking the record files.",2)
			If ($Recv[0] >= 2) And CheckRecordedFiles($Recv[2]) Then
				LogUpload("PASSED the check on recorded files.")
			Else
				LogUpload("Continue Warning on the check of recorded files.")
			EndIf

		Case "eof", "cancel"	; tell the client the end of file sending in update
			LogUpload("Continue End of file stransfer. " & $sentPattern)
			If StringInStr($raw, "eof") Then
				PopFile(True)	; pop the previous file out of the stack when receives eof
				If $uploadMode = "all" Then UploadFile("all")
			EndIf
			MsgBox($MB_OK, $mMB, "Got " & $raw & " command from server.",2)

		Case "configure"	; configure the client
			MsgBox($MB_OK, $mMB, "Configuring the client.",2)
			If ($Recv[0] >= 2) And Configure($Recv[2]) Then
				LogUpload("PASSED configuration of the client. The client is now of version " & $appVersion)
			Else
				LogUpload("FAILED configuration of the client. The client is now of version " & $appVersion)
			EndIf

		Case "send"	; let the client to send the file
			$sentPattern = ""
			$len = 1
			While BinaryLen($fileContent) And $len;LarryDaLooza's idea to send in chunks to reduce stress on the application
				$len = TCPSend($Socket,BinaryMid($fileContent, 1, $maxSendLength))
				$err = @error
				$fileContent = BinaryMid($fileContent,$len+1,BinaryLen($fileContent)-$len)
				$sentPattern &= $len & " "
			WEnd
			If $err <> 0 Then
				CloseConnection($err)
			EndIf
			MsgBox($MB_OK, $mMB, "Got " & $raw & " command from server.",2)

		Case "quit", "endtest", "quittest"	; let the client to quit the current automation test
			Run(@ComSpec & ' /c schtasks /Create /SC ONLOGON /TN "ACI\CopTrax Welcome" /TR "C:\CopTrax Support\Tools\CopTraxWelcome\CopTraxWelcome.exe" /F /RL HIGHEST') ; Enable the welcome screen next time
			LogUpload("quit Got " & $raw & " command. The test client will stop. The welcome screen is turned ON.")
			$testEnd = True	;	Stop testing marker
			$restart = False

		Case "restart", "restarttest"	; let the client to restart the automation test
			LogUpload("quit The test client will restart.")
			$testEnd = True	;	Stop testing marker
			$restart = True

		Case "status", "heartbeat"	; heartbeat and let the client to report its status
			ReportCPUMemory()
			If $uploadMode = "idle" Then
				UploadFile("now")
				$uploadMode = "idle"
			EndIf
			MsgBox($MB_OK, $mMB, "Got " & $raw & " command from server.",2)

		Case "info"	; null command
			LogUpload("Continue It is a null command at this moment.")

		Case "about"	; let the client to report the about infomation
			MsgBox($MB_OK, $mMB, "Checking CopTrax about infomation.",2)

			If testAbout() Then
				LogUpload("PASSED CopTrax About Info check. The CopTrax is of version " & $appVersion & " " & $releaseRead & ".")
			Else
				LogUpload("FAILED CopTrax version check. The current CopTrax is of version " & $appVersion & " " & $releaseRead & ".")
			EndIf

		Case "checkfirmware"	; check the firmware
			MsgBox($MB_OK, $mMB, "Checking client firmware.",2)
			If $firmwareVersion = "" Then
				LogUpload("FAILED firmware version check. Run settings command before checking the firmware version.")
			ElseIf ($Recv[0] >= 2) And ($firmwareVersion = $Recv[2]) Then
				LogUpload("PASSED firmware version check. The firmware version is " & $firmwareVersion)
			Else
				LogUpload("FAILED firmware version check. The current firmware version is " & $firmwareVersion & ", not " & $Recv[2])
			EndIf

		Case "checkapp"	; check the app version and the release
			MsgBox($MB_OK, $mMB, "Checking CopTrax version and release.",2)

			If $releaseSet = "Unset" Then $releaseSet = $releaseRead	; backward compatible

			If ($Recv[0] >= 2) And ($appVersion = $Recv[2]) And ($releaseRead = $releaseSet) Then
				LogUpload("PASSED CopTrax version check. The CopTrax is of version " & $appVersion & " " & $releaseRead & ".")
			Else
				LogUpload("FAILED CopTrax version check. The current CopTrax is of version " & $appVersion & " " & $releaseRead & ", not " & $Recv[2])
			EndIf

		Case "checklibrary"	; check the library version
			MsgBox($MB_OK, $mMB, "Checking CopTrax library version.",2)

			If ($Recv[0] >= 2) And ($libraryVersion = $Recv[2]) Then
				LogUpload("PASSED library version check. The library version is " & $libraryVersion)
			Else
				LogUpload("FAILED library version check. The current library version is " & $libraryVersion & ", not " & $Recv[2])
			EndIf

		Case "cleanup"	; let the client cleanup
			Local $filename = "C:\CopTrax Support\Tools\Automation.bat"
			Local $file = FileOpen($filename, $FO_OVERWRITE );
			FileWriteLine($file, "Echo Welcome to use CopTrax II")
			FileClose($file)

			If Not QuitCopTrax() Then ProcessClose($pCopTrax)	; try to stop the CopTrax gracefully
			Run(@ComSpec & ' /c schtasks /Create /SC ONLOGON /TN "ACI\CopTrax Welcome" /TR "C:\CopTrax Support\Tools\CopTraxWelcome\CopTraxWelcome.exe" /F /RL HIGHEST') ; Enable the welcome screen next time
			Run(@ComSpec & " /c schtasks /Delete /TN Automation /F")	; Disable the automation
			LogUpload("quit The box is going to be cleanup and shutdown. Welcome Screen is turned ON. And the automation is turned OFF.")
			Run("C:\Coptrax Support\Tools\Cleanup.bat", "C:\Coptrax Support\Tools\", @SW_HIDE)
			$testEnd = True
			$restart = False
			Exit

		Case "reboot"	; let the client to reboot
			Run(@comSpec & ' /c schtasks /Delete /TN "ACI\CopTrax Welcome" /F')	; Disable the welcome screen
			Run(@ComSpec & " /c schtasks /Create /SC ONLOGON /TN Automation /TR C:\CopTraxAutomation\automation.bat /F")	; Enable the Automation next time
			LogUpload("quit Going to reboot the box. Welcome Screen is turned OFF. And the automation is turned ON.")
			TCPShutdown()
			Shutdown(2+4)	; force the window to reboot
			Exit
	EndSwitch

	Return True
EndFunc

Func RunCopTrax()
	LogUpload("Restarting CopTrax App.")
	Run($CopTraxAppDir & $pCopTrax, $CopTraxAppDir)
	$mCopTrax = GetHandleWindowWait($titleCopTraxMain)
	If $mCopTrax Then
		$userName = GetUserName()
		Return True
	Else
		Return False
	EndIf
EndFunc

Func Configure($arg)
	Local $ct
	Local $release
	Local $bwc
	Local $rst = True
	Local $file

	$ct = GetParameter($arg, "ct")	; configure the CopTrax App
	$release = GetParameter($arg, "release")	; configure the Evidence Viewer
	If $ct Or $release Then
		If Not QuitCopTrax() Then Return $rst

		If $ct Then
			LogUpload("Configuring CopTrax App to " & $ct & ".")
			$rst = CopyOver("CT-" & $ct, $CopTraxAppDir)
		EndIf

		If $release Then
			LogUpload("Configuring Coptrax App to release " & $release & ".")
			$releaseSet = $release
			$file = FileOpen($CopTraxAppDir & "CopTrax.config", 2) ; Open the coptrax.config file in overwrite mode
			If $file <> -1 Then
				FileWriteLine($file, "release=" & $release)
				FileClose($file)
			Else
				$rst = False
			EndIf
		EndIf

		If Not RunCopTrax() Then
			$rst = False
		EndIf
	EndIf

	$bwc = GetParameter($arg, "bwc")	; configure the Evidence Viewer
	If $bwc Then
		LogUpload("Configuring Body Wore Camera to turn " & $bwc & ".")
		If StringInStr($bwc, "on") Then
			Run(@ComSpec & ' /c schtasks /Create /SC ONLOGON /TN "BWC Manager Startup" /TR "C:\Program Files\Applied Concepts Inc\CopTrax Body Camera Manager\MobileCam.exe" /F')	; Enable the BWC next time
			LogUpload("Body Wore Camera Manager is configured to startup.")
		Else
			Run(@ComSpec & ' /c schtasks /Delete /TN "BWC Manager Startup"')
			LogUpload("Body Wore Camera Manager is configured not to startup.")
		EndIf
	EndIf

	Return $rst
EndFunc

Func CopyOver($config, $destDir)
	Local $sourceDir = "C:\CopTrax Support\Configures\" & $config
	Local $list = _FileListToArray( $sourceDir, "*", 1, True )	; list all the files in the folder with full path
	If Not IsArray($list) Or $list[0] = 0 Then
		LogUpload("Warning! Cannot find any file in " & $sourceDir & ".")
		Return False
	EndIf

	Local $i
	Local $rst = 0
	Local $end = 3
	For $i = 1 To $list[0]
		Do
			If FileCopy($list[$i], $destDir, 1) Then; copies the directory $sourceDir and all sub-directories and files to $destDir in overwrite mode
				$rst += 1
				$end = 0
			Else
				LogUpload($list[$i] & " was not copied to " & $destDir & ". Try again.")
				$end -= 1
			EndIf
		Until $end <= 0
	Next

	If $rst = $list[0] Then
		LogUpload("Configures are copied to " & $destDir & ".")
		Return True
	Else
		LogUpload("Warning! Only " & $rst & " out of " & $list[0] & " files were copied from " & $sourceDir & " to " & $destDir)
		Return False
	EndIf
EndFunc

Func RunMsi($msi)
	Local $dir = "C:\CopTrax Support\"
	If Not FileExists($dir & $msi) Then
		Return False
	EndIf

	Local $pMsi = Run($dir & $msi, $dir)
	Local $hMsi = GetHandleWindowWait("CopTrax", "&Next")
	If Not $hMsi Then
		LogUpload("Unable to load " & $msi & ".")
		ProcessClose($pMsi)
		Return False
	EndIf

	AutoItSetOption ( "SendKeyDelay", 1000 )
	Send("nannnc")	; &Next, &Agree, &Next, &Next, &Next, &Close
	AutoItSetOption ( "SendKeyDelay", 100 )
	Sleep(2000)

	If ProcessExists($pMsi) Then
		LogUpload("Unable to install " & $msi & ". The error messages are " & WinGetText($hMsi))
		ProcessClose($pMsi)
		Return False
	Else
		LogUpload("Complete the installation of " & $msi & ". The messages are " & WinGetText($hMsi))
		Return True
	EndIf
EndFunc

Func EncodeToSystemTime($datetime)
	Local $yyyy = Number(StringMid($datetime,1,4))
	Local $mon = Number(StringMid($datetime,5,2))
	Local $dd = Number(StringMid($datetime,7,2))
	Local $hh = Number(StringMid($datetime,9,2))
	Local $min = Number(StringMid($datetime,11,2))
	Local $ss = Number(StringMid($datetime,13,2))
	Return _Date_Time_EncodeSystemTime( $mon, $dd, $yyyy, $hh, $min, $ss )
EndFunc

Func SyncDateTime($datetime)
	Local $tSysTime  = EncodeToSystemTime($datetime)
	Return _Date_Time_SetLocalTime($tSysTime)
EndFunc

Func SyncTimeZone($tmz)
	Local $s = _Date_Time_GetTimeZoneInformation()
	LogUpload("Original time zone is " & $s[2] & ". Changing it to " & $tmz)
	RunWait('tzutil /s "' & $tmz & '"', "", @SW_HIDE)
	Local $s = _Date_Time_GetTimeZoneInformation()
	LogUpload("Now current time zone is " & $s[2])
	Return $s[2] = $tmz
EndFunc

Func UploadFile($arg)
	If $arg = "" Then Return False
	Switch StringLower($arg)
		Case "all"
			$uploadMode = "all"
		Case "idle"
			$uploadMode = "idle"
		Case "wait"
			$uploadMode = "wait"
		Case "now"
			$uploadMode = "now"
		Case Else
			PushFile(StringReplace($arg, "\!", "|"))	; change \! back to !
	EndSwitch

	If $uploadMode = "wait" Or $uploadMode = "idle" Then
		Return False
	EndIf

	Local $filename = PopFile(False)	; not pop the file until it is received by server
	If $filename = "" Then Return False

	$filename = StringReplace($filename, "\_", " ")	; change \_ back to space
	Local $file = FileOpen($filename,16)
	If $file = -1 Then
		LogUpload("Cannot find " & $filename & ".")
		Return False
	EndIf

	$fileContent = FileRead($file)
	FileClose($file)
	LogUpload("file " & $filename & " " & BinaryLen($fileContent))
	Return True
EndFunc

Func PushFile($newFile)
	If $newFile <> "" Then $filesToBeSent &= $newFile & " "
	Return
EndFunc

Func PopFile($pop = True)
	Local $length = StringInStr($filesToBeSent, " ", 2)	; there is a space at the end of string
	Local $nextFile = StringLeft($filesToBeSent, $length-1)
	If $pop Then
		$filesToBeSent = StringTrimLeft($filesToBeSent, $length)
	EndIf
	Return $nextFile
EndFunc

Func UpdateFile($filename, $filesize)
	$filename = StringReplace($filename, "\!", "|")
	$filename = StringReplace($filename, "\_", " ")
	$fileToBeUpdate = FileOpen($filename, 16+8+2)	; binary overwrite and force create directory
	$bytesCounter = $filesize
	Return True
EndFunc

Func HotKeyPressed()
	Switch @HotKeyPressed ; The last hotkey pressed.
		Case "{Esc}", "^q" ; KeyStroke is the {ESC} hotkey. to stop testing and quit
			$testEnd = True	;	Stop testing marker
			LogUpload("quit Automation is interrupt by operator.")
			MsgBox($MB_OK, $mMB, "Automation test is stopped.",2)
			Exit

		Case "+!t" ; Keystroke is the Shift-Alt-t hotkey, to stop the CopTrax App
			MsgBox($MB_OK, $mMB, "Terminating the CopTrax. Bye",2)
			If QuitCopTrax() Then
				LogUpload("CopTrax II has been stopped successfully.")
			Else
				LogUpload("Unable to stop CopTrax II.")
			EndIf

		Case "+!r" ; Keystroke is the Shift-Alt-r hotkey, to restart the automation test
			MsgBox($MB_OK, $mMB, "Restart the automation test. see you soon.",2)
			$testEnd = True	;	Stop testing marker
			$restart = True

		Case "+!s" ; Keystroke is the Shift-Alt-s hotkey, to start the CopTrax
			MsgBox($MB_OK, $mMB, "Starting the CopTrax",2)
			Run("c:\Program Files (x86)\IncaX\CopTrax\IncaXPCApp.exe", "c:\Program Files (x86)\IncaX\CopTrax")

		Case "!{SPACE}", "^{SPACE}" ; Keystroke is the Alt-Space or Ctrl-Space hotkey, to show the automation testing in-progress
			MsgBox($MB_OK, $mMB, "CopTrax Automation testing is in progress. " & $Socket ,2)

	EndSwitch
EndFunc   ;==>HotKeyPressed

Func ReportCPUMemory()
	Local $aProcUsage = _ProcessUsageTracker_Create($pCopTrax)
	Local $aMem = MemGetStats()
	Local $logLine = "Memory usage " & $aMem[0] & "%; "

	Local $aUsage = GetCPUUsage()
	Local $i
	For $i = 1 To $aUsage[0]
		$logLine &= 'CPU #' & $i & ' - ' & $aUsage[$i] & '%; '
	Next

	Sleep(2000)
	Local $fUsage = _ProcessUsageTracker_GetUsage($aProcUsage)
	$logLine &= $pCopTrax & " CPU usage: " & $fUsage & "%."

	If CheckEventLog() Then
		$logLine = "Continue " & $logLine
	Else
		$logLine = "FAILED " & $logLine
	EndIf
	LogUpload($logLine)	; Log with CPU and Memory Status

	_ProcessUsageTracker_Destroy($aProcUsage)
EndFunc

Func OnAutoItExit()
	TCPShutdown() ; Close the TCP service.
EndFunc   ;==>OnAutoItExit

Func ReadConfig()
	Local $file = FileOpen($configFile,0)	; for test case reading, readonly
	Local $aLine
	Local $aTxt
	Local $eof = False
	Do
		$aLine = FileReadLine($file)
		If @error < 0 Then ExitLoop

		$aLine = StringRegExpReplace($aLine, "([;].*)", "")
		$aLine = StringRegExpReplace($aLine, "([//].*)", "")
		If $aLine = "" Then ContinueLoop

		$aTxt = GetParameter($aLine, "ip")	; read the server IP address, default=10.0.5.211
		If $aTxt Then $ip = TCPNameToIP($aTxt)
		$aTxt = GetParameter($aLine, "port")	; read the server port, default = 16869
		If $aTxt Then $port = CorrectRange(Int($aTxt), 10000, 65000)
		$aTxt = GetParameter($aLine, "name")	; read the box serial number, default = Unknown
		If $aTxt Then $boxID = $aTxt
		$aTxt = GetParameter($aLine, "ctconfig")	; read the location of CopTrax configure, default is the same location
		If $aTxt Then $configDir = $aTxt
		$aTxt = GetParameter($aLine, "map")	; read the location to store the map
		If $aTxt Then $mapDir = $aTxt
		$aTxt = GetParameter($aLine, "bwc")	; read the location to store the Body wore Camera
		If $aTxt Then $bwcDir = $aTxt
	Until $eof

	FileClose($file)
EndFunc

Func RenewConfig()
	Local $file = FileOpen($configFile,1)	; Open config file in over-write mode
	FileWriteLine($file, "")
	FileWriteLine($file, "name=" & $boxID & " ")
	FileClose($file)
EndFunc

Func GetHandleWindowWait($title, $text = "", $seconds = 5)
	Local $hWnd0 = 0
	Local $hWnd1 = 0
	If $seconds < 1 Then $seconds = 1
	If $seconds > 10 Then $seconds = 10
	Do
		$hWnd0 = WinActivate($title, $text)
		$hWnd1 = WinWaitActive($title, $text, 1)
		If $hWnd0 And ($hWnd0 = $hWnd1) Then
			Return $hWnd0
		EndIf
		$seconds -= 1
	Until $seconds <= 0
	Return 0
EndFunc

Func GetParameter($parameters, $keyword)
	Local $parameter = StringRegExp($parameters, "(?:" & $keyword & "[= ])(.[^\s|]*)", $STR_REGEXPARRAYMATCH)
	If IsArray($parameter) Then
		Return StringReplace($parameter[0], "\_", " ") ; replace \_ back to space
	Else
		Return ""
	EndIf
EndFunc

Func CorrectRange($num, $lowerBand = 1, $upperBand = 999)
	If $num < $lowerBand Then Return $lowerBand
	If $num > $upperBand Then Return $upperBand
	Return $num
EndFunc

;#####################################################################
;# Function: GetCPUUsage()
;# Gets the utilization of the CPU, compatible with multicore
;# Return:   Array
;#           Array[0] Count of CPU, error if negative
;#           Array[n] Utilization of CPU #n in percent
;# Error:    -1 Error at 1st Dll-Call
;#           -2 Error at 2nd Dll-Call
;#           -3 Error at 3rd Dll-Call
;# Author:   Bitboy  (AutoIt.de)
;#####################################################################
Func GetCPUUsage()
	Local Const $SYSTEM_PROCESSOR_PERFORMANCE_INFORMATION = 8
	Local Const $SYSTEM_TIME_INFO = 3
	Local Const $tagS_SPPI = "int64 IdleTime;int64 KernelTime;int64 UserTime;int64 DpcTime;int64 InterruptTime;long InterruptCount"

	Local $CpuNum, $IdleOldArr[1],$IdleNewArr[1], $tmpStruct
	Local $timediff = 0, $starttime = 0
	Local $S_SYSTEM_TIME_INFORMATION, $S_SYSTEM_PROCESSOR_PERFORMANCE_INFORMATION
	Local $RetArr[1]

	Local $S_SYSTEM_INFO = DllStructCreate("ushort dwOemId;short wProcessorArchitecture;dword dwPageSize;ptr lpMinimumApplicationAddress;" & _
	"ptr lpMaximumApplicationAddress;long_ptr dwActiveProcessorMask;dword dwNumberOfProcessors;dword dwProcessorType;dword dwAllocationGranularity;" & _
	"short wProcessorLevel;short wProcessorRevision")

	$err = DllCall("Kernel32.dll", "none", "GetSystemInfo", "ptr",DllStructGetPtr($S_SYSTEM_INFO))

	If @error Or Not IsArray($err) Then
		Return $RetArr[0] = -1
	Else
		$CpuNum = DllStructGetData($S_SYSTEM_INFO, "dwNumberOfProcessors")
		ReDim $RetArr[$CpuNum+1]
		$RetArr[0] = $CpuNum
	EndIf
	$S_SYSTEM_INFO = 0

	While 1
		$S_SYSTEM_PROCESSOR_PERFORMANCE_INFORMATION = DllStructCreate($tagS_SPPI)
		$StructSize = DllStructGetSize($S_SYSTEM_PROCESSOR_PERFORMANCE_INFORMATION)
		$S_SYSTEM_PROCESSOR_PERFORMANCE_INFORMATION = DllStructCreate("byte puffer[" & $StructSize * $CpuNum & "]")
		$pointer = DllStructGetPtr($S_SYSTEM_PROCESSOR_PERFORMANCE_INFORMATION)

		$err = DllCall("ntdll.dll", "int", "NtQuerySystemInformation", _
			"int", $SYSTEM_PROCESSOR_PERFORMANCE_INFORMATION, _
			"ptr", DllStructGetPtr($S_SYSTEM_PROCESSOR_PERFORMANCE_INFORMATION), _
			"int", DllStructGetSize($S_SYSTEM_PROCESSOR_PERFORMANCE_INFORMATION), _
			"int", 0)

		If $err[0] Then
			Return $RetArr[0] = -2
		EndIf

		Local $S_SYSTEM_TIME_INFORMATION = DllStructCreate("int64;int64;int64;uint;int")
		$err = DllCall("ntdll.dll", "int", "NtQuerySystemInformation", _
			"int", $SYSTEM_TIME_INFO, _
			"ptr", DllStructGetPtr($S_SYSTEM_TIME_INFORMATION), _
			"int", DllStructGetSize($S_SYSTEM_TIME_INFORMATION), _
			"int", 0)

		If $err[0] Then
			Return $RetArr[0] = -3
		EndIf

		If $starttime = 0 Then
			ReDim $IdleOldArr[$CpuNum]
			For $i = 0 to $CpuNum -1
				$tmpStruct = DllStructCreate($tagS_SPPI, $Pointer + $i*$StructSize)
				$IdleOldArr[$i] = DllStructGetData($tmpStruct,"IdleTime")
			Next
			$starttime = DllStructGetData($S_SYSTEM_TIME_INFORMATION, 2)
			Sleep(100)
		Else
			ReDim $IdleNewArr[$CpuNum]
			For $i = 0 to $CpuNum -1
				$tmpStruct = DllStructCreate($tagS_SPPI, $Pointer + $i*$StructSize)
				$IdleNewArr[$i] = DllStructGetData($tmpStruct,"IdleTime")
			Next

			$timediff = DllStructGetData($S_SYSTEM_TIME_INFORMATION, 2) - $starttime

			For $i=0 to $CpuNum -1
				$RetArr[$i+1] = Round(100-(($IdleNewArr[$i] - $IdleOldArr[$i]) * 100 / $timediff))
			Next

			Return $RetArr
		EndIf

		$S_SYSTEM_PROCESSOR_PERFORMANCE_INFORMATION = 0
		$S_SYSTEM_TIME_INFORMATION = 0
		$tmpStruct = 0
	WEnd
EndFunc
; ========================================================================================================
; <Process_CPUUsage.au3>
;
; Example of Tracking a Process (or multiple processes) CPU usage.
; The functions maintain a 'Process Usage' object which updates itself and returns CPU usage.
;  Readings are shown in a 'Splash' window
;
; Functions:
;	_CPUGetTotalProcessorTimes()	; Gets Overall (combined CPUs) Processor Times
;	_ProcessUsageTracker_Create()	; Creates a Process CPU usage tracker for the given Process
;	_ProcessUsageTracker_GetUsage()	; Updates Process CPU usage tracker and returns Process % CPU usage
;	_ProcessUsageTracker_Destroy()	; Destroys the Process CPU Usage Tracker
;
; See Also:
;	<CPU_ProcessorUsage.au3>
;	Performance Counters UDF
;
; Author: Ascend4nt
; ========================================================================================================

; ==============================================================================================
; Func _CPUGetTotalProcessorTimes()
;
; Gets the total (combined CPUs) system processor times (as FILETIME)
; Note that Kernel Mode time includes Idle Mode time, so a proper calculation of usage time is
;   Kernel + User - Idle
; And percentage (based on two readings):
;  (Kernel_b - Kernel_a) + (User_b - User_a) - (Idle_b - Idle_a) * 100
;	/ (Kernel_b - Kernal_a) + (User_b - User_a)
;
; O/S Requirements: min. Windows XP SP1+
;
; Returns:
;  Success: Array of info for total (combined CPU's) processor times:
;   [0] = Idle Mode Time
;   [1] = Kernel Mode Time -> NOTE This INCLUDES Idle Time
;   [2] = User Mode Time
;
;  Failure: "" with @error set:
;	 @error = 2: DLLCall error, @extended = error returned from DLLCall
;    @error = 3: API call returned False - call GetLastError for more info
;
; Author: Ascend4nt
; ==============================================================================================

Func _CPUGetTotalProcessorTimes()
	Local $aRet, $aTimes

	$aRet = DllCall("kernel32.dll", "bool", "GetSystemTimes", "uint64*", 0, "uint64*", 0, "uint64*", 0)
	If @error Then Return SetError(2, @error, "")
	If Not $aRet[0] Then Return SetError(3, 0, "")

	Dim $aTimes[3] = [ $aRet[1], $aRet[2], $aRet[3] ]

	Return $aTimes
EndFunc

; ==============================================================================================
; Func _ProcessUsageTracker_Destroy(ByRef $aProcUsage)
;
; Destroys a ProcessUsage array object, closing handles first.
;
; In the future, if more than one process is monitored, this shouldn't be called until the
; end, and only individual process elements should be invalidated (and release their handles)
;
; Returns:
;  Success: True
;  Failure: False with @error set to 1 for invalid parameters
;
; Author: Ascend4nt
; ==============================================================================================

Func _ProcessUsageTracker_Destroy(ByRef $aProcUsage)
	If Not IsArray($aProcUsage) Or UBound($aProcUsage) < 2 Then Return SetError(1, 0, False)
	DllCall("kernel32.dll", "bool", "CloseHandle", "handle", $aProcUsage[1][2])
	$aProcUsage = ""
	Return True
EndFunc

; ==============================================================================================
; Func _ProcessUsageTracker_Create($sProcess, $nPID = 0)
;
; Creates a Process CPU usage tracker array (object)
; This array should be passed to _ProcessUsageTracker_GetUsage() to get
; current CPU usage information, and _ProcessUsageTracker_Destroy() to cleanup the resources.
;
; Returns:
;  Success: An array used to track Process CPU usage
;   Array 'internal' format:
;	  $arr[0][0] = # of Processes Being tracked (1 for now, may add to functionality in future)
;	  $arr[0][1] = Total Overall SYSTEM CPU Time (Kernel + User Mode) [updated with _GetUsage() call]
;	  $arr[1][0] = Process 1 Name
;	  $arr[1][1] = Process 1 PID
;	  $arr[1][2] = Process 1 Handle
;	  $arr[1][3] = Process 1 Access Rights (important for Protected Processes)
;	  $arr[1][4] = Process 1 Kernel Mode Time (updated with _GetUsage() call)
;	  $arr[1][5] = Process 1 User Mode Time (updated with _GetUsage() call)
;
;  Failure: "" with @error set [reflects _CPUGetTotalProcessorTimes codes]:
;	 @error =  2: DLLCall error, @extended = error returned from DLLCall
;    @error =  3: API call returned False - call GetLastError for more info
;	 @error = -1: GetProcessTimes error (shouldnt' occur)
;
; Author: Ascend4nt
; ==============================================================================================

Func _ProcessUsageTracker_Create($sProcess, $nPID = 0)
	Local $aRet, $iAccess, $hProcess, $aProcUsage[2][6]

	If Not $nPID Then
		$nPID = ProcessExists($sProcess)
	EndIf

	; XP, XPe, 2000, or 2003? - Affects process access requirement
	If StringRegExp(@OSVersion,"_(XP|200(0|3))") Then
		$iAccess = 0x0400	; PROCESS_QUERY_INFORMATION
	Else
		$iAccess = 0x1000	; PROCESS_QUERY_LIMITED_INFORMATION
	EndIf

	; SYNCHRONIZE access - required to determine if process has terminated
	$iAccess += 0x00100000

	$aRet = _CPUGetTotalProcessorTimes()
	If @error Then Return SetError(@error, @extended, "")

	; Total Overall CPU Time
	$aProcUsage[0][1] = $aRet[1] + $aRet[2]

	$hProcess = DllCall("kernel32.dll", "handle", "OpenProcess", "dword", $iAccess, "bool", False, "dword", $nPID)
	If @error Then Return SetError(2, @error, "")
	$hProcess = $hProcess[0]

	If $hProcess = 0 Then
		Local $nLastError = DllCall("kernel32.dll", "dword", "GetLastError")
		If @error Then Return SetError(2, @error, "")
		$nLastError = $nLastError[0]

		; ERROR_ACCESS_DENIED?  It must be a Protected process
		If $nLastError = 5 Then
			; Try without SYNCHRONIZE right. - Rely instead on ExitTime & GetExitCodeProcess
			$iAccess -= 0x00100000
			$hProcess = DllCall("kernel32.dll", "handle", "OpenProcess", "dword", $iAccess, "bool", False, "dword", $nPID)
			If @error Then Return SetError(2, @error, False)
			$hProcess = $hProcess[0]
			; Even with LIMITED access rights, some processes still won't open.. (e.g. CTAudSvc.exe)
			If $hProcess = 0 Then Return SetError(3, 0, "")
		Else
			Return SetError(3, $nLastError, "")
		EndIf
	EndIf

	$aProcUsage[0][0] = 1			; 1 Process Total (possible future expansion)

	$aProcUsage[1][0] = $sProcess	; Process Name
	$aProcUsage[1][1] = $nPID		; Process ID
	$aProcUsage[1][2] = $hProcess	; Process Handle
	$aProcUsage[1][3] = $iAccess	; Access Rights (useful to determine when process terminated)

	$aRet = DllCall("kernel32.dll", "bool", "GetProcessTimes", "handle", $hProcess, "uint64*", 0, "uint64*", 0, "uint64*", 0, "uint64*", 0)
	If @error Or Not $aRet[0] Then
		Local $iErr = @error
		_ProcessUsageTracker_Destroy($aProcUsage)
		Return SetError(-1, $iErr, "")
	EndIf

	$aProcUsage[1][4] = $aRet[4]	; Process Kernel Time
	$aProcUsage[1][5] = $aRet[5]	; Process User Time

	Return $aProcUsage
EndFunc

; ==============================================================================================
; Func _ProcessUsageTracker_GetUsage(ByRef $aProcUsage)
;
; Updates a ProcessUsage array and returns Process % CPU Usage information
;
; IMPORTANT: If Process is exited, this will return @error code of -1 and destroy the
; Process Usage array object. In the future this may change to just closing the handle
; if more Processes are monitored..
;
; Returns:
;  Success: Process CPU Usage (Percentage)
;  Failure: 0 with @error set to 1 for invalid parameters, or:
;	 @error =  2: DLLCall error, @extended = error returned from DLLCall
;    @error =  3: API call returned False - call GetLastError for more info
;	 @error = -1: Process Exited. The Usage Tracker will be destroyed after this!
;
; Author: Ascend4nt
; ==============================================================================================

Func _ProcessUsageTracker_GetUsage(ByRef $aProcUsage)
	If Not IsArray($aProcUsage) Or UBound($aProcUsage) < 2 Then Return SetError(1, 0, 0)

	Local $fUsage, $nCPUTotal, $aRet

	$aRet = _CPUGetTotalProcessorTimes()
	If @error Then Return SetError(@error, @extended, 0)

	; Total Overall CPU Time (current)
	$nCPUTotal = $aRet[1] + $aRet[2]

	$aRet = DllCall("kernel32.dll", "bool", "GetProcessTimes", "handle", $aProcUsage[1][2], "uint64*", 0, "uint64*", 0, "uint64*", 0, "uint64*", 0)
	If @error Or Not $aRet[0] Then
		Local $iErr = @error
		_ProcessUsageTracker_Destroy($aProcUsage)
		Return SetError(-1, $iErr, 0)
	EndIf

	; ExitTime field set with a time > CreationTime? (typically field is 0 if not exited)
	If $aRet[3] > $aRet[2] Then
	 ; MSDN says ExitTime is 'undefined' if process hasn't exited, so we do further checking]
		If BitAND($aProcUsage[1][3], 0x00100000) Then
			; See if process has ended (requires SYNCHRONIZE access (0x00100000)
			$aRet = DllCall("kernel32.dll", "dword", "WaitForSingleObject", "handle", $aProcUsage[1][2], "dword", 0)
			If Not @error And $aRet[0] = 0  Then
				_ProcessUsageTracker_Destroy($aProcUsage)
				Return SetError(-1, 0, 0)
			EndIf
		Else
			$aRet = DllCall("kernel32.dll", "bool", "GetExitCodeProcess", "handle", $aProcUsage[1][2], "dword*", 0)
			; Since we couldn't open with SYNCHRONIZE access, checking for no STILL_ACTIVE exit code is the next best thing
			If Not @error And $aRet[0] And $aRet[2] <> 259 Then
				_ProcessUsageTracker_Destroy($aProcUsage)
				Return SetError(-1, 0, 0)
			EndIf
		EndIf
		Return 0
	EndIf

	; Process Usage: (ProcKernelDelta + ProcUserDelta) * 100 / SysTotalDelta:
	$fUsage = Round( (($aRet[4] - $aProcUsage[1][4]) + ($aRet[5] - $aProcUsage[1][5]) ) * 100 / ($nCPUTotal - $aProcUsage[0][1]), 1)

	; Update current usage tracker info
	$aProcUsage[0][1] = $nCPUTotal
	$aProcUsage[1][4] = $aRet[4]
	$aProcUsage[1][5] = $aRet[5]

	Return $fUsage
EndFunc

Func _GetActiveSSID()
    Local $SSID = ""
    $objWMIService = ObjGet("winmgmts:{impersonationLevel=impersonate}!\\.\root\wmi")
    If Not IsObj($objWMIService) Then Return $SSID

    Local $objMSNdis_80211_ServiceSetIdentifierSet = $objWMIService.ExecQuery("Select * from MSNdis_80211_ServiceSetIdentifier Where active=true")
    If Not IsObj($objMSNdis_80211_ServiceSetIdentifierSet) Then Return $SSID

    For $objMSNdis_80211_ServiceSetIdentifier In $objMSNdis_80211_ServiceSetIdentifierSet
        $ID = ""
        For $i = 0 To $objMSNdis_80211_ServiceSetIdentifier.Ndis80211SsId(0)
            $ID = $ID & Chr($objMSNdis_80211_ServiceSetIdentifier.Ndis80211SsId($i + 4))
        Next
        $SSID = $ID
    Next
    Return $SSID
EndFunc  ;==>_GetActiveSSID