#RequireAdmin

#pragma compile(FileVersion, 2.12.20.77)
#pragma compile(FileDescription, Automation test client)
#pragma compile(ProductName, AutomationTest)
#pragma compile(ProductVersion, 2.11)
#pragma compile(CompanyName, 'Stalker')
#pragma compile(Icon, automation.ico)
;
; Test client for CopTrax Version: 1.0
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
HotKeySet("q", "HotKeyPressed") ; Esc to stop testing
HotKeySet("+!t", "HotKeyPressed") ; Shift-Alt-t to stop CopTrax
HotKeySet("+!s", "HotKeyPressed") ; Shift-Alt-s, to start CopTrax
HotKeySet("!{SPACE}", "HotKeyPressed") ; Space show the running CopTraxAutomation

Global Const $titleCopTraxMain = "CopTrax II v"
Global Const $titleAccount = "Account" ; "CopTrax - Login / Create Account"
Global Const $titleInfo = "Action" ; "Menu Action"
Global Const $titleLogin = "Login"
Global Const $titleRadar = "Radar" ; "CopTrax | Radar"
Global Const $titleReview = "Playback" ; "CopTrax | Video Playback"
Global Const $titleSettings = "Setup" ; "CopTrax II Setup"
Global Const $titleStatus = "CopTrax Status" ; "CopTrax Status"
Global Const $titleEndRecord = "Report" ; "Report Taken"
Global Const $TIMEOUTINSECEND = 300

TCPStartup()
Global $ip =  TCPNameToIP("10.0.7.63")
Global $port = 16869
Global $Socket = -1
Global $boxID = "CopTrax0"
Global $firmwareVersion = ""
Global $libraryVersion = ""
Global $appVersion = ""
Global $title = "CopTrax II is not up yet"
Global $userName = ""

Global $filesToBeSent = ""
Global $fileContent = ""
Global $bytesCounter = 0
Global $workDir = @ScriptDir & "\"
Global $configFile = $workDir & "client.cfg"
ReadConfig()

Global $fileToBeUpdate = $workDir & "tmp\" & @ScriptName
Global $testEnd = FileExists($fileToBeUpdate) ? FileGetVersion(@AutoItExe) <> FileGetVersion($fileToBeUpdate) : False
If FileGetSize($fileToBeUpdate) < 1000000 Then $testEnd = False	; update the client file only when it was completetly downloaded
$fileToBeUpdate = ""
Global $restart = $testEnd
Global Const $mMB = "CopTrax GUI Automation Test"

If $testEnd Then
	MsgBox($MB_OK, $mMB, "Automation test finds new update." & @CRLF & "Restarting now to complete the update.", 2)
	Run($workDir & "restartclient.bat")	; restart the test client
	Exit
Else
	MsgBox($MB_OK, $mMB, "Automation testing start. Connecting to" & $ip & "..." & @CRLF & "Esc to quit", 2)
EndIf

Global $chunkTime = 30

Global $sendBlock = False
Global $mCopTrax = 0
Global $pCopTrax = "IncaXPCApp.exe"
Global $hEventLogSystem = _EventLog__Open("", "System")
Global $hEventLogApp = _EventLog__Open("", "Application")
_EventLog__Read($hEventLogSystem, True, False)
_EventLog__Read($hEventLogApp, True, False)

OnAutoItExitRegister("OnAutoItExit")	; Register OnAutoItExit to be called when the script is closed.
AutoItSetOption ("WinTitleMatchMode", 2)
AutoItSetOption("SendKeyDelay", 100)

If WinExists("", "Open CopTrax") Then
	MouseClick("", 1002, 315)
	Send("{Enter}")
	MouseClick("", 820, 450)
	Sleep(5000)
EndIf

If WinExists($titleAccount) Then
	WinActivate($titleAccount)
	Sleep(1000)
	If Not CreatNewAccount("auto1", "coptrax") Then
		MsgBox($MB_OK, $mMB, "Something wrong! Quit automation test now.", 5)
		Exit
	Else
		MsgBox($MB_OK, $mMB, "First time run. Created a new acount.", 2)
	EndIf
EndIf

Global $hTimer = TimerInit()	; Begin the timer and store the handler
Global $timeout = 1000

While $mCopTrax = 0
	$mCopTrax = WinActivate($titleCopTraxMain)
	If $mCopTrax <> 0 Then
		$userName = GetUserName()
		If IsRecording() Then
			EndRecording(True)	; stop any recording in progress before automation test
		EndIf
	Else
		MsgBox($MB_OK, $mMB, "CopTrax II is not up yet.", 2)
		If $testEnd Then
			Exit
		EndIf
	EndIf
