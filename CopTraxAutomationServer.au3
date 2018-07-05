#Region ;**** Directives created by AutoIt3Wrapper_GUI ****
#AutoIt3Wrapper_Res_Description=Automation test server
#AutoIt3Wrapper_Res_Fileversion=2.4.10.30
#AutoIt3Wrapper_Res_Fileversion_AutoIncrement=y
#EndRegion ;**** Directives created by AutoIt3Wrapper_GUI ****

#pragma compile(Icon, ..\clouds.ico)
;
; Test Server for CopTrax
; Version: 1.0
; Language:       AutoIt
; Platform:       Win8 or Win10
; Script Function:
;	Read test case from file
;   Listen for the target CopTrax box, waiting its powerup and connection to the server;
;   Send test commands from the test case to individual target(client);
;	Receive test results from the target(client), verify it passed or failed, log the result;
;	Drop the connection to the client when the test completed.
; Author: George Sun
; Nov., 2017
;

#include <Constants.au3>
#include <Timers.au3>
#include <File.au3>
#include <Date.au3>
#include <GUIConstants.au3>
#include <GUIConstantsEx.au3>
#include <WindowsConstants.au3>
#include <ProgressConstants.au3>
#include <Misc.au3>

_Singleton('Automation test server')

HotKeySet("!{Esc}", "HotKeyPressed") ; Alt-Esc to stop testing

TCPStartup() ; Start the TCP service.
AutoItSetOption("TCPTimeout", 5)

Global Const $maxConnections = 20	; define the max client numbers
Global Const $maxListen = 100	; define the max client numbers
Global Const $automationLogPort = $maxConnections + 1 ;define the automation log port
Global Const $maxSendLength = 100000	; set maximum legth of bytes that a TCPsend command may send
Global Const $maxLoopTime = 1000; set the max time in miliseconds every loop may take
Global $totalConnection = 0
Global $commandID = 0
Local $ipServer = @IPAddress1
Local $port = 16869
Global $ipRaspberryPi1 = TCPNameToIP("10.0.9.199")
Global $ipRaspberryPi2 = TCPNameToIP("10.0.9.198")
Local $portRaspberryPi = 8080
Global $socketRaspberryPi1 = -1
Global $socketRaspberryPi2 = -1
Global $piCommandHold = False
Global $piHeartbeatTime = 0
Global $piHeartbeatInterval = 30 * 1000
Global $workDir = "C:\CopTraxTest\"
Global $sentPattern = ""
Global $config = "FactoryDefault"
Global $InproperID = False	; Keep the record of inproper box ID
Local $cheatSheet = ReadCheatSheet()

OnAutoItExitRegister("OnAutoItExit")	; Register OnAutoItExit to be called when the script is closed.
Global $TCPListen = TCPListen ($ipServer, $port, $maxListen)

Global $currentTestCaseFile = $workDir & $config & ".txt"
Global Const $maxCommands = 38
Global $allCommands[$maxCommands]	; this section defines the supported test commands
$allCommands[0] = "record duration interval"
$allCommands[1] = "settings pre chunk cam2 cam3 keyboard"
$allCommands[2] = "createprofile username password"
$allCommands[3] = "checkrecord total newadd detailed"
$allCommands[4] = "upload file"
$allCommands[5] = "update file"
$allCommands[6] = "checkapp version"
$allCommands[7] = "checkfirmware version"
$allCommands[8] = "checklibrary version"
$allCommands[9] = "batchtest mode"
$allCommands[10] = "pause duration"
$allCommands[11] = "lightbar duration"
$allCommands[12] = "siren duration"
$allCommands[13] = "aux4 duration"
$allCommands[14] = "aux5 duration"
$allCommands[15] = "aux6 duration"
$allCommands[16] = "lightswitch duration"
$allCommands[17] = "mic1trigger duration"
$allCommands[18] = "mic2trigger duration"
$allCommands[19] = "endrecord duration"
$allCommands[20] = "startrecord duration"
$allCommands[21] = "runapp"
$allCommands[22] = "stopapp"
$allCommands[23] = "configure ct release bwc"
$allCommands[24] = "info"
$allCommands[25] = "camera"
$allCommands[26] = "review"
$allCommands[27] = "synctime"
$allCommands[28] = "synctmz"
$allCommands[29] = "radar"
$allCommands[30] = "status"
$allCommands[31] = "photo"
$allCommands[32] = "onfailure command"
$allCommands[33] = "about"
$allCommands[34] = "restarttest"
$allCommands[35] = "quittest"
$allCommands[36] = "reboot"
$allCommands[37] = "cleanup"

; This section defines the required parameters for automation test for each UUT
Global $sockets[$maxConnections + 1]	; the socket for each UUT
Global $logFiles[$maxConnections + 3]	; the handler of log file for each UUT
Global $logContent[$maxConnections + 1]	; the simplified content of log file for each UUT
Global $commands[$maxConnections + 1]	; the testcase for each UUT
Global $commandTimers[$maxConnections + 1]	; the command timer for each UUT; when reaches, next test command shall be started
Global $connectionTimers[$maxConnections + 1]	; the TCP connection timer for each UUT;  when reaches, TCP connection to that UUT may have lost
Global $filesReceived[$maxConnections + 1]	; stores the file handler of files that need to be upload to server from that UUT
Global $byteCounter[$maxConnections + 1]	; counter of bytes that need to receive from UUT for the upload file
Global $fileToBeSent[$maxConnections + 1]	; file handler of files that need to download to UUT
Global $heartBeatTimers[$maxConnections + 1]	; timer of heartbeat for each UUT; when reaches, the server need to send a heartbeat command to that UUT
Global $pGUI[$maxConnections + 1]	; the control ID of the progressbar for that UUT
Global $nGUI[$maxConnections + 1]	; the control ID of the timer for that UUT
Global $bGUI[$maxConnections + 1]	; the control ID of the button for that UUT, the name(serial number) is displayed on the button
Global $totalCommands[$maxConnections + 1]	; the counter of the total test commands in the test case for each UUT
Global $testEndTime[$maxConnections + 1]	; stores the end time estimation for each UUT
Global $remainTestTime[$maxConnections + 1]	; stores the remain time estimation in seconds for each UUT
Global $testFailures[$maxConnections + 1]	; stores the number of failures in automation test for each UUT
Global $boxID[$maxConnections + 1]	; stores the serial number of each UUT
Global $boxIP[$maxConnections + 1]	; stores the IP address of each UUT during the automation test
Global $batchWait[$maxConnections + 1]	; stores the batch mode of each test during the automation test. True means not to hold other box entering batch align mode
Global $errorsFirmware[$maxConnections + 1]	; stores the errors of event logs during the automation test. If the errors exceeds 10,reboot
Global $listFailed = ""	; the list of UUT's serial number that failed the automation test
Global $listPassed = "" ; the list of UUT's serial number that passed the automation test
Global $portDisplay = 0	; stores the index of UUT which log is displayed in the window

