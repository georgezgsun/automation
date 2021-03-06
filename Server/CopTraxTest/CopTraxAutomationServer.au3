#Region ;**** Directives created by AutoIt3Wrapper_GUI ****
#AutoIt3Wrapper_Res_Description=Automation test server
#AutoIt3Wrapper_Res_Fileversion=2.8.6.1
#AutoIt3Wrapper_Res_Fileversion_AutoIncrement=y
#EndRegion ;**** Directives created by AutoIt3Wrapper_GUI ****

#pragma compile(Icon, clouds.ico)
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
Global $config = "" ; It is empty in the beginning
Global $InproperID = False	; Keep the record of inproper box ID
Local $cheatSheet = ReadCheatSheet()

OnAutoItExitRegister("OnAutoItExit")	; Register OnAutoItExit to be called when the script is closed.
Global $TCPListen = TCPListen ($ipServer, $port, $maxListen)

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
$allCommands[23] = "configure release bwc ct"
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
Global $bufferReceived[$maxConnections + 1]	; the command timer for each UUT; when reaches, next test command shall be started
Global $filesReceived[$maxConnections + 1]	; stores the file handler of files that need to be upload to server from that UUT
Global $fileSendingAllowed[$maxConnections + 1]	; stores the file handler of files that need to be upload to server from that UUT
Global $byteCounter[$maxConnections + 1]	; counter of bytes that need to receive from UUT for the upload file
Global $fileToBeSent[$maxConnections + 1]	; file handler of files that need to download to UUT
Global $pGUI[$maxConnections + 1]	; the control ID of the progressbar for that UUT
Global $nGUI[$maxConnections + 1]	; the control ID of the timer for that UUT
Global $bGUI[$maxConnections + 1]	; the control ID of the button for that UUT, the name(serial number) is displayed on the button
Global $totalCommands[$maxConnections + 1]	; the counter of the total test commands in the test case for each UUT
Global $testEndTime[$maxConnections + 1]	; stores the end time estimation for each UUT
Global $testFailures[$maxConnections + 1]	; stores the number of failures in automation test for each UUT
Global $boxID[$maxConnections + 1]	; stores the serial number of each UUT
Global $boxIP[$maxConnections + 1]	; stores the IP address of each UUT during the automation test
Global $batchWait[$maxConnections + 1]	; stores the batch mode of each test during the automation test. True means not to hold other box entering batch align mode
Global $errorsFirmware[$maxConnections + 1]	; stores the errors of event logs during the automation test. If the errors exceeds 10,reboot
Global $flagOldClient[$maxConnections + 1] ; stores the flag of old version client
Local $timeRemains[$maxConnections + 1]	; stores the remain time estimation in seconds for each UUT
Local $timerConnections[$maxConnections + 1]	; the TCP connection timer for each UUT;  when reaches, TCP connection to that UUT may have lost
Global $timerFileTransfer[$maxConnections + 1]	; timer of file transfering; when reaches, the server need to clear current file transfer mode
Global $listFailed = ""	; the list of UUT's serial number that failed the automation test
Global $listPassed = "" ; the list of UUT's serial number that passed the automation test
Global $portDisplay = 0	; stores the index of UUT which log is displayed in the window

Local $i
For $i = 0 To $maxConnections	; initialize the variables
	$sockets[$i] = -1	; Stores the sockets for each client
	$timerConnections[$i] = 0
	$fileSendingAllowed[$i] = False
	$timerFileTransfer[$i] = 0
	$timeRemains[$i] = 0
	$filesReceived[$i] = 0
	$logFiles[$i] = 0
	$fileToBeSent[$i] = ""
	$bufferReceived[$i] = ""
	$boxIP[$i] = ""
	$logContent[$i] = $cheatSheet
	$batchWait[$i] = True	; default value is true, not to hold other box entering batch align mode
	$flagOldClient[$i] = False
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
LogWrite($automationLogPort, "Server" & @TAB & "A new batch of automation test starts.")
LogWrite($automationLogPort, "Server" & @TAB & "Current version : " & FileGetVersion ( @ScriptFullPath ))
LogWrite($automationLogPort, "Server" & @TAB & "Run @" & $ipServer & ":" & $port & ".")
LogWrite($automationLogPort, "")
GUICtrlSetData($cLog, $cheatSheet)

Global $hTimer = TimerInit()	; global timer handle
Global $testEnd = False
Global $batchAligned = False
Global $batchMode = False	; Not in batch mode until get a batch align command
Local $commandLeft
Local $timeLeft
Local $lastEndTime = 0
Local $batchCheck = False
Local $tempTime
Local $tempPattern
Local $Recv