WEnd

If Not StringRegExp($boxID, "[A-Za-z]{2}[0-9]{6}")  Then
	MsgBox($MB_OK, $mMB, "Now reading Serial Number from the box.", 2)
	TestSettingsFunction("NULL")
EndIf

Local $currentTime = TimerDiff($hTimer)
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
		If $Socket >= 0 Then
			LogUpload("name " & $boxID & " " & $userName & " " & FileGetVersion(@AutoItExe) & " " & $title)
			MsgBox($MB_OK, $mMB, "Connected to server.",2)
			$timeout = $currentTime + 1000*$TIMEOUTINSECEND
		Else
	  		If  $currentTime > $timeout Then
				MsgBox($MB_OK, $mMB, "Cannot connected to server. Please check the network connection or the server.", 10)
				$timeout = TimerDiff($hTimer) + 1000*10	; check the networks connection every 10s.
				$Socket = -1
			EndIf
		EndIf
   Else
	  ListenToNewCommand()
	  If  $currentTime > $timeout Then
		  $testEnd = True
		  $restart = True
;		 LogUpload("quit")		; Not get any commands from the server, then quit and trying to connect the server again;
;		 TCPCloseSocket($Socket)
;		 $Socket = -1
;		 $timeout += 1000*10 ; check the networks connection in 10s.
	  EndIf
   EndIf
   Sleep(100)
WEnd

LogUpload("quit")
TCPShutdown() ; Close the TCP service.
FileClose($fileToBeUpdate)
_EventLog__Close($hEventLogSystem)
_EventLog__Close($hEventLogApp)

If $restart Then
	If IsRecording() Then
		EndRecording(True)	; stop any recording in progress before automation test
	EndIf
	Run("C:\CopTraxAutomation\restartclient.bat")	; restart the test client
Else
	MsgBox($MB_OK, $mMB, "Testing ends. Bye.",5)
EndIf

Exit

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
	If Not ReadyForTest() Then  Return False

	AutoItSetOption("SendKeyDelay", 200)
	MouseClick("",960,560)	; click on the info button
	Sleep(400)

	If WinWaitActive($titleInfo, "", 10) = 0 Then
		MsgBox($MB_OK, $mMB, "Cannot trigger the Info window. " & @CRLF, 5)
		LogUpload("Click on the info button failed.")
		WinClose($titleInfo)
		Return False
	EndIf

	Sleep(500)
	Send("{TAB}{END}{TAB}{ENTER}")	; choose the Administrator
	; ControlClick($titleInfo,"","Apply")

	Sleep(500)
	If WinWaitActive($titleLogin, "", 10) = 0 Then
		MsgBox($MB_OK, $mMB, "Cannot trigger the Login window.",2)
		LogUpload("Click on Apply button to close the Login window failed.")
		WinClose($titleLogin)
		Return False
	EndIf

	Send("135799{ENTER}")	; type the administator password
	MouseClick("", 500, 150)
	$mCopTrax = 0
	Return True
EndFunc

Func TestUserSwitchFunction($arg)
	If Not ReadyForTest() Then  Return False

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
	If WinWaitActive($mTitle,"",10) = 0 Then
		MsgBox($MB_OK, $mMB, "Cannot trigger the info window. " & @CRLF, 5)
		LogUpload("Click to open info window failed.")
		WinClose($mTitle)
		Return False
	EndIf

	Sleep(500)
	Send("{Tab}s{Tab}{Enter}")	; choose switch Account
	Sleep(500)

	Return CreatNewAccount($username, $password)
EndFunc