Local $i
For $i = 0 To $maxConnections	; initialize the variables
	$sockets[$i] = -1	; Stores the sockets for each client
	$connectionTimers[$i] = 0
	$commandTimers[$i] = 0
	$heartBeatTimers[$i] = 0
	$remainTestTime[$i] = 0
	$filesReceived[$i] = 0
	$logFiles[$i] = 0
	$fileToBeSent[$i] = ""
	$boxIP[$i] = ""
	$logContent[$i] = $cheatSheet
	$batchWait[$i] = True	; default value is true, not to hold other box entering batch align mode
	$errorsFirmware[$i] = 0
Next

XPStyleToggle(1)	; force not in XP mode, necessary for color change in progress bar
Global $connectionPattern = ""	; stores the pattern of UUT connections. "o" means not connected; "x" means connected but not ready for trigger; "+" means connected and ready for trigger
Global $hMainWindow = GUICreate("Automation Server Version " & FileGetVersion ( @ScriptFullPath ) & " @ " & $ipServer & ":" & $port, 480*3, 360*2)	; the main display window
Global $cLog = GUICtrlCreateEdit("Automation test results", 240, 350, 960, 360, $WS_VSCROLL)	; the child window that displays the log of each UUT
GUICtrlSendMsg($cLog, $EM_LIMITTEXT, -1, 0)
WinMove($hMainWindow, "", 240, 180)

For $i = 1 To $maxConnections
	Local $x0 = ($i - Floor($i / 2) * 2) * 960
	Local $y0 = 10 + Floor($i / 2 - 0.5) * 30
	$pGUI[$i] = GUICtrlCreateProgress($x0 + 125, $y0, 350, 20)
	$nGUI[$i] =	GUICtrlCreateLabel("        ", 80 + $x0, 3 + $y0, 5*9, 20)
	$bGUI[$i] =	GUICtrlCreateButton($boxID[$i], 5 + $x0, $y0, 8*9, 20)
	GUICtrlSetFont($bGUI[$i], 10, 700, 0, "Courier New")
	GUICtrlSetBkColor($bGUI[$i], $COLOR_SKYBLUE)
Next
Local $cID
$cID = GUICtrlCreateLabel("PASSED", 60, 320, 170, 20)	; label of passed list
GUICtrlSetFont($cID, 12, 400, 0, "Courier New")
$cID = GUICtrlCreateLabel("FAILED", 1200+60, 320, 170, 20)	; label of failed list
GUICtrlSetFont($cID, 12, 400, 0, "Courier New")

$cID = GUICtrlCreateLabel("Time remains", 700, 10, 120, 20)	; label of main timer's name
$nGUI[0] = GUICtrlCreateLabel("00:00:00", 700 + 130, 10, 81, 18)	; label of the main timer
Global $aLog = GUICtrlCreateEdit("Automation Progress", 480, 35, 475, 300, $WS_VSCROLL)	; the child window that displays the automation log
Global $idComboBox = GUICtrlCreateCombo($config, 700-200, 5, 180, 20)
GUICtrlSetFont($idComboBox, 10, 700, 0, "Courier New")
GUICtrlSetColor($nGUI[0], $COLOR_GREEN)	; set the main timer in color green
GUICtrlSetFont($nGUI[0], 12, 400, 0, "Courier New")
Global $comboList = ""
UpdateConfigCombo($idComboBox)

GUICtrlSetFont($aLog, 10, 400, 0, "Courier New")
GUICtrlSetFont($cLog, 10, 400, 0, "Courier New")
GUICtrlSetFont($cID, 12, 400, 0, "Courier New")
$cID = GUICtrlCreateLabel($connectionPattern, 1200 + 40, 700, 160, 20)	; label of connection pattern
GUICtrlSetFont($cID, 10, 400, 0, "Courier New")
Global $tLog = GUICtrlCreateLabel("CheatSheet", 250, 330, 100, 18)	; label of UUT's serial number which log is displayed
GUICtrlSetFont($tLog, 12, 700, 0, "Courier New")
GUICtrlSetBkColor($tLog, $COLOR_SKYBLUE)	; set the color of the lable the same as the buttons
Local $cLoop = GUICtrlCreateLabel("00:00:00", 40, 700, 60, 15)	; label of connection pattern

$hListPassed = GUICtrlCreateLabel( $listPassed, 5, 350, 230, 350 )	; the label of the passed list
GUICtrlSetColor($hListPassed, $COLOR_GREEN)
$hListFailed = GUICtrlCreateLabel( $listFailed, 1200 + 5, 350, 230, 350 )	; the label of the failed list
GUICtrlSetColor($hListFailed, $COLOR_RED)
GUISetState(@SW_SHOW)

; the window $automationLogPort will display the main test result
$logFiles[$automationLogPort] =FileOpen($workDir & "log\automationtest.log", 1+8) 	; the automation log file
LogWrite($automationLogPort, "")
LogWrite($automationLogPort, "A new batch of automation test starts.")
LogWrite($automationLogPort, "Current setting of configuration for burn-in is " & $config & ".")
GUICtrlSetData($cLog, $cheatSheet)

Global $hTimer = TimerInit()	; global timer handle
Global $testEnd = False
Global $batchAligned = False
Global $batchMode = False	; Not in batch mode until get a batch align command
Local $commandsRemains
Local $timeRemains
Local $progressPercentage
Local $lastEndTime = 0
Local $batchCheck = False
Local $tempTime
Local $tempPattern
Local $Recv
Local $estimate
Global $time0
Local $msg
Local $tLoop = ""
Local $file
Local $nextCommand
While Not $testEnd	; main loop that get input, display the resilts
	$time0 = Int(TimerDiff($hTimer))	; get current timer elaspe
	AcceptConnection()	; accept new client's connection requist

	If $batchMode Then
		If $socketRaspberryPi1 > 0 Then
			$Recv = TCPRecv($socketRaspberryPi1, 100)	; when connected, try to receive message
			If $Recv <> "" Then
				LogWrite($automationLogPort, "(Raspberry Pi1) Replied " & $Recv )
				TCPCloseSocket($socketRaspberryPi1)
				$socketRaspberryPi1 = -1
			EndIf
		EndIf

		If $socketRaspberryPi2 > 0 Then
			$Recv = TCPRecv($socketRaspberryPi2,100)	; when connected, try to receive message
			If $Recv <> "" Then
				LogWrite($automationLogPort, "(Raspberry Pi2) Replied " & $Recv )
				TCPCloseSocket($socketRaspberryPi2)
				$socketRaspberryPi2 = -1
			EndIf
		EndIf

		If $time0 > $piHeartbeatTime Then
			$piCommandHold = False
		EndIf
	EndIf

	$batchCheck = ($totalConnection > 0)
	$totalConnection = 0
	$tempPattern = ""
	$lastEndTime = 0
	For $i = 1 To $maxConnections
		If $connectionTimers[$i] And ($time0 > $connectionTimers[$i]) Then	; test if the client is alive
			LogWrite($i, "(Server) No reply from the client. Connection to client lost.")
			$connectionTimers[$i] = 0;
			CloseConnection($i)
			GUICtrlSetData($nGUI[$i], "LOST")	; show interrupt message
			ContinueLoop
		EndIf
		$totalConnection += 1

		If $sockets[$i] <= 0 Then ContinueLoop

		If ProcessReply($i) Then
			$connectionTimers[$i] = $time0 + 1000*60 ; renew the connection check timer
		EndIf

		$timeRemains = CorrectRange(Round(($testEndTime[$i] - $time0) / 1000), 0, 24*3600)
		If $timeRemains <> $remainTestTime[$i]	Then
			$remainTestTime[$i] = $timeRemains
			GUICtrlSetData($nGUI[$i], toHMS($timeRemains))
		EndIf

		If Not $batchWait[$i] Then	; If there is one not aligned
			$batchCheck = False
		EndIf

		If $timeRemains > $lastEndTime Then
			$lastEndTime = $timeRemains
		Endif
	Next

	$batchAligned = $batchCheck	; Aligned only when there are UUT connected
	If $tempTime <> $lastEndTime Then
		GUICtrlSetData($nGUI[0], toHMS($lastEndTime))
		$tempTime = $lastEndTime
	EndIf

	$testEnd = ProcessMSG()

	$tempPattern = Int(TimerDiff($hTimer) - $time0)
	If $tempPattern > $maxLoopTime Then
		LogWrite($automationLogPort, "Loop time is " & $tempPattern & "ms. It is too long. Consider to restart the server.")
	EndIf
	$tempPattern = tobar($tempPattern)

	If $tLoop <> $tempPattern Then
		$tLoop = $tempPattern
		GUICtrlSetData($cLoop, $tLoop)
	EndIf