Global $time0
Local $msg
Local $tLoop = ""
Local $file
Local $nextCommand
Local $err
Local $len
While Not $testEnd	; main loop that get input, display the results
	$time0 = Int(TimerDiff($hTimer))	; get current timer elaspe
	$i = AcceptConnection()	; accept new client's connection requist
	If $i Then
		$timerConnections[$i] = $time0 + 60 * 1000
	EndIf

	$batchCheck = ($totalConnection > 0)
	$totalConnection = 0
	$tempPattern = ""
	$lastEndTime = 0
	For $i = 1 To $maxConnections
		If Not $timerConnections[$i] Then
			$tempPattern &= "0"
			ContinueLoop
		EndIf

		If $batchWait[$i] Then
			$tempPattern &= "+"
		Else
			$tempPattern &= "x"
			$batchCheck = False	; there is one not aligned
		EndIf
		$totalConnection += 1

		If ProcessReply($i) Then
			If Not $timerConnections[$i] Then ContinueLoop
			$timerConnections[$i] = $time0 + 1000 * 90 ; renew the connection check timer
		EndIf

		$timeLeft = CorrectRange(Round(($testEndTime[$i] - $time0) / 1000), 0, 24*3600)
		If $timeLeft <> $timeRemains[$i]	Then
			$timeRemains[$i] = $timeLeft
			GUICtrlSetData($nGUI[$i], toHMS($timeLeft))
		EndIf

		If $timeLeft > $lastEndTime Then
			$lastEndTime = $timeLeft
		Endif

		If $fileSendingAllowed[$i] Then
			$len = TCPSend($sockets[$i], BinaryMid($fileToBeSent[$i], 1, $maxSendLength))	; send at most maxSendLength bytes each time
			$err = @error
			If $err Then
				LogWrite($i, "Server" & @TAB & "Connection lost while sending files to client. " & BinaryLen( $fileToBeSent[$i] ) & " bytes fails to be sent.")
				$fileToBeSent[$i] = ""
			Else
				LogWrite($i, "Server" & @TAB & "Sent " & $len & " bytes to client.")
			EndIf
			$fileToBeSent[$i] = BinaryMid($fileToBeSent[$i], $len + 1)
			If Not $fileToBeSent[$i] Then $fileSendingAllowed[$i] = False	; not allow to send file since the filecotent is empty now
		EndIf

		If $filesReceived[$i] And ($time0 > $timerFileTransfer[$i]) Then
			LogWrite($i, "Last file transfering is not completed in given time. Reset the file stransfering")
			CloseConnection($i)
		EndIf

		If $time0 > $timerConnections[$i] Then
			$timerConnections[$i] = 0
			LogWrite($automationLogPort, $boxID[$i] & @TAB & "Connection has lost duo to time out.")
			LogWrite($i, "Server" & @TAB & "Connection has lost duo to time out.")
			GUICtrlSetData($nGUI[$i], "LOST")	; show interrupt message
			$testEndTime[$i] = 0	; test ends
			$timeRemains[$i] = 0	; test ends
			CloseConnection($i)
			ClearCommands($i)
		EndIf
	Next

	If $socketRaspberryPi1 > 0 Then
		$tempPattern &= "1"
		$Recv = TCPRecv($socketRaspberryPi1, 100)	; when connected, try to receive message
		If $Recv Then
			LogWrite($automationLogPort, "RSPi1" & @TAB & "Replied " & $Recv )
			TCPCloseSocket($socketRaspberryPi1)
			$socketRaspberryPi1 = -1
		EndIf
	EndIf

	If $socketRaspberryPi2 > 0 Then
		$tempPattern &= "2"
		$Recv = TCPRecv($socketRaspberryPi2,100)	; when connected, try to receive message
		If $Recv Then
			LogWrite($automationLogPort, "RSPi2" & @TAB & "Replied " & $Recv )
			TCPCloseSocket($socketRaspberryPi2)
			$socketRaspberryPi2 = -1
		EndIf
	EndIf

	If $time0 > $piHeartbeatTime Then
		$piCommandHold = False
		If $socketRaspberryPi1 > 0 Then
			TCPCloseSocket($socketRaspberryPi1)
			$socketRaspberryPi1 = -1
		EndIf
		If $socketRaspberryPi2 > 0 Then
			TCPCloseSocket($socketRaspberryPi2)
			$socketRaspberryPi2 = -1
		EndIf
	EndIf

	If $batchCheck And Not $batchAligned Then	; When first time reach Aligned only
		LogWrite($automationLogPort, "Server" & @TAB & "All clients aligned.")
		For $i = 1 To $maxConnections
			If StringInStr($commands[$i], "batchhold") Then	; all aligned box have a batchhold command in the command queue
				$bufferReceived[$i] = "Request for new command." & @CRLF & $bufferReceived[$i]	; artificially request next command in next round, which is batchhold
			EndIf
		Next
	EndIf
	$batchAligned = $batchCheck

	If $tempTime <> $lastEndTime Then
		GUICtrlSetData($nGUI[0], toHMS($lastEndTime))
		$tempTime = $lastEndTime
	EndIf

	If $connectionPattern <> $tempPattern Then
		$connectionPattern = $tempPattern
		LogWrite($automationLogPort, "Server" & @TAB & $connectionPattern)
		GUICtrlSetData($cID, $connectionPattern)
	EndIf

	$testEnd = ProcessMSG()

	$tempPattern = Int(TimerDiff($hTimer) - $time0)
	If $tempPattern > $maxLoopTime Then
		LogWrite($automationLogPort, "Server" & @TAB & "WARNING! Loop time is " & $tempPattern & "ms.")
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
	If Not ($msg Or $comboList) Then Return False

	For $i = 1 To $maxConnections
		If $msg = $bGUI[$i] Then
			$portDisplay = $i	; update the log display for that button
			If $boxID[$i] Then
				GUICtrlSetData($tLog, " " & $boxID[$i])
			Else
				GUICtrlSetData($tLog, "CheatSheet")
			EndIf
			GUICtrlSetData($cLog, $logContent[$i])
			Return False
		EndIf
	Next

	Local $fileList = _FileListToArray($workDir, "*.mcfg", 1)	; list *.config files in ..\latest folder
	$fileList = StringReplace(_ArrayToString($fileList), ".mcfg", "")	; get rid of the file extension
	$fileList = StringRegExpReplace($fileList, "(^[0-9].)", "")	; get rid of the heading number
	If $fileList <> $comboList Then
		$comboList = $fileList
		If Not $config Then
			$config = StringLeft($fileList, StringInStr($fileList, "|") - 1) ; assign config to the first available item in the list when it is empty
			$msg = $idComboBox
		EndIf
		GUICtrlSetData($idComboBox, "|" & $fileList, $config)
	EndIf

	If $msg = $idComboBox Then
		$config = GUICtrlRead($idComboBox)
		LogWrite($automationLogPort, "")
		LogWrite($automationLogPort, "Server" & @TAB & "Change the configure to " & $config & ".")
		Return False
	EndIf

	If $msg = $GUI_EVENT_CLOSE Then
		LogWrite($automationLogPort, "Server" & @TAB & "Automation test end by operator.")
		LogWrite($automationLogPort, "")
		Return True
	EndIf

	Return False
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
	;LogWrite($automationLogPort, "Socket time out")