Func CreatNewAccount($name, $password)
	Local $hWnd = WinWaitActive($titleAccount, "", 10)
	If  $hWnd = 0 Then
		MsgBox($MB_OK, $mMB, "Cannot trigger the CopTrax-Login/Create Account window. " & @CRLF, 5)
		LogUpload("Trigger the CopTrax-Login/Create Account window failed.")
		Return False
	EndIf

	Local $txt = WinGetText($hWnd)
	If StringInStr($txt, "Key") Then
		;MouseClick("", 640, 55)
		Send("{TAB 3}{END}")
		If WinWaitActive("Server", "", 5) = 0 Then
			MsgBox($MB_OK, $mMB, "Cannot open Server Configuration window. " & @CRLF, 5)
			LogUpload("Cannot open Server Configuration window. ")
			WinClose($hWnd)
			Return False
		EndIf

		Sleep(500)
		Send("10.0.6.32")
		MouseClick("", 350,70)
		ControlCommand("Server", "", "[INSTANCE:1]", "Check")
		ControlClick("Server", "", "Test")
		Sleep(5000)
		ControlClick("Server", "", "OK")
		WinWaitClose("Server", "", 5)

		Sleep(500)
		Send("{TAB 2}")
	EndIf
	Send($name)
	Sleep(500)

	Send("{Tab}" & $password)	; type the user password
	Sleep(500)
	Send("{Tab}" & $password)	; re-type the user password
	Sleep(2000)
	Send("{Tab}{ENTER}")
	MouseClick("", 670, 230)	; clear the soft keyboard
	;ControlClick($hWnd, "", "Register")

	If WinWaitClose($hWnd,"",10) = 0 Then
		MsgBox($MB_OK, $mMB, "Clickon the Register button to close the window failed.",2)
		LogUpload("Click on the Register button to exit failed.")
		WinClose($hWnd)
		Return False
	EndIf

	Sleep(1000)

	If $mCopTrax = 0 Then Return True

	$userName = GetUserName()
	If $userName <> $name Then
		LogUpload("Switch to new user failed. Current user is " & $userName)
		Return False
	EndIf

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

	If $click And (Not ReadyForTest()) Then  Return False

   	If $click And Not IsRecording() Then	; check if the specified *.mp4 files is modifying
		LogUpload("No recording in progress.")
		Return False
	EndIf

	Local $i=0
	Do
		If $click Then
			MouseClick("", 960, 80)	; click on the button to stop record
		EndIf
		$i += 1
	Until WinWaitActive($titleEndRecord,"",5) <> 0 Or $i > 3

	If $i > 3 Then
		LogUpload("Click to stop record failed. ")
		MsgBox($MB_OK,  $mMB, "Cannot trigger the end record function",2)
		Return False
	EndIf

	Local $hEndRecord = WinActivate($titleEndRecord)
	AutoItSetOption("SendKeyDelay", 100)
	Sleep(200)
	Send("tt{Tab}")
	Sleep(200)

	Send("This is a test input by CopTrax testing team.")
	Sleep(100)
	MouseClick("", 670,90)

	ControlClick($hEndRecord,"","OK")
	Sleep(100)

	If WinWaitClose($hEndRecord,"",10)  Then
		Return True
	Else
		MsgBox($MB_OK,  $mMB, "Click on the OK button failed",2)
		LogUpload("Click on the OK button to stop record failed. ")
		WinClose($hEndRecord)
		Return False
	EndIf
EndFunc