WEnd

OnAutoItExit()

Exit

Func ProcessMSG()
	Local $i
	Local $msg = GUIGetMsg()
	If Not $msg Then Return False

	UpdateConfigCombo($idComboBox)	; check and update the combo list

	If $msg = $GUI_EVENT_CLOSE Then
		LogWrite($automationLogPort, "Automation test end by operator.")
		LogWrite($automationLogPort, "")
		Return True
	EndIf

	For $i = 1 To $maxConnections
		If $msg = $bGUI[$i] Then
			$portDisplay = $i	; update the log display for that button
			If $boxID[$i] Then
				GUICtrlSetData($tLog, " " & $boxID[$i])
			Else
				GUICtrlSetData($tLog, "CheatSheet")
			EndIf
			GUICtrlSetData($cLog, $logContent[$i])
			ExitLoop
		EndIf
	Next

	If $msg = $idComboBox Then
		$config = GUICtrlRead($idComboBox)
		$currentTestCaseFile = $workdir & $config & ".txt"
		LogWrite($automationLogPort, "Change the configure to " & $config & ".")
	EndIf

	Return False
EndFunc

Func UpdateConfigCombo($id)
	Local $fileList = _FileListToArray($workDir,"*.mcfg", 1)	; list *.config files in ..\latest folder
	$fileList = StringRegExpReplace(_ArrayToString($fileList), "(\.mcfg)", "")
	$fileList = StringRegExpReplace($fileList, "(^[0-9].)", "")
	If $fileList <> $comboList Then
		$comboList = $fileList
		GUICtrlSetData($id, "|" & $fileList, $config)
	EndIf
EndFunc

Func toBar($x)
	Local $rst= ""
	Local $i
	Local $j = Floor($x / 1000)
	For $i = 1 To $j
		$rst &= "#"
	Next

	$x -= $j * 1000
	$j = Floor($x / 100)
	For $i = 1 To $j
		$rst &= "="
	Next

	$x -= $j * 100
	$j = Floor($x / 10)
	For $i = 1 To $j
		$rst &= "-"
	Next

	$x -= $j * 10
	$j = Floor($x)
	For $i = 1 To $j
		$rst &= "."
	Next

	Return $rst
EndFunc

Func ReadCheatSheet()
	Local $file = FileOpen($workDir & "CheatSheet.txt")
	If @error < 0 Then
		Return "Cannot find CheatSheet.txt at " & $workDir
	EndIf

	Local $fileContent = FileRead($file)
	FileClose($file)
	Return $fileContent
EndFunc

Func UpdateLists($passed, $failed)
	If $passed <> "" Then
		$listFailed = StringRegExpReplace( $listFailed, $passed & "; ", "" )
		$listPassed = StringRegExpReplace( $listPassed, $passed & "; ", "" )
		$listPassed &= $passed & "; "
	EndIf

	If $failed <> "" Then
		$listPassed = StringRegExpReplace( $listPassed, $failed & "; ", "" )
		$listFailed = StringRegExpReplace( $listFailed, $failed & "; ", "" )
		$listFailed &= $failed & "; "
	EndIf

	GUICtrlSetData( $hListPassed, $listPassed )
	GUICtrlSetData( $hListFailed, $listFailed )
EndFunc

Func CloseConnection($n)
	If $sockets[$n] > 0 Then TCPCloseSocket($sockets[$n])	; Close the TCP connection to the client
	$sockets[$n] = -1	; clear the soket index
	If $filesReceived[$n] Then
		FileClose($filesReceived[$n])
		$filesReceived[$n] = 0
	EndIf
EndFunc