EndFunc

Func ParseCommand($n)
	Local $interval
	Local $IP
	Local $arg = EstimateCommands($commands[$n]) ;
	Local $commandLeft = Int(GetParameter($arg, "count"))
	Local $duration = Int(GetParameter($arg, "time"))	; time remains in seconds
	$testEndTime[$n] = $time0 + $duration * 1000 ; time that the test will end in milliseconds
	Local $progress = CorrectRange(100 * (1-$commandLeft/$totalCommands[$i]), 0, 100)
	GUICtrlSetData($pGUI[$n], $progress)

	If $filesReceived[$n] Then	; This indicates there exists file uploading, do not send new command until it ends
		SendCommand($n, "heartbeat")	; Write a non reply command
		Return 	; keep the current socket close timer
	EndIf

	Local $newCommand = PopCommand($n)
	If $newCommand = "" Then 	; no command left to be precessed
		SendCommand($n, "quittest")
		Return
	EndIf

	Switch $newCommand	; process the new command
		Case "record"
			$arg = PopCommand($n)
			LogWrite($i, "Server" & @TAB & "Read '" & $newCommand & " " & $arg & "' command.")
			$duration = CorrectRange(Int(GetParameter($arg, "duration")), 1, 999)
			$interval = Int(GetParameter($arg, "interval"))
			If $interval < 1 Or $interval > 10 Then $interval = 10

			PushCommand($n, "endrecord " & $interval)
			$newCommand = "startrecord " & $duration * 60
			SendCommand($n, $newCommand)
			LogWrite($i, "Server" & @TAB & "Sent '" & $newCommand & "' command to client. The endrecord command will be sent in " & $duration & " mins.")

		Case "endrecord"
			$arg = PopCommand($n)
			LogWrite($i, "Server" & @TAB & "Read '" & $newCommand & " " & $arg & "' command.")
			$newCommand = "endrecord " & Int($arg)*60
			SendCommand($n, $newCommand)	; send new test command to client
			LogWrite($i, "Server" & @TAB & "Sent '" & $newCommand & "' command to client. Next command is in " & $arg & " mins.")

		Case "settings", "createprofile", "upload", "checkfirmware", "checkapp", "checklibrary", "checkrecord", "pause", "configure"
			$arg = PopCommand($n)
			LogWrite($i, "Server" & @TAB & "Read '" & $newCommand & " " & $arg & "' command.")
			If StringInStr($newCommand, "config") Then $arg &= "|case=" & StringReplace($config, " ", "")	; get rid of space in the filename
			$newCommand &= " " & $arg
			LogWrite($i, "Server" & @TAB & "Sent '" & $newCommand & "' command to client.")
			SendCommand($n, $newCommand)	; send new test command to client

		Case "siren", "lightbar", "aux4", "aux5", "aux6", "lightswitch", "mic1trigger", "mic2trigger"
			If Not $piCommandHold And $socketRaspberryPi1 <= 0 Then
				$socketRaspberryPi1 = TCPConnect($ipRaspberryPi1, $portRaspberryPi)	; When RSP1 not connected and not in command hold mode, try to connect it
			EndIf
			If Not $piCommandHold And $socketRaspberryPi2 <= 0 Then
				$socketRaspberryPi2 = TCPConnect($ipRaspberryPi2, $portRaspberryPi)	; When RSP2 not connected, try to connect it
			EndIf

			$arg = PopCommand($n)
			LogWrite($i, "Server" & @TAB & "Read '" & $newCommand & " " & $arg & "' command.")

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

			If $piCommandHold Then
				LogWrite($i, "Server" & @TAB & "Sent '" & $aCommand & "' command to client. '" & $piCommand & "' command to Raspberry Pi is already sent momentarilly before.")
			Else
				SendCommand(0, $piCommand)  ; send pi its command
				LogWrite($i, "Server" & @TAB & "Sent '" & $aCommand & "' command to client. Sent '" & $piCommand & "' command to Raspberry Pi.")
			EndIf
			SendCommand($n, $aCommand)    ; send new test command to client
			$batchWait[$n] = False	; enter batchtest stop mode, stops any other box from entering aligned mode

		Case "review", "photo", "info", "status", "radar", "stopapp", "runapp", "camera", "about", "reboot", "quittest", "restarttest", "cleanup"
			SendCommand($n, $newCommand)	; send new test command to client
			LogWrite($i, "Server" & @TAB & "Read '" & $newCommand & "' command.")
			LogWrite($i, "Server" & @TAB & "Sent '" & $newCommand & "' command to client.")

		Case "onfailure"
			$arg = PopCommand($n)
			LogWrite($i, "Server" & @TAB & "Read '" & $newCommand & " " & $arg & "' command. Checking for any failures so far.")
			If $testFailures[$n] > 0 Then
				$commands[$n] = ""	; clear the command queue when there are failures

				If StringInStr($arg, "start") Then
					PushCommand($n, "upload all restart")
					LogWrite($i, "Server" & @TAB & "Change the rest test commands to 'upload all restart' because there are " & $testFailures[$n] & " failures in this test.")
				EndIf

				If StringInStr($arg, "quit") Then
					PushCommand($n, "upload all quittest")
					LogWrite($i, "Server" & @TAB & "Change the rest test commands to 'upload all quit'  because there are " & $testFailures[$n] & " failures in this test.")
				EndIf

				If StringInStr($arg, "boot") Then
					PushCommand($n, "upload all reboot")
					LogWrite($i, "Server" & @TAB & "Change the rest test commands to 'upload all reboot' because there are " & $testFailures[$n] & " failures in this test.")
				EndIf
			Else
				LogWrite($i, "Server" & @TAB & "There is no failure in the test so far.")
			EndIf

		Case "synctime"
			$arg = @YEAR & @MON & @MDAY & @HOUR & @MIN & @SEC
			SendCommand($n, $newCommand & " " & $arg)	; send new test command to client
			LogWrite($i, "Server" & @TAB & "Read '" & $newCommand & "' command.")
			LogWrite($i, "Server" & @TAB & "Sent '" & $newCommand & " " & $arg & "' command to client.")

		Case "synctmz"
			Local $tmzarg = _Date_Time_GetTimeZoneInformation ( )
			$arg = $tmzarg[2]
			SendCommand($n, $newCommand & " " & $arg)	; send new test command to client
			LogWrite($i, "Server" & @TAB & "Read '" & $newCommand & "' command.")
			LogWrite($i, "Server" & @TAB & "Sent '" & $newCommand & " " & $arg & "' command to client.")

		Case "update"
			Local $fileName = PopCommand($n)
			Local $file
			Local $netFileName
			Local $sourceFileName
			LogWrite($i, "Server" & @TAB & "Read '" & $newCommand & " " & $fileName & "' command.")

			;$fileName = StringReplace($fileName, "\_", " ")
			;$fileName = StringReplace($fileName, "\!", "|")
			If StringInStr($filename, "\") Then
				$netFileName = StringSplit($fileName, "\")
				$sourceFileName = $workDir & "latest\" & $netFileName[$netFileName[0]]    ; all file need to be update shall sit in \latest folder
			Else
				$sourceFileName = $workDir & "latest\" & $fileName
			Endif

			$file = FileOpen($sourceFileName,16)	; open file for read only in binary mode
			$fileToBeSent[$n] = FileRead($file)
			FileClose($file)
			Local $fLen = BinaryLen($fileToBeSent[$n])
			$newCommand = "update " & $fileName & " " & $fLen
			SendCommand($n, $newCommand)	; send new test command to client
			LogWrite($i, "Server" & @TAB & "Sent '" & $newCommand & "' command to client.")
			LogWrite($i, "Server" & @TAB & "Sending " & $sourceFileName & " in server to update " & $fileName & " in client.")
			$fileSendingAllowed[$n] = False

		Case "batchtest"
			$arg = StringLower(PopCommand($n))
			LogWrite($i, "Server" & @TAB & "Read 'batchtest " & $arg & "' command.")

			$IP =  StringInStr($arg, "10.0.") ? TCPNameToIP($arg) : ""
			If $IP Then
				LogWrite($i, "Server" & @TAB & "Select the Raspberry Pi simulator at " & $IP & " to do the triggers test.")
				LogWrite($automationLogPort, "Server" & @TAB & "Select the Raspberry Pi simulator at " & $IP & " to do the triggers test.")
				$ipRaspberryPi1 = $IP
				$ipRaspberryPi2 = @IPAddress1
			EndIf

			If $arg = "align" Then
				If $batchMode Then
					LogWrite($i, "Server" & @TAB & "PASSED. Wait till all other clients aligned.")
					LogWrite($automationLogPort, $boxID[$n] & @TAB & "Aligned.")
					PushCommand($n, "batchhold")
					$batchWait[$n] = True	; indicates client $n in batch wait mode now
				Else
					LogWrite($i, "Server" & @TAB & "FAILED. In batchtest stop mode, cannot achieve align.")
				EndIf
			EndIf

			If $arg = "start" Then
				LogWrite($i, "Server" & @TAB & "Start batch test mode, hold other boxes from entering trigger test until all box aligned.")
				LogWrite($automationLogPort, $boxID[$n] & @TAB & "Enter batch test mode.")
				$batchWait[$n] = False
				$batchMode = True
				SendCommand($n, "upload wait")	; make the client not to upload files during the waiting for alignment period
				LogWrite($n, "Set the upload mode to 'wait' to avoid file uploading while waiting for alignment.")
			EndIf

			If $arg = "stop" Then
				LogWrite($i, "Server" & @TAB & "Enter stop batch test mode, disabled all other later boxes from achieving align mode.")
				$batchWait[$n] = False
				$batchAligned = False
				SendCommand($n, "upload idle")	; make the client not to upload files during the waiting for alignment period
				LogWrite($n, "Set the upload mode back to 'idle' to allow file uploading while waiting.")

				If $batchMode Then
					SendCommand(0, "h0")
					LogWrite($automationLogPort, "Server" & @TAB & "Send Raspberry Pi simulator handshake command." )
					$batchMode = False
				EndIf
			EndIf

		Case "batchhold"
			If $batchAligned Then
				LogWrite($i, "Server" & @TAB & "All clients aligned.")
				SendCommand($n, "pause 10")	; all aligned box will get this command no matter what the previouse pause mode they are in
			Else
				PushCommand($n, "batchhold")	; the batchhold command can only be cleared by all active clients entering batch wait mode
				SendCommand($n, "pause 600")	; check in next 10min in case connection lost
			EndIf
			Return

		Case Else
			LogWrite($i, "Server" & @TAB & "Unknown command '" & $newCommand & "'. Commands in stack are " & $commands[$n])
			SendCommand($n, "pause 5")
	EndSwitch
EndFunc

Func LogWrite($n,$s)
	If $n <= 0 Or $n > $maxConnections + 1 Then Return

	If StringLeft($s,3) = "===" Then
		$s = "=============" ; get 13 =
		$s = $s & $s & "===" ; 13x2+3 = 29 =
		$s = $s & $s & $s & $s & @CRLF ; 29x4 = 116
	Else
		$s = @HOUR & ":" & @MIN & ":" & @SEC & @TAB & $s & @CRLF	; show the log with time stamps
	EndIf

	If $logFiles[$n] Then FileWrite($logFiles[$n], $s)
	If StringInStr($s, "error event") Then Return
	$s = StringReplace($s, @TAB, " ")

	If $n = $automationLogPort Then
		GUICtrlSetData($aLog, $s, 1)
		Return
	EndIf

	$logContent[$n] &= $s

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
			$testTime = ($j < 3) ? $testTime + 40 : $testTime + 10
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
	Local $reply = ""
	Local $len
	Local $err
	Local $sentPattern = ""

	If Not $bufferReceived[$n] And ($sockets[$n] <= 0) Then Return False

	If $filesReceived[$n] Then	; This indicates the coming message shall be saved in file
		$reply = TCPRecv($sockets[$n], 1000000, 1)	; receives in binary mode using longer length
		$err = @error
		If $err Then
			LogWrite($i, "Server" & @TAB & "Connection lost with error : " & $err)
			LogWrite($automationLogPort, $boxID[$n] & @TAB & "Connection lost with error : " & $err)
			FileClose($filesReceived[$n])	; get and save the file
			$filesReceived[$n] = 0	;clear the flag when file transfer ends
			CloseConnection($n)
			Return False
		EndIf

		$len = BinaryLen($reply)
		If $len = 0 Then Return False	; receives nothing

		FileWrite($filesReceived[$n], $reply)
		$byteCounter[$n] -= $len
		LogWrite($i, "Server" & @TAB & "Received " & $len & " bytes, " & $byteCounter[$n] & " bytes remains.")

		If $byteCounter[$n] < 5 Then
			FileClose($filesReceived[$n])	; get and save the file
			$filesReceived[$n] = 0	;clear the flag when file transfer ends
			SendCommand($n, "eof")	; send "eof" command to client
			LogWrite($n,"(Server) Send 'eof' command to client.")
		EndIf

		Return True
	EndIf

	If $sockets[$n] > 0 Then
		$reply = TCPRecv($sockets[$n], 1000)    ; receive in text mode using short length
		$err = @error
		If $err Then
			LogWrite($automationLogPort, $boxID[$n] & @TAB & "The socket is closed at " & @MIN & ":" & @SEC)
			CloseConnection($n)
		EndIf

		If $reply Then
			If IsBinary($reply) Then
				LogWrite($i, "Server" & @TAB & "Received unsaved upload file content with " & $len & " bytes.")
				CloseConnection($n)
				Return True
			EndIf

			$bufferReceived[$n] &= $reply	; append the receiving to the buffer

			If StringMid($reply, 14, 5) = " new " Then
				$flagOldClient[$n] = True
				$bufferReceived[$n] = StringReplace($reply, " new ", " ") & @CRLF & "Request for new command."; backward compatible
			EndIf

			If $flagOldClient[$n] Then
				If StringInStr($bufferReceived[$n], "Continue Got the update command.")  Then
					$bufferReceived[$n] &= " Send file now."
				EndIf

				If StringInStr($bufferReceived[$n], "Continue End of File")  Then
					$bufferReceived[$n] &= @CRLF & "Request for new command."
				EndIf

				$bufferReceived[$n] &= @CRLF
			EndIf
		EndIf
	EndIf

	$len = StringInStr($bufferReceived[$n], @CRLF)	; process the first whole reply end with @CRLF
	If $len = 0 Then Return $reply <> ""

	$reply = StringLeft($bufferReceived[$n], $len-1)	; get the reply without @CRLF
	$bufferReceived[$n] = StringMid($bufferReceived[$n], $len + 2) ; refresh the buffer
	If Not $reply Then Return True

	If StringInStr($reply, "Request for new ") Then
		LogWrite($n, "")	; write an empty line as a seperator in the log file
		ParseCommand($n)	; Get a new command and execute it
		Return True
	EndIf

	If StringLeft($reply, 5) = "file " Then
		LogWrite($n, "")	; write an empty line when get a file request as a seperator
	EndIf

	LogWrite($n, "Client" & @TAB & $reply)	; write the returned results into the log file

	Local $newCommand
	Local $msg = StringSplit($reply, " ")
	Local $readTxt

	If ($msg[0] >= 5) And StringInStr($reply, "Identify ", 1) Then	; the settings reply the identify ID
		$readTxt =  StringRegExp($reply, "([a-zA-Z]{2}[0-9]{6})", $STR_REGEXPARRAYMATCH)
		If IsArray($readTxt) And ($readTxt[0] <> $boxID[$n]) Then
			LogWrite($i, "Server" & @TAB & "Got the box serial number updated from " & $boxID[$n] & " to " & $readTxt[0] & ". Have to update the log file.")
			$boxID[$n] = $readTxt[0]	; update the box ID
			$portDisplay = $n	; update the main log display to current box
			GUICtrlSetData($bGUI[$n], $boxID[$n])	; update the text on the button
			GUICtrlSetData($tLog, " " & $boxID[$n])	; update the serial number on top the main log display

			FileClose($logFiles[$n])
			$logFiles[$n] = FileOpen($workDir & "log\" & $boxID[$n] & ".log", 1+8) ; open log file for append write in text mode
			FileWrite($logFiles[$n], $logContent[$n])	; write the previouse log content into new log file
			$logContent[$n] = "" ; clear the log when it was written to log file
			$InproperID = False	; clear the flag
		EndIf
		Return True
	EndIf

	If ($msg[0] >= 3) And ($msg[1] = "file") Then	; start to upload file from client
		Local $filename = $msg[2]
		Local $len =  Int($msg[3])
		Local $netFileName = StringSplit(StringReplace($filename, "\_", " "), "\")
		Local $destFileName = $workDir & "ClientFiles\" & $boxID[$n] & "\" & $netFileName[$netFileName[0]]
		LogWrite($i, "Server" & @TAB & "" & $filename & " from client is going to be saved as " & $destFileName & " in server.")
		LogWrite($i, "Server" & @TAB & "Total " & $len & " bytes need to be stransfered.")
		$filesReceived[$n] = FileOpen($destFileName,16+8+2)	; open file for over-write and create the directory structure if it doesn't exist
		$timerFileTransfer[$n] = $time0 + 60 * 1000; set the timer of file transfering, the file transfer shall
		$byteCounter[$n] = $len
		SendCommand($n, "send")	; send "send" command to client to trigger the file transfer
		LogWrite($i, "Server" & @TAB & "Sent 'send' command to client.")
		Return True
	EndIf

	If ($msg[0] >= 3) And ($msg[1] = "name") Then	; Start a new test when got name reply
		StartNewTest($n, $msg[2], $msg[3])
		Return True
	EndIf

	If ($msg[0] >= 1) And ($msg[1] = "FAILED") Then	; Got a FAILED reply,
		$testFailures[$n] += 1
		GUICtrlSetColor($pGUI[$n], $COLOR_RED)
		LogWrite($automationLogPort, $boxID[$n] & @TAB & $reply)
		LogWrite($automationLogPort, "")

		If $filesReceived[$n] Then
			FileClose($filesReceived[$n])	; close the file
			$filesReceived[$n] = 0	;clear the flag when file transfer ends
			LogWrite($i, "Server" & @TAB & "Last file update failed by client.")
		EndIf
	EndIf

	If StringInStr($reply, "Fatal error.") Then
		$testFailures[$n] += 1
		GUICtrlSetColor($pGUI[$n], $COLOR_RED)

		PushCommand($n, "upload all reboot")	; seems there exists mis-matching problems in the client box, reboot to fix it
		LogWrite($automationLogPort, $boxID[$n] & @TAB & "Firmware reading mulfunction. Need to be reboot.")
		LogWrite($n, "Firmware reading error. Cannot read valid data from firmware.")
	EndIf

	If StringInStr($reply, "App error") And Not StringInStr($reply, "(15 ms)") Then
		$errorsFirmware[$n] += 1
		If $errorsFirmware[$n] > 10 Then
			GUICtrlSetColor($pGUI[$n], $COLOR_RED)
			$errorsFirmware[$n] = 0
			PushCommand($n, "upload all reboot")	; Send command reboot to client to force a reboot
			LogWrite($automationLogPort, $boxID[$n] & @TAB & "CopTrax App errors exceed 10 times. Have to reboot the box.")
			LogWrite($n, "CopTrax App errors exceed 10 times.  Have to reboot the box.")
		EndIf
	EndIf

	If ($msg[0] >= 1) And ($msg[1] = "quit") Then
		If StringLen($commands[$n]) > 5 Then
			LogWrite($automationLogPort, $boxID[$n] & @TAB & "Tests was interrupted.")
			LogWrite($i, "Server" & @TAB & "Tests was interrupted.")
			GUICtrlSetData($nGUI[$n], "interrupt")
		Else
			If StringInStr($boxID[$n], "DK") Then
				LogWrite($automationLogPort, $boxID[$n] & @TAB & "Serial number is inproper.")
				LogWrite($i, "Server" & @TAB & "" & $boxID[$n] & " is not a properly programmed serial number. The box need to be re-programmed.")
				$testFailures[$n] += 1	; initialize the result true until any failure
			EndIf

			GUICtrlSetData($pGUI[$n], 100)
			If $testFailures[$n] = 0 Then
				LogWrite($n, "Server" & @TAB & "All tests passed.")
				LogWrite($automationLogPort, $boxID[$n] & @TAB & "All tests passed. AUTOMATION TEST ENDS.")
				GUICtrlSetColor($pGUI[$n], $COLOR_GREEN)
				GUICtrlSetData($nGUI[$n], "PASSED")
				UpdateLists($boxID[$n], "")
			Else
				LogWrite($n, "Server" & @TAB & "Tests failed with " & $testFailures[$n] & " failures.")
				LogWrite($automationLogPort, $boxID[$n] & @TAB & "Tests failed with " & $testFailures[$n] & " failures.")
				LogWrite($automationLogPort, $boxID[$n] & @TAB & "ALL TESTS DID NOT PASS.")
				GUICtrlSetData($nGUI[$n], "FAILED" )
				UpdateLists( "", $boxID[$n] )
			EndIf
			$testEndTime[$n] = 0
		EndIf

		GUICtrlSetState($nGui[$n], $GUI_SHOW)
		LogWrite($n, "=====")
		LogWrite($n, " ")
		$logContent[$n] = ""	; clear the previouse log content

		CloseConnection($n)
		ClearCommands($n)
		$timerConnections[$n] = 0
		$totalConnection -= 1
		Return True
	EndIf

	If StringInStr($reply, "Heartbeat", 1) Then
		SendCommand($n, "heartbeat")
		Return True
	EndIf

	If StringInStr($reply, "End of file", 1) Then
		$fileToBeSent[$n] = ""
	EndIf

	If StringInStr($reply, "Send file") Then
		$fileSendingAllowed[$n] = True
	EndIf

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
	$commands[$n] = ""	; clear the command queue
EndFunc

Func StartNewTest($n, $ID, $clientVersion)
	ClearCommands($n)
	Local $nextCommand
	Local $filename = $workDir & "log\" & $ID & ".log"

	$logFiles[$n] = FileOpen($filename, 1+8) ; open log file for append write in text mode
	FileWrite($logFiles[$n], $logContent[$n])	; write the previouse log content into new log file
	$logContent[$n] = ""	; clear the previouse log content

	LogWrite($n, " ")
	LogWrite($n, "=====")
	LogWrite($n, " " & @MON & "/" & @MDAY & "/" & @YEAR)
	LogWrite($n, " Start automation test for CopTrax DVR box " & $ID & " at " & $boxIP[$n])
	LogWrite($n, " Current version of the test server : " & FileGetVersion ( @ScriptFullPath ) & ", of the client : " & $clientVersion)
	GUICtrlSetData($cLog, $logContent[$n])	; display and update the log content

	LogWrite($automationLogPort, "")
	LogWrite($automationLogPort, " " & @MON & "/" & @MDAY & "/" & @YEAR)
	LogWrite($automationLogPort, $ID & @TAB & "Connected on " & $boxIP[$n] & " at channel " & $n & ".")

	$portDisplay = $n
	GUICtrlSetData($bGUI[$n], $ID)	; update the text on the button
	GUICtrlSetData($tLog, " " & $ID)	; update the serial number on top the main log display
	$boxID[$n] = $ID	; get the boxID from client

	Local $latestVersion = FileGetVersion($workDir & "latest\CopTraxAutomationClient.exe")
	If _VersionCompare($clientVersion, $latestVersion) < 0 Then	; $latest version is greater
		PushCommand($n, "update C:\CopTraxAutomation\tmp\CopTraxAutomationClient.exe restarttest restarttest")
		LogWrite($n, " Find latest automation tester in Server. Updating client to " & $latestVersion & ". Test will restart.")
		LogWrite($n, "=====")
		Return
	Else
		LogWrite($n, " The latest automation test app version is " & $latestVersion & ". App in client is up-to-date.")
	EndIf

	If Not StringRegExp($ID, "[A-Za-z]{2}[0-9]{6}")  Then
		LogWrite($n, "The Serial Number reported from the box " & $ID & " is invalid. Reboot the box now.")
		LogWrite($automationLogPort, $boxID[$n] & @TAB & "Firmware error. Cannot read serial number. Reboot now.")
		SendCommand($n, "reboot")
		Return
	EndIf

	If StringInStr($ID, "DK") Then
		If $InproperID Then ; Got DK123456 again
			$testFailures[$n] += 1
			GUICtrlSetColor($pGUI[$n], $COLOR_RED)
			GUICtrlSetData($pGUI[$n], 100)
			SendCommand($n, "reboot")
			LogWrite($automationLogPort, $ID & @TAB & "Serial number is inproper. The box need to be reboot now.")
			Return
		Else
			$InproperID = True
		EndIf
	EndIf

	$filename = $workdir & $boxID[$n] & ".txt"	; try to find if any individual test case exits
	If Not FileExists($filename) Then	; If there is no individual test case, try to read general test case.
		$filename = $workdir & $config & ".txt"
	Endif
	$commands[$n] = ReadTestCase($filename)	; Read test case from file
	If $commands[$n] = "" Then
		LogWrite($n, "Cannot read test case from " & $filename & ". Assign a simple test case.")
		$filename = "Simple Test Case"
		PushCommand($n, "synctms synctime quittest")
	EndIf

	Local $estimate = EstimateCommands($commands[$n])
	Local $commandsNumber = Int(GetParameter($estimate, "count"))
	Local $totalTestTime = toHMS(Int(GetParameter($estimate, "time")))

	GUICtrlSetData($pGUI[$n], 0)
	GUICtrlSetData($nGUI[$n], $totalTestTime)
	GUICtrlSetColor($nGUI[$n], $COLOR_BLACK)
	GUICtrlSetColor($pGUI[$n], $COLOR_SKYBLUE)

	LogWrite($n, " Test case is read from " & $filename)
	LogWrite($n, " - " & $commands[$n])
	LogWrite($n, " Number of test commands: " & $commandsNumber & ". Estimated test time is " & $totalTestTime & ".")
	LogWrite($n, "=====")

	LogWrite($automationLogPort, $boxID[$n] & @TAB & "START AUTOMATION TEST.")
	LogWrite($automationLogPort, $boxID[$n] & @TAB & "Number of test commands: " & $commandsNumber & ". Estimated test time is " & $totalTestTime & ".")
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
	If $totalConnection = $maxConnections Then Return 0;Makes sure no more Connections can be made.
	Local $newSocket = TCPAccept($TCPListen)     ;Accepts incomming connections.
	If $newSocket < 0 Then Return 0

	Local $IP = SocketToIP($newSocket)
	Local $i = 0
	Local $port = 0
	Local $port0 = 0
	For $i = $maxConnections To 1 Step -1
		If $boxIP[$i] = $IP Then
			If $sockets[$i] > 0 Then
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
	If $port0 > $port Then $port = $port0

	If $boxIP[$port] <> $IP Then
		GUICtrlSetData($bGUI[$port], "new box")	; update the text on the button
		ClearCommands($port)
		PushCommand($port, "restarttest")	; if no name report after connection, let the client restart
		$logContent[$port] = ""	; clear the cheat sheet reading and previous content
	EndIf

	$sockets[$port] = $newSocket	;assigns that socket the incomming connection.
	$boxIP[$port] = $IP
	$flagOldClient[$port] = False	; assume every new box is new version until get a name request
	Return $port
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
	If $n > 0 Then
		TCPSend($sockets[$n], $command & " " & @CRLF)
		$err = @error
		If $err Then
			LogWrite($n, "Server" & @TAB & "Cannot send " & $command & " to client with connection error : " & $err )
			LogWrite($automationLogPort, $boxID[$n] & @TAB & "Connection lost with error : " & $err)
			CloseConnection($n)
		EndIf
	Else	; send the command to raspberry pi simulators
		If $piCommandHold Then Return

		If $socketRaspberryPi1 <= 0 Then
			$socketRaspberryPi1 = TCPConnect($ipRaspberryPi1, $portRaspberryPi)	; When RSP1 not connected, try to connect it
		EndIf

		If $socketRaspberryPi2 <= 0 Then
			$socketRaspberryPi2 = TCPConnect($ipRaspberryPi2, $portRaspberryPi)	; When RSP2 not connected, try to connect it
		EndIf

		If ($socketRaspberryPi1 < 0) And ($socketRaspberryPi2 < 0) Then
			LogWrite($automationLogPort, "Server" & @TAB & "Cannot connect to any Raspberry Pi Stimulator. " & $command & " was not sent.")
			Return
		EndIf

		$piCommandHold = True	; release the pi command hold
		$piHeartbeatTime = $time0 + $piHeartbeatInterval
		$commandID += 1
		If $commandID > 9 Then $commandID = 0
		If ($socketRaspberryPi1 > 0) Then
			If TCPSend($socketRaspberryPi1, $command & $commandID & " ") Then
				LogWrite($automationLogPort, "Server" & @TAB & "Sent " & $command & " to Raspberry Pi 1.")
			Else
				LogWrite($automationLogPort, "Server" & @TAB & "Connection to Raspberry Pi 1 lost. " & $command & " was not sent.")
				$socketRaspberryPi1 = -1
			EndIf
		EndIf

		If ($socketRaspberryPi2 > 0) Then
			If TCPSend($socketRaspberryPi2, $command & $commandID & " ") Then
				LogWrite($automationLogPort, "Server" & @TAB & "Sent " & $command & " to Raspberry Pi 2.")
			Else
				LogWrite($automationLogPort, "Server" & @TAB & "Connection to Raspberry Pi 2 lost. " & $command & " was not sent.")
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