Func TestSettingsFunction($arg)
	If Not ReadyForTest() Then  Return False

	Local $pre = GetParameter($arg, "pre")
	Local $chunk = GetParameter($arg, "chunk")
	Local $cam2 = StringLower(GetParameter($arg, "cam2"))
	Local $cam3 = StringLower(GetParameter($arg, "cam3"))

	MouseClick("",960, 460)
	LogUpload("Start settings function testing.")

	If WinWaitActive($titleLogin, "", 2) <> 0 Then
		Send("135799{ENTER}")	; type the administator password
		MouseClick("", 500, 150)
	EndIf

	; $mTitle = "CopTrax II Setup"
	Local $hWnd = WinWaitActive($titleSettings, "", 10)
	If $hWnd = 0 Then
		MsgBox($MB_OK, $mMB, "Cannot trigger the settings function.", 2)
		LogUpload("Click to start the settings function failed.")
		Return False
	EndIf

	Local $positionY = 60
	Do
		MouseClick("", 60, $positionY)
		Sleep(500)
		Local $txt = WinGetText($hWnd)
		If StringInStr($txt, "Capture") Then	; Cameras
			ControlClick($hWnd, "", "Test")
			If $pre >= 0 Then
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
			EndIf

			If $cam2 <> "" Or $cam3 <> "" Then
				Send("+{Tab 4}2")	; select Camera
				sleep(2000)
				If $cam2 = "enabled" Then
					ControlCommand($hWnd, "", "[CLASS:Button; TEXT:secondary; INSTANCE:4]", "Check")
					ControlCommand($hWnd, "", "[CLASS:Button; TEXT:Always; INSTANCE:5]", "Check")
				EndIf
				If $cam2 = "disabled" Then
					ControlCommand($hWnd, "", "[CLASS:Button; TEXT:secondary; INSTANCE:4]", "uncheck")
					ControlCommand($hWnd, "", "[CLASS:Button; TEXT:Always; INSTANCE:5]", "uncheck")
				EndIf

				ControlClick($hWnd, "", "Test")
				Sleep(2000)
			EndIf

			If $cam3 <> "" Then
				Send("+{Tab 3}3")	; select Camera
				sleep(2000)
				If $cam3 = "enabled" Then
					ControlCommand($hWnd, "", "[CLASS:Button; TEXT:third; INSTANCE:3]", "Check")
				EndIf
				If $cam3 = "disabled" Then
					ControlCommand($hWnd, "", "[CLASS:Button; TEXT:third; INSTANCE:3]", "uncheck")
				EndIf

				ControlClick($hWnd, "", "Test")
				Sleep(2000)
			EndIf
		EndIf

		If StringInStr($txt, "Identify") Then	; Hardware Triggers
			ControlClick($hWnd, "", "Identify")
			Sleep(2000)
			Local $id = StringTrimLeft(WinGetText("CopTrax", "OK"), 2)
			LogUpload("Identify of current box is " & $id)
			$readTxt = StringRegExp($id, "[0-9]+\.[0-9]+\.[0-9]+\.?[0-9a-zA-Z]*", $STR_REGEXPARRAYGLOBALMATCH)
			If UBound($readTxt) < 2 Then
				$boxID = ""
				$firmwareVersion = ""
				$libraryVersion = ""
				LogUpload("Identify reading error.")
				Return False
			Else
				$libraryVersion = $readTxt[0]
				$firmwareVersion = $readTxt[1]
			EndIf

			$readTxt =  StringRegExp($id, "([a-zA-Z]{2}[0-9]{6})", $STR_REGEXPARRAYMATCH)
			If $readTxt = "" Then
				$boxID = "WrongSN"
				LogUpload("Serial number reading error.")
				Return False
			EndIf
			Local $readID = $readTxt[0]

			If StringCompare($readID, $boxID) <> 0 Then
				LogUpload("Changed the box ID in config file.")
				$boxID = $readID
				RenewConfig()
			EndIf

			WinClose("CopTrax", "OK")	; click to close the Identify popup window
		EndIf

		If StringInStr($txt, "Visual") Then	; Speed Triggers
			Sleep(1000)
		EndIf

		If StringInStr($txt, "Baud") Then	; GPS & Radar
			ControlClick($hWnd, "", "Test")
			Sleep(2000)
		EndIf

		If StringInStr($txt, "Max") Then	; Upload & Storage
			$chunkTime = CorrectRange(Int($chunk), 0, 60)
			Send("{Tab}{BS 4}20" & $chunkTime)
			MouseClick("", 800,100) ; clear the soft keyboard
			Sleep(1000)
		EndIf

		If StringInStr($txt, "Welcome") Then	; Misc
			ControlCommand($hWnd, "", "[CLASS:Button; TEXT:keyboard; INSTANCE:13]", "uncheck")
			ControlCommand($hWnd, "", "[CLASS:Button; TEXT:welcome; INSTANCE:12]", "Check")
			Sleep(1000)
		EndIf
		$positionY += 60
	Until $positionY > 480

	ControlClick($hWnd, "", "Apply")
	If WinWaitClose($hWnd, "", 10) = 0 Then
		MsgBox($MB_OK, $mMB, "Click on the Apply button failed", 2)
		LogUpload("Click on the Apply button to quit settings failed.")
		WinClose($hWnd)
		Return False
	EndIf

	Return True
EndFunc

Func ReadyForTest()
	If WinExists($titleStatus) Then
		LogUpload("The accessories are not ready.")
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

	If WinExists($titleEndRecord) Then
		WinClose($titleEndRecord)
		Sleep(100)
	EndIf

	If WinExists("CopTrax","OK") Then
		Local $txt = WinGetText("CopTrax", "OK")
		WinClose("CopTrax","OK")
		Sleep(100)
		If StringInStr($txt, "Full") Then
			LogUpload("Disk Full! No more automation test.")
			$testEnd = True
			$restart = False
			Return False
		EndIf
	EndIf

	$mCopTrax = WinActivate($titleCopTraxMain)
	Sleep(100)
	If WinWaitActive($mCopTrax, "", 2) = 0 Then
		LogUpload("The CopTrax is not ready.")
		Return False
	EndIf

	Return True
EndFunc

Func CheckEventLog()
	Local $aEvent
	Local $bEvent
	Local $rst = True
	Do
		$aEvent = _EventLog__Read($hEventLogSystem, True, True)

		If $aEvent[7] = 1 Then
			LogUpload("Event " &  $aEvent[4] & " " & $aEvent[5] & " ID=" & $aEvent[6] & " " & $aEvent[13])
			$rst = $aEvent[6]
		EndIf
	Until Not $aEvent[0]

	Do
		$aEvent = _EventLog__Read($hEventLogApp, True, True)

		If $aEvent[7] = 1 Then
			LogUpload("Event " &  $aEvent[4] & " " & $aEvent[5] & " ID=" & $aEvent[6] & " " & $aEvent[13])
			$rst = $aEvent[6]
		EndIf
	Until Not $aEvent[0]


	Return ($rst = 10110)