Func ParseCommand($n)
	If $filesReceived[$n] Then	; This indicates there exists file uploading, do not send new command until it ends
		$testEndTime[$n] += 5
		$commandTimers[$n] +=  5*1000 ; add 5 seconds for next command to be executed
		Return False
	EndIf

	Local $arg = EstimateCommands($commands[$n]) ;
	Local $count = Int(GetParameter($estimate, "count"))	; number of commands remains
	Local $duration = Int(GetParameter($estimate, "time"))	; time remains in seconds
	Local $newCommand = PopCommand($n)
	Local $interval
	Local $IP
	$testEndTime[$n] = $time0 + $duration * 1000 ; time that the test will end in milliseconds

	If $newCommand = "" Then 	; no command left to be precessed
		SendCommand($n, "quittest")
		Return
	EndIf

	If Not ($newCommand = "send" Or $newCommand = "batchhold") Then
		LogWrite($n, "")
		LogWrite($n, "Number of test Commands : " & $count & ". Estimated test time remains " & toHMS($duration))
	EndIf

	Switch $newCommand	; process the new command
		Case "record"
			$arg = PopCommand($n)
			LogWrite($n, "(Server) Read " & $newCommand & " " & $arg & " command.")
			$duration = CorrectRange(Int(GetParameter($arg, "duration")), 1, 999)
			$interval = Int(GetParameter($arg, "interval"))
			If $interval < 1 Or $interval > 10 Then $interval = 10

			PushCommand($n, "endrecord " & $interval)
			$newCommand = "startrecord " & $duration * 60
			SendCommand($n, $newCommand)
			LogWrite($n, "(Server) Sent " & $newCommand & " command to client. The endrecord command will be sent in " & $duration & " mins.")

		Case "endrecord"
			$arg = PopCommand($n)
			LogWrite($n, "(Server) Read " & $newCommand & " " & $arg & " command.")
			$newCommand = "endrecord " & Int($arg)*60
			SendCommand($n, $newCommand)	; send new test command to client
			LogWrite($n, "(Server) Sent " & $newCommand & " command to client. Next command is in " & $arg & " mins.")

		Case "settings", "createprofile", "upload", "checkfirmware", "checkapp", "checklibrary", "checkrecord", "pause", "configure"
			$arg = PopCommand($n)
			LogWrite($n, "(Server) Read " & $newCommand & " " & $arg & " command.")
			$newCommand = StringInStr($newCommand, "pause") ? $newCommand & " " & $arg : $newCommand & " " & Int($arg) * 60
			LogWrite($n, "(Server) Sent " & $newCommand & " command to client.")
			SendCommand($n, $newCommand)	; send new test command to client

			If StringInStr($newCommand, "config") Then
				Local $filename = $boxID[$n] & ".txt"
				Local $file = FileOpen($workdir & "latest\" & $filename, 2)
				_FileWriteLog($file, "This box is configured according to " & $currentTestCaseFile & ", where the configuration is " & $arg )
				FileClose($file)

				PushCommand($n, "update C:\Users\coptraxadmin\Desktop\Utilities\" & $filename )
			EndIf

		Case "siren", "lightbar", "aux4", "aux5", "aux6", "lightswitch", "mic1trigger", "mic2trigger"
			If $socketRaspberryPi1 <= 0 Then
				$socketRaspberryPi1 = TCPConnect($ipRaspberryPi1, $portRaspberryPi)	; When RSP1 not connected, try to connect it
			EndIf
			If $socketRaspberryPi2 <= 0 Then
				$socketRaspberryPi2 = TCPConnect($ipRaspberryPi2, $portRaspberryPi)	; When RSP2 not connected, try to connect it
			EndIf

			$arg = PopCommand($n)
			LogWrite($n, "(Server) Read " & $newCommand & " " & $arg & " command.")

			$duration = CorrectRange(Int($arg), 1, 60)
			Local $aCommand = "trigger " & Int($arg) * 60
			Local $piCommand = "t1"
			If $newCommand = "siren" Then $piCommand = "t1"
			If $newCommand = "lightbar" Then $piCommand = "t3"
			If $newCommand = "aux4" Then $piCommand = "t4"
			If $newCommand = "aux5" Then $piCommand = "t5"
			If $newCommand = "aux6" Then $piCommand = "t6"
			If $newCommand = "mic1trigger" Then $piCommand = "m1"
			If $newCommand = "mic2trigger" Then $piCommand = "m2"
			If $newCommand = "lightswitch" Then
				$piCommand = "t7"
				$aCommand = "lightswitch " & Int($arg) * 60
			Endif

			SendCommand(0, $piCommand)  ; send pi its command
			SendCommand($n, $aCommand)    ; send new test command to client
			LogWrite($n, "(Server) Sent " & $aCommand & " command to client. Sent " & $piCommand & " command to Raspberry Pi.")
			$batchWait[$n] = False	; enter batchtest stop mode, stops any other box from entering aligned mode

		Case "review", "photo", "info", "status", "radar", "stopapp", "runapp", "camera", "about", "quit", "reboot", "endtest", "quittest", "restart", "restarttest", "cleanup"
			SendCommand($n, $newCommand)	; send new test command to client
			LogWrite($n, "(Server) Read " & $newCommand & " command.")
			LogWrite($n, "(Server) Sent " & $newCommand & " command to client.")

		Case "onfailure"
			$arg = PopCommand($n)
			LogWrite($n, "(Server) Read " & $newCommand & " " & $arg & " command. Checking for any failures so far.")
			If $testFailures[$n] > 0 Then
				$commands[$n] = ""	; clear the command queue when there are failures

				If StringInStr($arg, "start") Then
					PushCommand($n, "upload all restart")
					LogWrite($n, "(Server) Change the rest test commands to 'upload all restart' because there are " & $testFailures[$n] & " failures in this test.")
				EndIf

				If StringInStr($arg, "quit") Then
					PushCommand($n, "upload all quit")
					LogWrite($n, "(Server) Change the rest test commands to 'upload all quit'  because there are " & $testFailures[$n] & " failures in this test.")
				EndIf

				If StringInStr($arg, "boot") Then
					PushCommand($n, "upload all reboot")
					LogWrite($n, "(Server) Change the rest test commands to 'upload all reboot' because there are " & $testFailures[$n] & " failures in this test.")
				EndIf
			Else
				LogWrite($n, "(Server) There is no failure in the test so far.")
			EndIf
			SendCommand($n, "pause 5")
			LogWrite($n, "(Server) Sent pause 5 command to client. Next command will be read in 5 seconds")

		Case "synctime"
			$arg = @YEAR & @MON & @MDAY & @HOUR & @MIN & @SEC
			SendCommand($n, $newCommand & " " & $arg)	; send new test command to client
			LogWrite($n, "(Server) Read " & $newCommand & " command.")
			LogWrite($n, "(Server) Sent " & $newCommand & " " & $arg & " command to client.")

		Case "synctmz"
			Local $tmzarg = _Date_Time_GetTimeZoneInformation ( )
			$arg = $tmzarg[2]
			SendCommand($n, $newCommand & " " & $arg)	; send new test command to client
			LogWrite($n, "(Server) Read " & $newCommand & " command.")
			LogWrite($n, "(Server) Sent " & $newCommand & " " & $arg & " command to client.")

		Case "update"
			Local $fileName = PopCommand($n)
			Local $file
			Local $netFileName
			Local $sourceFileName
			LogWrite($n, "(Server) Read " & $newCommand & " " & $fileName & " command.")

			If StringInStr($filename, "\") Then
				$netFileName = StringSplit($fileName, "\")
				$sourceFileName = $workDir & "latest\" & $netFileName[$netFileName[0]]    ; all file need to be update shall sit in \latest folder
			Else
				$sourceFileName = $workDir & "latest\" & $fileName
			Endif
			$sourceFileName = StringReplace($sourceFileName, "|", " ")

			$file = FileOpen($sourceFileName,16)	; open file for read only in binary mode
			$fileToBeSent[$n] = FileRead($file)
			FileClose($file)
			Local $fLen = BinaryLen($fileToBeSent[$n])
			$newCommand = "update " & $fileName & " " & $fLen
			SendCommand($n, $newCommand)	; send new test command to client
			LogWrite($n, "(Server) Sent " & $newCommand & " command to client.")
			LogWrite($n, "(Server) Sending " & $sourceFileName & " in server to update " & $fileName & " in client.")
			PushCommand($n, "send")	; hold any new command from executing only after get a continue response from the client

		Case "send"
			SendCommand($n, $fileToBeSent[$n])	; send file to client
			LogWrite($n,"(Server) File sent to client in chunks " & $sentPattern & ".")

		Case "batchhold"
			If $batchAligned Then
				LogWrite($n, "(Server) All clients aligned.")
				$piCommandHold = False
			Else
				PushCommand($n, "batchhold")	; the batchhold command can only be cleared by all active clients entering batch wait mode
			EndIf
			SendCommand($n, "pause 5")

		Case "batchtest"
			$arg = StringLower(PopCommand($n))
			LogWrite($n, "(Server) Read batchtest " & $arg & " command.")

			$IP =  StringInStr($arg, "10.0.") ? TCPNameToIP($arg) : ""
			If $IP Then
				LogWrite($n, "(Server) Select the Raspberry Pi simulator at " & $IP & " to do the triggers test.")
				LogWrite($automationLogPort, "(Server) Select the Raspberry Pi simulator at " & $IP & " to do the triggers test.")
				$ipRaspberryPi1 = $IP
				$ipRaspberryPi2 = @IPAddress1
			EndIf

			If $arg = "align" Then
				If $batchMode Then
					LogWrite($n, "(Server) PASSED. Wait till all other clients aligned.")
					LogWrite($automationLogPort, "(Server) " & $boxID[$i] & " aligned.")
					PushCommand($n, "batchhold")
					$batchWait[$n] = True	; indicates client $n in batch wait mode now
				Else
					LogWrite($n, "(Server) FAILED. In batchtest stop mode, cannot achieve align.")
				EndIf
			EndIf

			If $arg = "start" Then
				LogWrite($n, "(Server) Start batch test mode, hold other boxes from entering trigger test until all box aligned .")
				LogWrite($automationLogPort, "(Server) " & $boxID[$n] & " enter batch test mode.")
				$batchWait[$n] = False
				$batchMode = True
			EndIf

			If $arg = "stop" Then
				LogWrite($n, "(Server) Enter stop batch test mode, disabled all other later boxes from achieving align mode.")
				$batchWait[$n] = False
				If Not $batchMode Then Return

				$socketRaspberryPi1 = -1
				$socketRaspberryPi2 = -1
				$batchAligned = False
				$batchMode = False
			EndIf
			SendCommand($n, "pause 5")

		Case Else
			LogWrite($n, "(Server) Unknown command " & $newCommand & ". Commands in stack are " & $commands[$n])
			SendCommand($n, "pause 5")

	EndSwitch
EndFunc

Func LogWrite($n,$s)
	If $n <= 0 Or $n > $maxConnections + 1 Then Return

	_FileWriteLog($logFiles[$n],$s)
	If StringInStr($s, "error event") Then Return

	$s = @HOUR & ":" & @MIN & ":" & @SEC & " " & $s & @CRLF	; show the log with time stamps

	If $n = $automationLogPort Then
		GUICtrlSetData($aLog, $s, 1)
		Return
	EndIf

	If Not ( StringInStr($s, "heartbeat command") Or StringInStr($s, "; CPU #", 1) )  Then
		$logContent[$n] &= $s
	EndIf

	If $n = $portDisplay Then
		GUICtrlSetData($cLog, $s, 1)	; update the log display in append mode
	EndIf
EndFunc

Func toHMS($time)
	Local $hms = ""
	Local $t = $time
	Local $h = Floor($t / 3600)
	If $h >= 10 Then
		$hms = $h & ":"
	Else
		$hms = "0" & $h & ":"
	Endif

	$t -= $h * 3600
	Local $m = Floor($t / 60)
	If $m >= 10 Then
		$hms &= $m & ":"
	Else
		$hms &= "0" & $m & ":"
	Endif

	Local $s = Round($t -$m * 60)
	If $s >= 10 Then
		$hms &= $s
	Else
		$hms &= "0" & $s
	Endif

	Return $hms
EndFunc

Func ReadTestCase($fileName)
	Local $testFile = FileOpen($fileName,0)    ; for test case reading, read only
	Local $aLine
	Local $aCommand = ""
	Local $testCase = ""
	Local $eof = false
	Local $endofTestCase = ""
	Local $i
	For $i = $maxCommands - 4 To $maxCommands - 1	; last 4 commands
		$endofTestCase &= $allCommands[$i]
	Next

	Do
		$aLine = FileReadLine($testFile)
		If @error < 0 Then ExitLoop

		$aLine = StringRegExpReplace($aLine, "(;.*)", "")
		$aLine = StringRegExpReplace($aLine, "(//.*)", "")
		If $aLine = "" Then ContinueLoop

		$aCommand = ReadCommand($aLine)
		If $aCommand = "" Then ContinueLoop

		$parameters = ReadParameters($aLine, $aCommand)
		If $parameters = "" Then
			$testCase &= $aCommand & " "
		Else
			$testCase &= $aCommand & " " & $parameters & " "
		EndIf

		If StringInStr($endofTestCase, $aCommand) Then
			ExitLoop
		EndIf
	Until $eof

	FileClose($testFile)
	Return $testCase
EndFunc

Func EstimateCommands($aCommand)
	If $aCommand = "" Then Return "count=0 time=0"
	Local $commandList = StringSplit($aCommand, " ")
	If @error Then Return "count=1 time=20"

	Local $count = 0
	Local $duration = 1
	Local $interval = 10
	Local $parameters = ""
	Local $testTime = 0
	Local $i
	Local $j

	For $i = 1 To $commandList[0] - 1	; there is a space in the end
		For $j = 0 To $maxCommands - 1
			If StringInStr($allCommands[$j], $commandList[$i]) = 1 Then ; find match only at the beginning
				$count += 1
				ExitLoop
			EndIf
		Next

		If $j >= $maxCommands Then ContinueLoop

		If $j = 0 Then  ; record
			$parameters = $commandList[$i+1]
			$duration = CorrectRange(Int(GetParameter($parameters, "duration")), 1, 999)
			$interval = Int(GetParameter($parameters, "interval"))
			If $interval < 1 Or $interval > 10 Then $interval = 10
			$count += 1
			$testTime += ($duration + $interval) * 60
		ElseIf StringInStr($allCommands[$j], "duration") > 4 Then
			$parameters = $commandList[$i+1]
			$duration = CorrectRange(Int(GetParameter($parameters, "duration")), 1, 9999)
			If StringInStr($allCommands[$j], "pause") Then	; pause in seconds instead of minutes now
				$testTime += $duration
			Else
				$testTime += $duration * 60
			EndIf
		Else
			$testTime += 20
        Endif

		If StringLen( $allCommands[$j] ) > StringLen ($commandList[$i]) Then
			$i += 1
		EndIf
    Next

    Return "count=" & $count & " time=" & $testTime
EndFunc

Func CorrectRange($num, $lowerBand = 1, $upperBand = 999)
	If $num < $lowerBand Then Return $lowerBand
	If $num > $upperBand Then Return $upperBand
	Return $num
EndFunc

Func ReadCommand($line)
	Local $readTxt = StringRegExp($line, "(?:^\s*)([a-zA-Z][a-zA-Z0-9]+)", $STR_REGEXPARRAYMATCH)
	If $readTxt = "" Then Return ""
	Local $readCommand = StringLower($readTxt[0])
	Local $i
	For $i = 0 To $maxCommands-1
		If StringInStr($allCommands[$i], $readCommand) Then Return $readCommand
	Next
	Return ""
EndFunc

Func ReadParameters($line, $aCommand)
	Local $i
	For $i = 0 To $maxCommands-1
		If StringInStr($allCommands[$i], $aCommand) Then ExitLoop
	Next

	Local $keywords = StringSplit($allCommands[$i], " ") ; split the keywords command keyword1 keyword2
	Local $parameter
	If $keywords[0] <= 1 Then Return ""	; no keywords so no parameters
	If $keywords[0] = 2 Then ; only 1 parameter, try to eliminate the keyword
		$parameter = StringRegExp($line, "(?i)(?:" & $acommand & "\s+)(.[^\s]*)", $STR_REGEXPARRAYMATCH)
		If Not IsArray($parameter) Then Return "NULL"
		If StringInStr($parameter[0], "=") Then
			Return StringRegExpReplace($parameter[0], "(" & $keywords[2] & "=)", "")
		Else
			Return $parameter[0]
		EndIf
	EndIf

	Local $parameters = ""
	For $i = 2 To $keywords[0]
		$parameter = StringRegExp($line, "(?i)(?:\s)(" & $keywords[$i] & "=.[^\s]*)", $STR_REGEXPARRAYMATCH)
		If IsArray($parameter) Then
			$parameters &= StringRegExpReplace($parameter[0], "(?i)" & $keywords[$i] & "=", $keywords[$i] & "=") & "|"
		EndIf
	Next

	If $parameters = "" Then
		Return "NULL"
	Else
		Return StringRegExpReplace($parameters, "\|$", "")	; eliminate the last | from the parameters
	EndIf
EndFunc

Func GetParameter($parameters, $keyword)
	If StringInStr($parameters, "=") Then
		Local $parameter = StringRegExp($parameters, "(?i)(?:" & $keyword & "=)(.[^\s]*)", $STR_REGEXPARRAYMATCH)
		If IsArray($parameter) Then
			Return StringReplace($parameter[0], "|", "\!")	; replace | with \!
		Else
			Return ""
		EndIf
	Else
		Return $parameters
	EndIf
EndFunc

Func ProcessReply($n)
	Local $reply
	Local $len
	Local $err

	If $sockets[$n] <= 0 Then Return False

	If $filesReceived[$n] Then	; This indicates the coming message shall be saved in file
		$reply = TCPRecv($sockets[$n], 1000000, 1)	; receives in binary mode using longer length
		$err = @error
		If $err <> 0 Then
			LogWrite($n, "(Server) Connection lost with error : " & $err)
			LogWrite($automationLogPort, "(Server) " & $boxID[$n] & " connection lost with error : " & $err)
			FileClose($filesReceived[$n])	; get and save the file
			$filesReceived[$n] = 0	;clear the flag when file transfer ends
			CloseConnection($n)
			Return False
		EndIf

		$len = BinaryLen($reply)
		If $len = 0 Then Return False	; receives nothing

		FileWrite($filesReceived[$n], $reply)
		$byteCounter[$n] -= BinaryLen($reply)
		LogWrite($n, "(Server) Received " & BinaryLen($reply) & " bytes, " & $byteCounter[$n] & " bytes remains.")

		If $byteCounter[$n] < 5 Then
			FileClose($filesReceived[$n])	; get and save the file
			$filesReceived[$n] = 0	;clear the flag when file transfer ends
			SendCommand($n, "eof")	; send "eof" command to client
			LogWrite($n,"(Server) Send 'eof' command to client.")
		EndIf

		Return True
	EndIf

	$reply = TCPRecv($sockets[$n], 1000)    ; receive in text mode using short length
	$err = @error
	If $err <> 0 Then
		LogWrite($n, "(Server) Connection lost with error : " & $err)
		LogWrite($automationLogPort, "(Server) " & $boxID[$n] & " connection lost with error : " & $err)
		CloseConnection($n)
		Return False
	EndIf
	$len = BinaryLen($reply)
	If $len = 0 Then Return False   ; receive nothing, return false

	If IsBinary($reply) Then
		LogWrite($n, "(Server) Received unsaved upload file content with " & $len & " bytes.")
		CloseConnection($n)
		Return True
	EndIf

	Local $newCommand
	Local $msg = StringSplit($reply, " ")
	Local $readTxt
	LogWrite($n, "(Client) " & $reply)	; write the returned results into the log file

	If ($msg[0] >= 5) And StringInStr($reply, "Identify ", 1) Then	; the settings reply the identify ID
		$readTxt =  StringRegExp($reply, "([a-zA-Z]{2}[0-9]{6})", $STR_REGEXPARRAYMATCH)
		If IsArray($readTxt) And ($readTxt[0] <> $boxID[$n]) Then
			$ID = $readTxt[0]
			LogWrite($n, "(Server) Got the box serial number updated from " & $boxID[$n] & " to " & $readTxt[0] & ". Have to update the log file.")
			$boxID[$n] = $readTxt[0]	; update the box ID
			$portDisplay = $n	; update the main log display to current box
			GUICtrlSetData($bGUI[$n], $boxID[$n])	; update the text on the button
			GUICtrlSetData($tLog, " " & $boxID[$n])	; update the serial number on top the main log display

			FileClose($logFiles[$n])
			$logFiles[$n] = FileOpen($workDir & "log\" & $boxID[$n] & ".log", 1+8) ; open log file for append write in text mode
			FileWrite($logFiles[$n], $logContent[$n])	; write the previouse log content into new log file
			$InproperID = False	; clear the flag
		EndIf

		CloseConnection($n)	; not to listen to the socket any more, let the client to close the socket after it got the commands
		Return True
	EndIf

	If ($msg[1] = "file") Then	; start to upload file from client
		Local $filename = $msg[2]
		Local $len =  Int($msg[3])
		Local $netFileName = StringSplit($filename, "\")
		Local $destFileName = $workDir & "ClientFiles\" & $netFileName[$netFileName[0]]
		LogWrite($n, "(Server) " & $filename & " from client is going to be saved as " & $destFileName & " in server.")
		LogWrite($n, "(Server) Total " & $len & " bytes need to be stransfered.")
		$filesReceived[$n] = FileOpen($destFileName,16+8+2)	; open file for over-write and create the directory structure if it doesn't exist
		$byteCounter[$n] = $len
		SendCommand($n, "send")	; send "send" command to client to trigger the file transfer
		LogWrite($n, "(Server) Sent 'send' command to client.")
		Return True
	EndIf

	If ($msg[0] >= 3) And ($msg[1] = "name") Then	; Start a new test when got name reply
		StartNewTest($n, $msg[2], $msg[3])
		ParseCommand($n)
		Return True
	EndIf

	If StringInStr($reply, "FAILED", 1) Then	; Got a FAILED reply,
		$testFailures[$n] += 1
		GUICtrlSetColor($pGUI[$n], $COLOR_RED)
		LogWrite($automationLogPort, $boxID[$n] & " " & $reply)
	EndIf

	If StringInStr($reply, "Fatal error.") Then
		$testFailures[$n] += 1
		GUICtrlSetColor($pGUI[$n], $COLOR_RED)

		PushCommand($n, "upload all reboot")	; seems there exists mis-matching problems in the client box, reboot to fix it
		LogWrite($automationLogPort, $boxID[$n] & " firmware reading error. Cannot read valid data from firmware.")
		LogWrite($n, "Firmware reading error. Cannot read valid data from firmware.")
	EndIf

	If StringInStr($reply, "App error") And Not StringInStr($reply, "(15 ms)") Then
		$errorsFirmware[$n] += 1
		If $errorsFirmware[$n] > 10 Then
			GUICtrlSetColor($pGUI[$n], $COLOR_RED)
			PushCommand($n, "upload all reboot")	; Send command reboot to client to force a reboot
			LogWrite($automationLogPort, $boxID[$n] & " firmware reading errors exceed 10 times. Have to reboot the box.")
			LogWrite($n, "Firmware reading errors exceeds 10. Cannot read valid data from firmware. Have to reboot the box.")
		EndIf
	EndIf

	If StringInStr($reply, "quit") Then
		If StringLen($commands[$n]) > 5 Then
			LogWrite($automationLogPort, $boxID[$n] & " Tests was interrupted.")
			LogWrite($n, "(Server) Tests was interrupted.")
			GUICtrlSetData($nGUI[$n], "interrupt")
		Else
			If StringInStr($boxID[$n], "DK") Then
				LogWrite($automationLogPort, $boxID[$n] & " is not a properly programmed serial number.")
				LogWrite($n, "(Server) " & $boxID[$n] & " is not a properly programmed serial number. The box need to be re-programmed.")
				$testFailures[$n] += 1	; initialize the result true until any failure
			EndIf

			If $testFailures[$n] = 0 Then
				LogWrite($n, "All tests passed.")
				LogWrite($automationLogPort, "All tests passed.")
				LogWrite($automationLogPort, "END AUTOMATION TEST for CopTrax DVR " & $boxID[$n])
				GUICtrlSetColor($pGUI[$n], $COLOR_GREEN)
				GUICtrlSetData($nGUI[$n], "PASSED")
				UpdateLists($boxID[$n], "")
			Else
				LogWrite($n, "Tests failed with " & $testFailures[$n] & " failures.")
				LogWrite($automationLogPort, "Tests failed with " & $testFailures[$n] & " failures.")
				LogWrite($automationLogPort, $boxID[$n] & " ALL TESTS DID NOT PASS.")
				GUICtrlSetData($nGUI[$n], "FAILED" )
				UpdateLists( "", $boxID[$n] )
			EndIf
			$testEndTime[$n] = 0
			$remainTestTime[$n] = 0
		EndIf

		GUICtrlSetState($nGui[$n], $GUI_SHOW)
		Local $s = "==================================="
		$s &= $s & $s
		LogWrite($n, $s)
		LogWrite($n, " ")

		CloseConnection($n)
		ClearCommands($n)
		Return True
	EndIf

	If StringInStr($reply, "Continue") Then
		SendCommand($n, "Continue")
		$sockets[$n] = -1	; not to listen to the socket any more, let the client to close the socket after it got the commands
		Return True
	EndIf

	If StringInStr($reply, "Request for new command.") Then
		ParseCommand($n)
		Return True
	EndIf

	CloseConnection($n)	; After receiving a report, close the connection
	Return True
EndFunc

Func ClearCommands($n)
	$filesReceived[$n] = 0	; clear the upload files
	$fileToBeSent[$n] = ""	; clear file need to be sent to client
	$testFailures[$n] = 0	; initialize the result true until any failure
	$batchWait[$n] = True	; Default is true, not to hold other boxes until was set by BatchTest mode=start
	$errorsFirmware[$n] = 0 ; clear the errors counter for event log
	If $logFiles[$n] Then FileClose($logFiles)
	$logFiles[$n] = 0 ; clear log file for append write in text mode
	$commands[$n] = ""
	$connectionTimers[$n] = 0
	$commandTimers[$n] = 0
	$heartBeatTimers[$n] = 0
	$remainTestTime[$n] = 0
EndFunc

Func StartNewTest($n, $ID, $clientVersion)
	ClearCommands($n)

	If Not StringRegExp($ID, "[A-Za-z]{2}[0-9]{6}")  Then
		LogWrite($n, "The Serial Number reported from the box " & $ID & " is invalid. Reboot the box now.")
		LogWrite($automationLogPort, $boxID[$n] & " firmware error. Cannot read serial number. Reboot now.")
		SendCommand($n, "0 reboot")
		Return
	EndIf
	$boxID[$n] = $ID	; get the boxID from client

	LogWrite($automationLogPort, $boxID[$n] & " connected on " & $boxIP[$n] & " at channel " & $n & ".")

	$portDisplay = $n
	GUICtrlSetData($bGUI[$n], $boxID[$n])	; update the text on the button
	GUICtrlSetData($tLog, " " & $boxID[$n])	; update the serial number on top the main log display

	If StringInStr($ID, "DK") Then
		If $InproperID Then ; Got DK123456 again
			$testFailures[$n] += 1
			GUICtrlSetColor($pGUI[$n], $COLOR_RED)
			GUICtrlSetData($pGUI[$n], 100)
			SendCommand($n, "0 reboot")
			LogWrite($automationLogPort, "Got inproper serial number " & $ID & " again. Let the box reboot now.")
			Return
		Else
			$InproperID = True
		EndIf
	EndIf

	Local $nextCommand
	Local $filename = $workDir & "log\" & $boxID[$n] & ".log"
	Local $splitChar = "==================================="
	Local $latestVersion = FileGetVersion($workDir & "latest\CopTraxAutomationClient.exe")

	$logFiles[$n] = FileOpen($filename, 1+8) ; open log file for append write in text mode
	$splitChar &= $splitChar & $splitChar
	LogWrite($n, " ")
	LogWrite($n, $splitChar)
	LogWrite($n, " Automation test for CopTrax DVR box " & $boxID[$n])
	LogWrite($n, " Current version of the test server : " & FileGetVersion ( @ScriptFullPath ))
	GUICtrlSetData($cLog, $logContent[$n])	; display and update the log content

	If _VersionCompare($clientVersion, $latestVersion) < 0 Then
		PushCommand($n, "update C:\CopTraxAutomation\tmp\CopTraxAutomationClient.exe restart")
		LogWrite($n, "Find latest automation tester in Server. Updating client to " & $latestVersion & ". Test will restart.")
		ParseCommand($n)
	Else
		LogWrite($n, "The latest automation test app version is " & $latestVersion & ". App in client is up-to-date.")
	EndIf

	$filename = $workdir & $boxID[$n] & ".txt"	; try to find if any individual test case exits
	If Not FileExists($filename) Then	; If there is no individual test case, try to read general test case.
		$filename = $currentTestCaseFile
	Endif
	$commands[$n] = ReadTestCase($filename)	; Read test case from file
	If $commands[$n] = "" Then
		LogWrite($n, "Cannot read test case from " & $filename & ". Assign a simple test case.")
		$filename = "Simple Test Case"
		PushCommand($n, "synctms synctime quittest")
	EndIf

	Local $commandsNumber = Int(GetParameter($estimate, "count"))
	Local $totalTestTime = toHMS(Int(GetParameter($estimate, "time")))

	GUICtrlSetData($pGUI[$n], 0)
	GUICtrlSetData($nGUI[$n], $totalTestTime)
	GUICtrlSetColor($nGUI[$n], $COLOR_BLACK)
	GUICtrlSetColor($pGUI[$n], $COLOR_SKYBLUE)

	LogWrite($n, " Test case is read from " & $filename)
	LogWrite($n, " - " & $commands[$n])
	LogWrite($n, " Number of test commands: " & $commandsNumber & ". Estimated test time is " & $totalTestTime & ".")
	LogWrite($n, $splitChar)

	LogWrite($automationLogPort, "START AUTOMATION TEST for CopTrax DVR " & $boxID[$n])
	LogWrite($automationLogPort, $boxID[$n] & " Number of test commands: " & $commandsNumber & ". Estimated test time is " & $totalTestTime & ".")
	$totalCommands[$n] = $commandsNumber
EndFunc

Func OnAutoItExit()
	If $socketRaspberryPi1 Then
		TCPCloseSocket($socketRaspberryPi1)
	EndIf
	If $socketRaspberryPi2 Then
		TCPCloseSocket($socketRaspberryPi2)
	EndIf

   Local $i
   For $i = 0 To $maxConnections
	  If $logFiles[$i] <> 0 Then
		 FileClose($logFiles[$i])
	  EndIf
   Next
EndFunc   ;==>OnAutoItExit

Func AcceptConnection ()
	If $totalConnection = $maxConnections Then Return	;Makes sure no more Connections can be made.
	Local $newSocket = TCPAccept($TCPListen)     ;Accepts incomming connections.
	If $newSocket < 0 Then Return

	Local $IP = SocketToIP($newSocket)
	Local $i = 0
	Local $port = 0
	Local $port0 = 0
	For $i = $maxConnections To 1 Step -1
		If $boxIP[$i] = $IP Then
			LogWrite($automationLogPort, "Resumed connection at " & $IP & " on channel " & $i & ".")
			If $sockets[$i] > 0 Then
				LogWrite($automationLogPort, "Clear the current socket " & $sockets[$i] & " and replace it with " & $newSocket & ".")
				TCPCloseSocket($sockets[$i])
			EndIf

			$port = $i
			$port0 = $i
			ExitLoop
		EndIf
		If $sockets[$i] < 0 Then	;Find the first open socket.
			$port = $i
			If $boxIP[$i] = "" Then	; Find the first never occupied socket
				$port0 = $i
			EndIf
		EndIf
	Next
	$port = ($port0 > $port) ? $port0 : $port

	If $boxIP[$port] <> $IP Then
		LogWrite($automationLogPort, " A new box connected at " & $IP & " on channel " & $port)
		GUICtrlSetData($bGUI[$port], "new box")	; update the text on the button
		ClearCommands($port)
	EndIf

	$sockets[$port] = $newSocket	;assigns that socket the incomming connection.
	$connectionTimers[$port] = $time0 + 5000	; Set connection lost timer to be 5s later
	$boxIP[$port] = $IP
EndFunc

Func PopCommand($n)
	Local $length = StringInStr($commands[$n], " ", 2)
	Local $nextCommand = StringLeft($commands[$n], $length-1)
	$commands[$n] = StringTrimLeft($commands[$n], $length)
	Return $nextCommand
EndFunc

Func PushCommand($n, $newCommand)
	$commands[$n] = $newCommand & " " & $commands[$n]
EndFunc

Func SendCommand($n, $command)
	Local $err
	Local $originalCommand
	If	IsString($command) Then $originalCommand = $command
	If $n > 0 Then
		$sentPattern = ""
		Local $len = 1
		While BinaryLen($command) And $len ; to send in chunks to reduce stress on the application
			$len = TCPSend($sockets[$n],BinaryMid($command, 1, $maxSendLength))
			$err = @error
			$command = BinaryMid($command,$len+1)
			$sentPattern &= $len & " "
		WEnd
		If $err Then
			LogWrite($n, "(Server) Connection lost with error : " & $err & " " & BinaryLen($command) & " bytes were not sent.")
			LogWrite($automationLogPort, "(Server) " & $boxID[$n] & " connection lost with error : " & $err)
			CloseConnection($n)
			If IsString($originalCommand) Then PushCommand($n, $originalCommand)	; let the command be sent later
		EndIf

		$connectionTimers[$n] = $time0 + 60 * 1000
	Else	; send the command to raspberry pi simulators
		If $piCommandHold Then
			LogWrite($n, "(Server) Raspberry Pi hold the duplicated " & $command & ".")
			Return
		EndIf

		If $socketRaspberryPi1 <= 0 Then
			$socketRaspberryPi1 = TCPConnect($ipRaspberryPi1, $portRaspberryPi)	; When RSP1 not connected, try to connect it
		EndIf

		If $socketRaspberryPi2 <= 0 Then
			$socketRaspberryPi2 = TCPConnect($ipRaspberryPi2, $portRaspberryPi)	; When RSP2 not connected, try to connect it
		EndIf

		If ($socketRaspberryPi1 < 0) And ($socketRaspberryPi2 < 0) Then
			LogWrite($automationLogPort, "(Server) Cannot connect to any Raspberry Pi Stimulator. " & $command & " was not sent.")
			$piCommandHold = False
			Return
		EndIf

		$piCommandHold = True	; release the pi command hold
		$commandID += 1
		If $commandID > 9 Then $commandID = 0
		If ($socketRaspberryPi1 > 0) Then
			If TCPSend($socketRaspberryPi1, $command & $commandID & " ") Then
				LogWrite($automationLogPort, "(Server) Sent " & $command & " to Raspberry Pi 1.")
			Else
				LogWrite($automationLogPort, "(Server) Connection to Raspberry Pi 1 lost. " & $command & " was not sent.")
				$socketRaspberryPi1 = -1
			EndIf
		EndIf

		If ($socketRaspberryPi2 > 0) Then
			If TCPSend($socketRaspberryPi2, $command & $commandID & " ") Then
				LogWrite($automationLogPort, "(Server) Sent " & $command & " to Raspberry Pi 2.")
			Else
				LogWrite($automationLogPort, "(Server) Connection to Raspberry Pi 2 lost. " & $command & " was not sent.")
				$socketRaspberryPi2 = -1
			EndIf
		EndIf
	EndIf
EndFunc

Func HotKeyPressed()
   Switch @HotKeyPressed ; The last hotkey pressed.
	  Case "!{Esc}" ; KeyStroke is the {ESC} hotkey. to stop testing and quit
	  $testEnd = True	;	Stop testing marker
	  Exit
    EndSwitch
 EndFunc   ;==>HotKeyPressed

Func SocketToIP($iSocket)
    Local $tSockAddr = DllStructCreate("short;ushort;uint;char[8]")
    Local $aRet = DllCall("Ws2_32.dll", "int", "getpeername", "int", $iSocket, "struct*", $tSockAddr, "int*", DllStructGetSize($tSockAddr))
    If Not @error And $aRet[0] = 0 Then
        $aRet = DllCall("Ws2_32.dll", "str", "inet_ntoa", "int", DllStructGetData($tSockAddr, 3))
        If Not @error Then Return $aRet[0]
    EndIf
    Return 0
EndFunc   ;==>SocketToIP

; This function will disable the XP Style, so that Autoit can draw the progressbar in smooth, and with colors.

Func XPStyleToggle($OnOff = 1)
	If Not StringInStr(@OSTYPE, "WIN32_NT") Then Return 0

	If $OnOff Then
		$XS_n = DllCall("uxtheme.dll", "int", "GetThemeAppProperties")
		DllCall("uxtheme.dll", "none", "SetThemeAppProperties", "int", 0)
		Return 1
	ElseIf IsArray($XS_n) Then
		DllCall("uxtheme.dll", "none", "SetThemeAppProperties", "int", $XS_n[0])
		$XS_n = ""
		Return 1
	EndIf
	Return 0
EndFunc ;==>XPStyleToggle