EndFunc

Func TestCameraSwitchFunction()
	Local $file1
	Local $file2
	Local $file3
	If Not ReadyForTest() Then  Return False

	LogUpload("Begin Camera switch function testing.")
	$file1 = TakeScreenCapture("Main Cam1", $mCopTrax)

	MouseClick("",960,170)	; click to rear camera2
	Sleep(2000)
	$file2 = TakeScreenCapture("Rear Cam2", $mCopTrax)

	MouseClick("", 200,170)	; click to switch rear camera
	Sleep(2000)
	$file3 = TakeScreenCapture("Rear Cam3", $mCopTrax)

	MouseClick("", 960,170)	; click back to main camera
	Sleep(1000)

	If ($file1 < 100000) Or ($file2 < 100000) Or ($file3 < 100000) Then
		LogUpload("Blank screen encountered.")
		Return False
	EndIf

	If ($file1 < $file2) Or ($file1 < $file3) Then
		LogUpload("Main Camera mistake.")
		Return False
	EndIf

	Return True
EndFunc

Func TakeScreenCapture($comment, $hWnd)
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

    Local $screenFile = $workDir & "tmp\" & $boxID & $Char1 & $Char2 & $Char3 & ".jpg"
	If _ScreenCapture_CaptureWnd($screenFile, $hWnd) Then
		LogUpload("Captured " & $comment & " screen file " & $boxID & $Char1 & $Char2 & $Char3 & ".jpg. It is now on the way sending to server.")
		$filesToBeSent =  $screenFile & "|" & $filesToBeSent
		Return FileGetSize($screenFile)
	Else
		LogUpload("Cannot capture " & $comment & " screen file.")
		Return 0
	EndIf
EndFunc

Func TestPhotoFunction()
	If Not ReadyForTest() Then Return False

	LogUpload("Begin Photo function testing.")
	MouseClick("", 960, 350);

	Local $hWnd = WinWaitActive("Information", "", 10)
	If $hWnd = 0 Then
		MsgBox($MB_OK, $mMB, "Click to trigger the Photo function failed.",2)
		LogUpload("Click to trigger the Photo function failed.")
		Return False
	EndIf

	Sleep(2000)
	ControlClick($hWnd,"","OK")
	Sleep(200)

	If WinWaitClose($hWnd, "", 10) = 0 Then
		MsgBox($MB_OK, $mMB, "Click to close the Photo failed.",2)
		LogUpload("Click to quit Photo taking window failed.")
		WinClose($hWnd)
		Return False
	EndIf

   Return True
EndFunc

Func TestRadarFunction()
	If Not ReadyForTest() Then Return False

	LogUpload("Begin RADAR function testing.")

	Local $testResult = False
	Local $hRadar
	If WinExists($titleRadar) Then
		$hRadar = WinActivate($titleRadar)
		TakeScreenCapture("RADAR On", $hRadar)
		$testResult = True
	EndIf

	MouseClick("", 50, 570)
	Sleep(5000)

	If WinExists($titleRadar) Then
		$hRadar = WinActivate($titleRadar)
		TakeScreenCapture("RADAR On", $hRadar)
		$testResult = True
	EndIf

	Return $testResult
EndFunc

Func TestReviewFunction()
	If Not ReadyForTest() Then Return False

	LogUpload("Begin Review function testing.")

	MouseClick("", 960, 260);
	Local $hWnd = WinWaitActive($titleReview, "", 10)
	If $hWnd = 0 Then
		MsgBox($MB_OK, $mMB, "Click to trigger the Review function failed.",2)
		LogUpload("Click to trigger the Review function failed.")
		Return False
	EndIf
	TakeScreenCapture("Playback from CT2", $hWnd)

	Sleep(5000)
	WinClose($hWnd)
	Sleep(200)

	If WinWaitClose($hWnd, "", 10) = 0 Then
		MsgBox($MB_OK, $mMB, "Click to close the playback window failed.",2)
		LogUpload("Click to close the playback review function failed.")
		Return False
	EndIf
	Return True
EndFunc

Func LogUpload($s)
   If $sendBlock Or $Socket < 0 Then
	   MsgBox($MB_OK, $mMB, $s, 5)
	   Return
   EndIf

   TCPSend($Socket, $s & " ")
   If StringLower(StringMid($s, 1, 6)) = "failed" Then
		TakeScreenCapture("failure", $mCopTrax)
	Else
		Sleep(1000)
	EndIf
EndFunc

Func IsRecording()
	Local $path = @MyDocumentsDir & "\CopTraxTemp"
	Local $filter = "*.JPG"
	Local $aFileList = _FileListToArray($path, $filter, 0, True)
	If @error > 0 Then
		Return False
	Else
		Return True
	EndIf
EndFunc

Func CheckRecordedFiles()
	LogUpload("Begin to review the records to check the chunk time.")

	Local $path0 = @MyDocumentsDir & "\CopTraxTemp"
	Local $path1 = GetVideoFilePath()
	Local $path2 = $path1 & "\cam2"
	Local $fileTypes = ["*.*","*.wmv", "*.jpg", "*.gps", "*.txt", "*.rdr", "*.vm", "*.trax", "*.rp"]
	Local $latestFiles[9+9]
	Local $videoFilesCam1 = GetVideoFileNum($path1, "*.wmv") + GetVideoFileNum($path0, @MDAY & "*.mp4")
	Local $videoFilesCam2 = GetVideoFileNum($path2, "*.wmv") + GetVideoFileNum($path2, "*.avi")
	LogUpload("Today the main camera has recorded " & $videoFilesCam1 & " video files. The rear camera has recorded " & $videoFilesCam2 & " video files. The setup chunk time is " & $chunkTime & " minutes.")

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
	Local $chk = True
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
			LogUpload("Find critical file " & $fileTypes[$n] & " missed in records.")
			$chk = False	; return False when .gps or .wmv or .jpg files were missing,
			If Abs(CalculateTimeDiff($time1, $time0)) < 3 Then
				LogUpload("Find " & $file0 & " in backup folder.")
			EndIf
		EndIf
	Next

	Local $chunk1 = CalculateChunkTime($latestFiles[1])
	Local $chunk2 = CalculateChunkTime($latestFiles[10])
	LogUpload("For " & $latestFiles[1] & ", the chunk time is " & $chunk1 & " seconds.")
	LogUpload("For " & $latestFiles[10] & ", the chunk time is " & $chunk2 & " seconds.")
	If $chunk1 > $chunkTime*60 + 30 Then $chk = False
   ;If $chunk2 > $chunkTime*60 + 30 Then $chk = False

   Return $chk
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
    Local $aFileList = _FileListToArray($path, $type, 1, True)

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

Func CalculateTimeDiff($time1,$time2)
   If (StringLen($time1) <> 14) Or (StringLen($time2) <> 14) Then Return 100000
   Local $t0 = (Number(StringMid($time2, 1, 8)) - Number(StringMid($time1, 1, 8)))*24*3600
   ; get the time difference in format yyyymmddhhmmss
   Local $t1 = Number(StringMid($time1, 9, 2)) * 3600 + Number(StringMid($time1, 11, 2)) * 60 + Number(StringMid($time1, 13, 2))
   Local $t2 = Number(StringMid($time2, 9, 2)) * 3600 + Number(StringMid($time2, 11, 2)) * 60 + Number(StringMid($time2, 13, 2))
   Return $t2 - $t1 + $t0
EndFunc

Func ListenToNewCommand()
	Local $raw = TCPRecv($Socket, 1000000)
	If $raw = "" Then Return
	$timeout = TimerDiff($hTimer) + 1000 * $TIMEOUTINSECEND

	If $fileToBeUpdate <> "" Then
		FileWrite($fileToBeUpdate, $raw)
		$len = StringLen($raw)
		LogUpload("Received " & $len & " bytes, write them to file.")
		$bytesCounter -= $len
		If $bytesCounter <= 10 Then
			FileClose($fileToBeUpdate)
			$fileToBeUpdate = ""
			Sleep(1000)
			LogUpload("Continue")
		EndIf
		Return
	EndIf

	Local $Recv = StringSplit($raw, " ")
	Switch StringLower($Recv[1])
		Case "runapp" ; get a stop command, going to stop testing and quit
			MsgBox($MB_OK, $mMB, "Re-starting the CopTrax",2)
			Run("c:\Program Files (x86)\IncaX\CopTrax\IncaXPCApp.exe", "c:\Program Files (x86)\IncaX\CopTrax")
			LogUpload("PASSED Start the CopTrax")

		Case "stopapp" ; get a stop command, going to stop testing and quit
			MsgBox($MB_OK, $mMB, "Stop CopTrax App",2)
			If QuitCopTrax() Then
				LogUpload("PASSED")
			Else
				LogUpload("FAILED to stop CopTrax II.")
			EndIf

		Case "startrecord", "record" ; Get a record command. going to test the record function
			MsgBox($MB_OK, $mMB, "Testing the start record function",2)
			If StartRecord(True) Then
				LogUpload("PASSED the test on start record function.")
			Else
				LogUpload("FAILED to start a record.")
			EndIf

		Case "startstop", "lightswitch" ; Get a startstop trigger command
			MsgBox($MB_OK, $mMB, "Testing the trigger Light switch button function",2)
			If WinWaitActive($titleEndRecord, "", 2) Then	; check if a recording progress exists
				If EndRecording(False) Then
					LogUpload("PASSED the test to end the record by trigger Light switch button.")
				Else
					LogUpload("FAILED to end the record by trigger Light switch button.")
				EndIf
			Else
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

		Case "upload"
			MsgBox($MB_OK, $mMB, "Testing file upload function",2)
			If $Recv[0] >= 2 Then
				$filesToBeSent =  $Recv[2] & "|" & $filesToBeSent
				UploadFile()
			EndIf
			LogUpload("PASSED file upload start.")

		Case "update"
			MsgBox($MB_OK, $mMB, "Testing file update function",2)
			If ($Recv[0] >=3) And UpdateFile($Recv[2], Int($Recv[3])) Then
				LogUpload("Continue")
			Else
				LogUpload("FAILED to update " & $Recv[2])
			EndIf

		Case "synctime"
			MsgBox($MB_OK, $mMB, "Synchronizing client time to server",2)
			If ($Recv[0] >= 2) And SyncDateTime($Recv[2]) Then
				LogUpload("PASSED date and time syncing. The client is now " & @YEAR & "/" & @MON & "/" & @MDAY & " " & @HOUR & ":" & @MIN & ":" & @SEC)
			Else
				LogUpload("FAILED to sync date and time.")
			EndIf

		Case "synctmz"
			MsgBox($MB_OK, $mMB, "Synchronizing client timezone to server's",2)
			If ($Recv[0] >= 2) And SyncTimeZone(StringMid($raw, 9)) Then
				LogUpload("PASSED timezone synchronization.")
			Else
				LogUpload("FAILED to sync timezone to server's.")
			EndIf

		Case "checkrecord"
			MsgBox($MB_OK, $mMB, "Checking the record files.",2)
			If CheckRecordedFiles() Then
				LogUpload("PASSED the check on recorded files.")
			Else
				LogUpload("Continue Warning on the check of recorded files.")
			EndIf

		Case "eof"
			$sendBlock = False
			LogUpload("Continue End of file stransfer")

		Case "send"
			TCPSend($Socket,$fileContent)
			$sendBlock = True

		Case "quit", "endtest", "quittest"
			LogUpload("quit The test client will stop.")
			$testEnd = True	;	Stop testing marker
			$restart = False

		Case "restart", "restarttest"
			LogUpload("quit The test client will restart.")
			$testEnd = True	;	Stop testing marker
			$restart = True

		Case "status", "heartbeat"
			ReportCPUMemory()
			UploadFile()

		Case "info"
			LogUpload("Continue function not programmed yet.")

		Case "checkfirmware"
			MsgBox($MB_OK, $mMB, "Checking client version is " & $Recv[2] & " or not..",2)
			If $firmwareVersion = "" Then
				LogUpload("FAILED firmware version check. Run settings command before checking the firmware version.")
				ContinueCase
			EndIf

			If ($Recv[0] >= 2) And ($firmwareVersion = $Recv[2]) Then
				LogUpload("PASSED firmware version check. The firmware version is " & $firmwareVersion)
			Else
				LogUpload("FAILED firmware version check. The current firmware version is " & $firmwareVersion & ", not " & $Recv[2])
			EndIf

		Case "checkapp"
			MsgBox($MB_OK, $mMB, "Checking CopTrax version is " & $Recv[2] & " or not.",2)

			If ($Recv[0] >= 2) And ($appVersion = $Recv[2]) Then
				LogUpload("PASSED CopTrax version check. The CopTrax version is " & $appVersion)
			Else
				LogUpload("FAILED CopTrax version check. The current CopTrax version is " & $appVersion & ", not " & $Recv[2])
			EndIf

		Case "checklibrary"
			MsgBox($MB_OK, $mMB, "Checking library version is " & $Recv[2] & " or not..",2)

			If ($Recv[0] >= 2) And ($libraryVersion = $Recv[2]) Then
				LogUpload("PASSED library version check. The library version is " & $libraryVersion)
			Else
				LogUpload("FAILED library version check. The current library version is " & $libraryVersion & ", not " & $Recv[2])
			EndIf

		Case "cleanup"
			LogUpload("PASSED The box is being cleaned up.")
			Run("C:\Coptrax Support\Tools\Cleanup.bat")
			LogUpload("Going to shutdown the box.")
			OnAutoItExit()
			Shutdown(1+4)	; force the window to shutdown
			Exit

		Case "reboot"
			LogUpload("quit Going to reboot the box.")
			OnAutoItExit()
			Shutdown(2+4)	; force the window to reboot
			Exit

	EndSwitch
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
	RunWait('tzutil /s "' & $tmz & '"')
	Local $s = _Date_Time_GetTimeZoneInformation()
	LogUpload("Now current time zone is " & $s[2])
	Return $s[2] = $tmz
EndFunc

Func UploadFile()
	If $filesToBeSent = "" Then Return

	Local $fileName = StringSplit($filesToBeSent, "|")
	$filesToBeSent = StringTrimLeft($filesToBeSent, StringLen($fileName[1])+1)
	If $fileName[1] = "" Then Return

	Local $file = FileOpen($filename[1],16)
	If $file = -1 Then
		LogUpload($filename[1] & " does not exist.")
		Return
	EndIf

	$fileContent = FileRead($file)
	FileClose($file)
	Local $fileLen = StringLen($fileContent)
;	If StringIsASCII($fileContent) Then $fileLen = Round($fileLen/2)
	Sleep(1000)
	LogUpload("file " & $filename[1] & " " & $fileLen & " " & $filesToBeSent)
EndFunc

Func UpdateFile($filename, $filesize)
   $fileToBeUpdate = FileOpen($filename, 16+8+2)	; binary overwrite and force create directory
   $bytesCounter = $filesize
   Return True
EndFunc

Func HotKeyPressed()
   Switch @HotKeyPressed ; The last hotkey pressed.
	  Case "{Esc}", "q" ; KeyStroke is the {ESC} hotkey. to stop testing and quit
	  $testEnd = True	;	Stop testing marker

	  Case "+!t" ; Keystroke is the Shift-Alt-t hotkey, to stop the CopTrax
		 MsgBox($MB_OK, $mMB, "Terminating the CopTrax. Bye",2)
		 QuitCopTrax()

	  Case "+!s" ; Keystroke is the Shift-Alt-s hotkey, to start the CopTrax
		 MsgBox($MB_OK, $mMB, "Starting the CopTrax",2)
		 Run("c:\Program Files (x86)\IncaX\CopTrax\IncaXPCApp.exe", "c:\Program Files (x86)\IncaX\CopTrax")

	  Case "!{SPACE}" ; Keystroke is the Alt-Space hotkey, to show the automation testing in-progress
		 MsgBox($MB_OK, $mMB, "CopTrax Automation testing is in progress.",2)

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
	Local $fUsage = _ProcessUsageTracker_GetUsage($aProcUsage)
	$logLine &= $pCopTrax & " CPU usage: " & $fUsage & "%."

	If CheckEventLog() Then
		$logLine = "Continue " & $logLine
	Else
		$logLine = "Failed " & $logLine
	EndIf
	LogUpload($logLine)	; Log with CPU and Memory Status

	_ProcessUsageTracker_Destroy($aProcUsage)
EndFunc

Func OnAutoItExit()
	LogUpload("quit")
    TCPShutdown() ; Close the TCP service.
 EndFunc   ;==>OnAutoItExit

Func ReadConfig()
	Local $file = FileOpen($configFile,0)	; for test case reading, readonly
	Local $aLine
	Local $aTxt
	Local $eof
	Do
		$aTxt = FileReadLine($file)
		$eof = @error < 0
		If $aTxt = "" Then ContinueLoop

		$aLine = StringSplit($aTxt, " ")
		If ($aLine = "") Or ($aLine[0] < 2) Then ContinueLoop

		Switch StringLower($aLine[1])
			Case "ip"
				$ip = TCPNameToIP($aLine[2])
			Case "port"
				$port = Int($aLine[2])
				If $port < 10000 Or $port > 65000 Then
				$port = 16869
				EndIf
			Case "name"
				$boxID = StringLeft(StringStripWS($aLine[2], 3), 8)
		 EndSwitch
   Until $eof

   FileClose($file)
EndFunc

Func RenewConfig()
   Local $file = FileOpen($configFile,1)	; Open config file in over-write mode
   FileWriteLine($file, "")
   FileWriteLine($file, "name " & $boxID & " ")
   FileClose($file)
EndFunc

Func GetParameter($parameters, $keyword)
	If StringInStr($parameters, "=") Then
		Local $parameter = StringRegExp($parameters, "(?:" & $keyword & "=)([a-zA-Z0-9]+)", $STR_REGEXPARRAYMATCH)
		If $parameter = "" Then
			Return ""
		Else
			Return $parameter[0]
		EndIf
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
