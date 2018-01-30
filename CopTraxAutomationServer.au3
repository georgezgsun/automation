#Region ;**** Directives created by AutoIt3Wrapper_GUI ****
#AutoIt3Wrapper_Res_Description=Automation test server
#AutoIt3Wrapper_Res_Fileversion=2.11.29.133
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
#include <GUIConstantsEx.au3>
#include <WindowsConstants.au3>
#include <ProgressConstants.au3>
#include <Misc.au3>

_Singleton('Automation test server')

HotKeySet("!{Esc}", "HotKeyPressed") ; Alt-Esc to stop testing

TCPStartup() ; Start the TCP service.

Global Const $maxConnections = 10	; define the max client numbers
Global Const $maxListen = 100	; define the max client numbers
Global Const $automationLogPort = $maxConnections + 1 ;define the automation log port
Global Const $piLogPort = 0 ;define the automation log port
Global $totalConnection = 0
Global $commandID = 0
Local $ipServer = @IPAddress1
Local $port = 16869
Local $ipRaspberryPi = TCPNameToIP("10.0.9.199")
Local $portRaspberryPi = 8080
Global $socketRaspberryPi = -1
Global $piCommandHold = False
Global $piHeartbeatTime = 0
Global $piHeartbeatInterval = 30 * 1000
Local $piTimeout = 0
Global $workDir = "C:\CopTraxTest\"

OnAutoItExitRegister("OnAutoItExit")	; Register OnAutoItExit to be called when the script is closed.
Global $TCPListen = TCPListen ($ipServer, $port, $maxListen)

Global $universalTestCaseFile = $workDir & "test_case.txt"
Global Const $maxCommands = 35
Global $allCommands[$maxCommands]
$allCommands[0] = "record duration repeat interval"
$allCommands[1] = "settings pre chunk cam2 cam3"
$allCommands[2] = "createprofile username password"
$allCommands[3] = "upload file"
$allCommands[4] = "update file"
$allCommands[5] = "checkapp version"
$allCommands[6] = "checkfirmware version"
$allCommands[7] = "checklibrary version"
$allCommands[8] = "batchtest mode"
$allCommands[9] = "pause duration"
$allCommands[10] = "checkrecord total newadd detailed"
$allCommands[11] = "radar speed"
$allCommands[12] = "lightbar duration"
$allCommands[13] = "siren duration"
$allCommands[14] = "aux4 duration"
$allCommands[15] = "aux5 duration"
$allCommands[16] = "aux6 duration"
$allCommands[17] = "lightswitch duration"
$allCommands[18] = "mic1trigger duration"
$allCommands[19] = "mic2trigger duration"
$allCommands[20] = "endrecord duration"
$allCommands[21] = "startrecord duration"
$allCommands[22] = "status"
$allCommands[23] = "photo"
$allCommands[24] = "info"
$allCommands[25] = "camera"
$allCommands[26] = "review"
$allCommands[27] = "synctime"
$allCommands[28] = "synctmz"
$allCommands[29] = "runapp"
$allCommands[30] = "stopapp"
$allCommands[31] = "cleanup"
$allCommands[32] = "quittest"
$allCommands[33] = "restarttest"
$allCommands[34] = "reboot"

MsgBox($MB_OK, "CopTrax Remote Test Server", "The universal test cases shall be in " & $universalTestCaseFile & @CRLF & "The server is " & $ipServer & ":" & $port, 5)

Global $sockets[$maxConnections + 1]
Global $logFiles[$maxConnections + 3]
Global $commands[$maxConnections + 1]
Global $commandTimers[$maxConnections + 1]
Global $connectionTimers[$maxConnections + 1]
Global $transFiles[$maxConnections + 1]
Global $byteCounter[$maxConnections + 1]
Global $fileToBeSent[$maxConnections + 1]
Global $heartBeatTimers[$maxConnections + 1]
Global $hGUI[$maxConnections + 3]
Global $gGUI[$maxConnections + 3]
Global $pGUI[$maxConnections + 1]
Global $nGUI[$maxConnections + 1]
Global $totalCommands[$maxConnections + 1]
Global $testEndTime[$maxConnections + 1]
Global $remainTestTime[$maxConnections + 1]
Global $offsetX[$maxConnections + 3]
Global $offsetY[$maxConnections + 3]
Global $testFailures[$maxConnections + 1]
Global $boxID[$maxConnections + 1]
Global $boxIP[$maxConnections + 1]
Global $batchWait[$maxConnections + 1]

Local $i
Global $connectionPattern = ""
For $i = 0 To $maxConnections
   $sockets[$i] = -1	; Stores the sockets for each client
   $connectionTimers[$i] = 0
   $commandTimers[$i] = 0
   $heartBeatTimers[$i] = 0
   $remainTestTime[$i] = 0
   $transFiles[$i] = ""
   $fileToBeSent[$i] = ""
   $batchWait[$i] = True	; default value is true, not to hold other box entering batch align mode
   $hGUI[$i] = 0
Next

For $i = 1 To 4
   Local $x = ($i - 1 - Floor(($i-1)/4)*3) * 480
   $offsetX[$i] = $x
   $offsetY[$i] = 0
   $offsetX[$i+6] = $x
   $offsetY[$i+6] = 360*2
Next
$offsetX[5] = $offsetX[1]
$offsetY[5] = 360
$offsetX[6] = $offsetX[4]
$offsetY[6] = 360
$offsetX[$automationLogPort] = $offsetX[2]
$offsetY[$automationLogPort] = 360
$offsetX[12] = $offsetX[3]
$offsetY[12] = 360			; arrage the 12 windows in the right places

; the window $automationLogPort will display the main test result
XPStyleToggle(1)
$hGUI[$automationLogPort] = GUICreate("Server " & $ipServer & ":" & $port, 480,360)
$gGUI[$automationLogPort] = GUICtrlCreateEdit("", 2, 2, 475, 355, $WS_VSCROLL)
GUICtrlSetFont($gGUI[$automationLogPort], 9, 400, 0, "Courier New")
GUISetState(@SW_SHOW)
WinMove($hGUI[$automationLogPort], "", $offsetX[$automationLogPort], $offsetY[$automationLogPort])
$logFiles[$automationLogPort] =FileOpen($workDir & "log\automationtest.log", 1+8) 	; Clear the client name for future updating from the client
$logFiles[$piLogPort] =FileOpen($workDir & "log\RaspberryPi.log", 1+8) 	; Clear the client name for future updating from the client

Opt("GUIOnEventMode", 1) ; Change to OnEvent mode
; the window 12 will display the test progress and time remains
$hGUI[12] = GUICreate("Automation Server", 480,360)
GUISetOnEvent($GUI_EVENT_CLOSE, "EndAutomation")
For $i = 1 To $maxConnections
	$pGUI[$i] = GUICtrlCreateProgress(105, 10 + ($i - 1) * 30, 360, 20)
	$nGUI[$i] =	GUICtrlCreateLabel("        ", 5, 13+ ($i - 1) * 30, 100, 20)
Next
$nGUI[0] = GUICtrlCreateLabel("Time remains", 240 - 130, 320, 150, 20)
GUICtrlSetFont($nGUI[0], 12, 400, 0, "Courier New")
$nGUI[0] = GUICtrlCreateLabel("00:00:00", 240, 320, 81, 18)
GUICtrlSetColor($nGUI[0], $COLOR_GREEN)
GUICtrlSetBkColor($nGUI[0], $COLOR_BLACK)
GUICtrlSetFont($nGUI[0], 12, 400, 0, "Courier New")
GUISetState(@SW_SHOW)
WinMove($hGUI[12], "", $offsetX[12], $offsetY[12])

Global $hTimer = TimerInit()	; global timer handle
Global $testEnd = False
Global $totalTestTime = 0
Global $batchAligned = False
Global $batchMode = False	; Not in batch mode until get a batch align command
Local $commandsRemains
Local $timeRemains
Local $progressPercentage
Local $lastEndTime = 0
Local $batchCheck = False
Local $tempTime
Local $tempPattern
While Not $testEnd
	AcceptConnection()	; accept new client's connection requist

	Local $Recv
	Local $currentTime = TimerDiff($hTimer)	; get current timer elaspe
	If $socketRaspberryPi <= 0 Then
		If $batchMode Then
			$socketRaspberryPi = TCPConnect($ipRaspberryPi, $portRaspberryPi)	; When not connected, try to connect
		EndIf

		If $socketRaspberryPi > 0 Then
			LogWrite($automationLogPort, "(Server) Raspberry Pi simulator connected.")
			LogWrite($piLogPort, "(Server) Raspberry Pi simulator connected.")
			MsgBox($MB_OK, "CopTrax Remote Test Server", "Raspberry Pi simulator connected.",2)
			$piTimeout = $currentTime + 2 * 60 * 1000
			$piHeartbeatTime = $currentTime + $piHeartbeatInterval
		EndIf
	Else
		$Recv = TCPRecv($socketRaspberryPi,10000)	; when connected, try to receive message
		If $Recv <> "" Then
			LogWrite($piLogPort, "(Raspberry Pi) Replied " & $Recv )
			$piTimeout = $currentTime + 2 * 60 * 1000
		EndIf

		If $currentTime > $piHeartbeatTime Then
			SendCommand(0, "h0")
			LogWrite($piLogPort, "(Server) Sent Raspberry Pi simulator heartbeat command.")
		EndIf

		If $currentTime > $piTimeout Then
			LogWrite($piLogPort, "(Server) Raspberry Pi simulator connection lost.")
			LogWrite($automationLogPort, "(Server) Raspberry Pi simulator connection lost.")
			MsgBox($MB_OK, "CopTrax Remote Test Server", "Raspberry Pi simulator connection lost.",2)
			$socketRaspberryPi = -1
		EndIf
	EndIf

	$batchCheck = True
	$totalConnection = 0
	$tempPattern = ""
	$lastEndTime = 0
	For $i = 1 To $maxConnections
		If $sockets[$i] <= 0 Then
			$tempPattern &= "o"
			ContinueLoop
		Endif

		$totalConnection += 1
		If $batchWait[$i] Then
			$tempPattern &= "+"
		Else
			$tempPattern &= "x"
		EndIf

		$Recv = TCPRecv($sockets[$i],1000000)
		If $Recv <> "" Then
			ProcessReply($i, $Recv)
			$connectionTimers[$i] = $currentTime + 2000*60 ; renew the connection check timer
		EndIf

		If ($currentTime > $commandTimers[$i]) And ParseCommand($i) Then	; check if it is time for next command, then execute the next test command
			$estimate = EstimateCommands($commands[$i])
			$commandsRemains = Int(GetParameter($estimate, "count"))
			$timeRemains = Round(($commandTimers[$i] - $currentTime) / 1000) + Int(GetParameter($estimate, "time"))	; next (command time- current time) in seconds plus the remain test time
			$testEndTime[$i] = $timeRemains + $currentTime/1000
			LogWrite($i, "(Server) " & $commandsRemains & " test commands remains. Next command in " & Int(($commandTimers[$i] - $currentTime) / 1000) & " seconds. Test remains " & $timeRemains & " seconds.")
			$progressPercentage = CorrectRange(100 * (1-$commandsRemains/$totalCommands[$i]), 0, 100)
			GUICtrlSetData($pGUI[$i], $progressPercentage)
		Else
			$timeRemains = $testEndTime[$i] - ($currentTime / 1000)
		EndIf

		If $timeRemains <> $remainTestTime[$i]	Then
			$remainTestTime[$i] = CorrectRange($timeRemains, 0, 3*24*3600)
			GUICtrlSetData($nGUI[$i], $boxID[$i] & " " & toHMS($remainTestTime[$i]))
		EndIf

		If ($currentTime > $heartBeatTimers[$i]) And ($currentTime < $commandTimers[$i] - 50*1000) Then ; check the heart-beat timer
			If $transFiles[$i] = "" Then	; This indicates there is no file transfer in-progress
				SendCommand($i, "heartbeat")	; send a command for heart_beat
				PushCommand($i, "hold")	; hold any new command from executing only after get a continue response from the client
				$heartBeatTimers[$i] = $currentTime + 60*1000;
				LogWrite($i, "(Server) Send heartbeat command to client.")
			Else
				$heartBeatTimers[$i] += 10 * 1000	; wait 10 more sec for end of file transfer
			EndIf
		EndIf

		If $currentTime > $connectionTimers[$i] Then	; test if the client is alive
			LogWrite($i, "(Server) No reply from the client. Connection to client lost.")
			LogWrite($automationLogPort, $boxID[$i] & " connection lost.")
			CloseConnection($i)
		EndIf

		If Not $batchWait[$i] Then	; If there is one not aligned
			$batchCheck = False
		EndIf

		If $timeRemains > $lastEndTime Then
            $lastEndTime = $timeRemains
        Endif
	Next
	If $connectionPattern <> $tempPattern Then
		$connectionPattern = $tempPattern
		LogWrite($automationLogPort, $connectionPattern)
		EndIf
	$batchAligned = $batchCheck

	If $tempTime <> $lastEndTime Then
		GUICtrlSetData($nGUI[0], toHMS($lastEndTime))
		$tempTime = $lastEndTime
	EndIf
WEnd

; SendCommand(0, "q0") ; let RaspberryPi to quit

OnAutoItExit()

Exit

Func EndAutomation()
	LogWrite($automationLogPort, "Automation test end by operator.")
	$testEnd = True;
EndFunc

Func CloseConnection($n)
	Local $s = "==================================="
	$s &= $s & $s
	LogWrite($n, $s)
	LogWrite($n, " ")
	; FileClose($logFiles[$n])	; Close the log file
	GUIDelete($hGUI[$n])
	TCPCloseSocket($sockets[$n])	; Close the TCP connection to the client
	$boxIP[$n] = ""
	$hGUI[$n] = 0
	$sockets[$n] = -1	; clear the soket index
	If $totalConnection > 0 Then
		$totalConnection -= 1 ; reduce the total number of connection
	EndIf
	$connectionTimers[$n] += 60*10000
EndFunc

Func ParseCommand($n)
	Local $newCommand = PopCommand($n)

	If $newCommand = "" Then 	; no command left to be precessed
		SendCommand($n, "quit")
		$testEndTime[$n] += 10
		Return False
	EndIf

	Local $nextCommandFlag = True
	Local $currentTime = TimerDiff($hTimer)
	$commandTimers[$n] =  $currentTime + 10*1000 ; time for next command to be executed

	Local $arg
	Local $duration
	Local $repeat
	Local $interval
	Switch $newCommand	; process the new command
		Case "record"
			$arg = PopCommand($n)
			$duration = CorrectRange(Int(GetParameter($arg, "duration")), 1, 999)
			$repeat = CorrectRange(Int(GetParameter($arg, "repeat")), 1, 99)
			$interval = Int(GetParameter($arg, "interval"))
			If $interval < 1 Or $interval > 10 Then $interval = 10

			Local $i
			For $i = 1 To $repeat
				PushCommand($n, "startrecord " & $duration & " endrecord " & $interval)
			Next

		Case "startrecord"
			SendCommand($n, $newCommand)
			$arg = PopCommand($n)
			$duration = Int($arg)
			PushCommand($n, "hold")
			$commandTimers[$n] += ($duration * 60 - 5) * 1000	; set the next command timer xx minutes later
			LogWrite($n, "")
			LogWrite($n, "(Server) Sent " & $newCommand & " command to client. The stop record command will be sent in " & $duration & " mins.")

		Case "endrecord"
			SendCommand($n, $newCommand)	; send new test command to client
			$arg = PopCommand($n)
			$interval = Int($arg)
			PushCommand($n, "hold")	; hold any new command from executing only after get a continue response from the client
			$commandTimers[$n] +=  ($interval * 60 - 15)* 1000	; set the next command timer 10 mins later
			LogWrite($n, "")
			LogWrite($n, "(Server) Sent " & $newCommand & " command to client. Pause for " & $interval & " mins till next command.")

		Case "settings", "createprofile", "upload"
			$arg = PopCommand($n)
			SendCommand($n, $newCommand & " " & $arg)	; send new test command to client
			PushCommand($n, "hold")	; hold any new command from executing only after get a continue response from the client
			LogWrite($n, "")
			LogWrite($n, "(Server) Sent " & $newCommand & " " & $arg & " command to client.")
			$commandTimers[$n] += 20*1000	; add 10 more seconds

		Case "checkfirmware", "checkapp", "checklibrary", "checkrecord"
			$arg = PopCommand($n)
			SendCommand($n, $newCommand & " " & $arg)	; send new test command to client
			PushCommand($n, "hold")	; hold any new command from executing only after get a continue response from the client
			LogWrite($n, "")
			LogWrite($n, "(Server) Sent " & $newCommand & " " & $arg & " command to client.")

		Case "pause"
			$arg = PopCommand($n)
			$commandTimers[$n] +=  (Int($arg) * 60 - 10)* 1000	; set the next command timer $arg2 mins later
			LogWrite($n, "")
			LogWrite($n, "(Server) Pause for " & $arg & " minutes.")

		Case "siren", "lightbar", "aux4", "aux5", "aux6", "lightswitch", "mic1trigger", "mic2trigger"
			$arg = PopCommand($n)
			local $duration = CorrectRange(Int($arg), 1, 60)
			Local $aCommand = "trigger"
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
				$aCommand = "lightswitch"
			Endif

			SendCommand(0, $piCommand)  ; send pi its command
			SendCommand($n, $aCommand)    ; send new test command to client
            LogWrite($n, "")
			LogWrite($n, "(Server) Sent " & $aCommand & " command to client. Sent " & $piCommand & " command to Raspberry Pi.")
			$commandTimers[$n] +=  ($duration * 60 - 10)* 1000    ; add $duration mins
			PushCommand($n, "hold")	; hold any new command from executing only after get a passed/continue response from the client
			$batchWait[$n] = False	; enter batchtest stop mode, stop any other box from entering aligned mode

		Case "review", "photo", "info", "status", "eof", "radar", "stopapp", "runapp", "camera"
			SendCommand($n, $newCommand)	; send new test command to client
			PushCommand($n, "hold")	; hold any new command from executing only after get a continue response from the client
			LogWrite($n, "")
			LogWrite($n, "(Server) Sent " & $newCommand & " command to client.")
			If ($newCommand = "checkrecord") Or ($newCommand = "camera") Then
				$commandTimers[$n] += 10*1000	; add 10 more seconds
			EndIf

		Case "cleanup", "quit", "reboot", "restart", "endtest", "restarttest", "quittest"
			SendCommand($n, $newCommand)	; send new test command to client
			LogWrite($n, "")
			LogWrite($n, "(Server) Sent " & $newCommand & " command to client.")

		Case "synctime"
			$arg = @YEAR & @MON & @MDAY & @HOUR & @MIN & @SEC
			SendCommand($n, $newCommand & " " & $arg)	; send new test command to client
			PushCommand($n, "hold")	; hold any new command from executing only after get a continue response from the client
			LogWrite($n, "")
			LogWrite($n, "(Server) Sent " & $newCommand & " " & $arg & " command to client.")

		Case "synctmz"
			Local $tmzarg = _Date_Time_GetTimeZoneInformation ( )
			$arg = $tmzarg[2]
			SendCommand($n, $newCommand & " " & $arg)	; send new test command to client
			PushCommand($n, "hold")	; hold any new command from executing only after get a continue response from the client
			LogWrite($n, "")
			LogWrite($n, "(Server) Sent " & $newCommand & " " & $arg & " command to client.")

		Case "update"
			Local $fileName = PopCommand($n)
			Local $file
            Local $netFileName
            Local $sourceFileName
            If StringInStr($filename, "\") Then
			    $netFileName = StringSplit($fileName, "\")
                $sourceFileName = $workDir & "latest\" & $netFileName[$netFileName[0]]    ; all file need to be update shall sit in \latest folder
            Else
                $sourceFileName = $workDir & "latest\" & $fileName
            Endif

			$file = FileOpen($sourceFileName,16)	; open file for read only in binary mode
			$fileToBeSent[$n] = FileRead($file)
			FileClose($file)
            ;Local $fLen = StringLen($fileToBeSent[$n]) ;
			;If $fLen < 10000 Then $fLen = BinaryLen($fileToBeSent[$n])
			Local $fLen = BinaryLen($fileToBeSent[$n])
			$newCommand &= " " & $fileName & " " & $fLen
			SendCommand($n, $newCommand)	; send new test command to client
			LogWrite($n, "")
			LogWrite($n, "(Server) Sent " & $newCommand & " command to client.")
			LogWrite($n, "(Server) Sending " & $sourceFileName & " in server to update " & $fileName & " in client.")
			PushCommand($n, "hold send hold")	; hold any new command from executing only after get a continue response from the client

		Case "send"
			SendCommand($n, $fileToBeSent[$n])	; send file to client
			LogWrite($n,"(Server) File sent to client.")

		Case "hold"
			PushCommand($n, "hold")	; the hold command can only be cleared by receive a contiue or passed reply from the client
			$commandTimers[$n] += -5*1000
			$testEndTime[$n] += 5
			$nextCommandFlag = False

		Case "batchhold"
			If $batchAligned Then
				LogWrite($n, "(Server) All clients aligned.")
			Else
				PushCommand($n, "batchhold")	; the batchhold command can only be cleared by all active clients entering batch wait mode
			EndIf
			$testEndTime[$n] += 5
			$nextCommandFlag = False

		Case "batchtest"
			$arg = StringLower(PopCommand($n))
			LogWrite($n, "")
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
				LogWrite($automationLogPort, "(Server) " & $boxID[$i] & " enter batch test mode.")
				$batchWait[$n] = False
				$batchMode = True
			EndIf

			If $arg = "stop" Then
				LogWrite($n, "(Server) Enter stop batch test mode, disabled all other later boxes from achieving align mode.")
				If $socketRaspberryPi Then
					TCPCloseSocket($socketRaspberryPi)
				EndIf
				$socketRaspberryPi = -1
				$batchWait[$n] = False
				$batchAligned = False
				$batchMode = False
			EndIf

		Case Else
			LogWrite($n, "Unknown command " & $newCommand)
			$nextCommandFlag = False

	EndSwitch
	Return $nextCommandFlag
EndFunc

Func LogWrite($n,$s)
	If $n <= $maxConnections + 1 Then _FileWriteLog($logFiles[$n],$s)
	GUICtrlSetData($gGui[$n], $s & @crlf, 1)
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
	For $i = $maxCommands-5 To $maxCommands - 1
		$endofTestCase &= $allCommands[$i]
	Next

    Do
        $aLine = FileReadLine($testFile)
		If @error < 0 Then ExitLoop

        $aLine = StringRegExpReplace($aLine, "([;].*)", "")
		$aLine = StringRegExpReplace($aLine, "([//].*)", "")
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
    Local $repeat = 1
    Local $interval = 10
    Local $parameters = ""
    Local $testTime = 0
    Local $i
    Local $j

    For $i = 1 To $commandList[0] - 1	; there is a apce in the end
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
            $repeat = CorrectRange(Int(GetParameter($parameters, "repeat")), 1, 99)
            $interval = Int(GetParameter($parameters, "interval"))
            If $interval < 1 Or $interval > 10 Then $interval = 10
            $count += 2*$repeat - 1
            $testTime += $repeat * ($duration + $interval) * 60
        Else
            If StringInStr($allCommands[$j], "duration") > 4 Then
                $parameters = $commandList[$i+1]
                $duration = CorrectRange(Int(GetParameter($parameters, "duration")), 1, 999)
                $testTime += $duration * 60
            Else
                $testTime += 20
            Endif
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
		If $parameter = "" Then Return "NULL"
		If StringInStr($parameter[0], "=") Then
			Return StringRegExpReplace($parameter[0], "(" & $keywords[2] & "=)", "")
		Else
			Return $parameter[0]
		EndIf
	EndIf

	Local $parameters = ""
	For $i = 2 To $keywords[0]
		$parameter = StringRegExp($line, "(?i)(?:\s)(" & $keywords[$i] & "=.[^\s]*)", $STR_REGEXPARRAYMATCH)
		If $parameter <> "" Then
			$parameters &= $parameter[0] & "|"
		EndIf
	Next

	If $parameters = "" Then
		Return "NULL"
	Else
		Return StringRegExpReplace($parameters, "\|$", "")
	EndIf
EndFunc

Func GetParameter($parameters, $keyword)
	If StringInStr($parameters, "=") Then
		Local $parameter = StringRegExp($parameters, "(?:" & $keyword & "=)([a-zA-Z0-9:_\\\.\-]+)", $STR_REGEXPARRAYMATCH)
		If IsArray($parameter) Then
			Return $parameter[0]
		Else
			Return ""
		EndIf
	Else
		Return $parameters
	EndIf
EndFunc

Func ProcessReply($n, $reply)
	Local $msg = StringSplit($reply, " ")
	Local $len
	If $transFiles[$n] <> "" Then	; This indicates the coming message shall be saved in file
		FileWrite($transFiles[$n], $reply)
		;$len = StringLen($reply)
		$len = BinaryLen($reply)
		LogWrite($n, "(Server) Received " & $len & " bytes, write them to file.")
		$byteCounter[$n] -= $len

		If $byteCounter[$n] <= 5 Then
			FileClose($transFiles[$n])	; get and save the file
			$transFiles[$n] = ""	;clear the flag when file transfer ends
			SendCommand($n, "eof")	; send "eof" command to client
			LogWrite($n,"(Server) Send eof to client.")
		EndIf
		Return
	EndIf

	If StringLen($reply) < 10 Then
		LogWrite($n, "(Client) Sent " & $reply & " message to server. ")	; write the returned results into the log file
	Else
		LogWrite($n, "(Client) " & $reply)	; write the returned results into the log file
	EndIf

	Switch StringLower($msg[1])
		Case "file"
			If $msg[0] <3 Then
                LogWrite($n, "(Server) Unknown reply from server")
                Return
            Endif

			Local $fileName = $msg[2]
			Local $len =  Int($msg[3])
			Local $netFileName = StringSplit($fileName, "\")
			Local $destFileName = $workDir & "ClientFiles\" & $netFileName[$netFileName[0]]
			LogWrite($n, "(Server) " & $fileName & " from client is going to be saved as " & $destFileName & " in server.")
			LogWrite($n, "(Server) Total " & $len & " bytes need to be stransfered.")
			$transFiles[$n] = FileOpen($destFileName,16+8+2)	; open file for over-write and create the directory structure if it doesn't exist
			$byteCounter[$n] = $len
			PushCommand($n,"hold")
			SendCommand($n, "send")	; send "send" command to client to trigger the file transfer
			LogWrite($n, "(Server) sent send command to client.")

		Case "name"
			If $msg[0] < 4 Then
				LogWrite($n, "(Server) Unknown reply from server")
				Return
			Endif
			$boxID[$n] = $msg[2]	; get the boxID from client
			Local $filename = $workDir & "log\" & $boxID[$n] & ".log"
			$logFiles[$n] = FileOpen($filename, 1+8) ; open log file for append write in text mode
			Local $boxUser = $msg[3]	; get the CopTrax App current username

			LogWrite($automationLogPort, $boxID[$n] & " connected on " & $boxIP[$n] & ".")

			If $hGUI[$n] <> 0 Then
				GUIDelete($hGUI[$n])
			EndIf
			$hGUI[$n] = GUICreate($boxID[$n], 480,360)
			$gGUI[$n] = GUICtrlCreateEdit("", 2, 2, 475, 355, $WS_VSCROLL)
			GUICtrlSetFont($gGUI[$n], 9, 400, 0, "Courier New")
			GUISetState(@SW_SHOW)
			WinMove($hGUI[$n], "", $offsetX[$n], $offsetY[$n])
			GUICtrlSetData($nGUI[$n], $boxID[$n] & " testing")

			$filename = $workdir & $boxID[$n] & ".txt"	; try to find if any individual test case exits
			If Not FileExists($filename) Then
                $filename = $universalTestCaseFile
            Endif
            $commands[$n] = ReadTestCase($filename)	; Read test case from file
            If $commands[$n] = "" Then
                PushCommand($n, "synctmz")
                PushCommand($n, "synctime")
                PushCommand($n, "status")
            EndIf
            Local $estimate = EstimateCommands($commands[$n])
            Local $commandsNumber = Int(GetParameter($estimate, "count"))
            $totalTestTime = Floor(Int(GetParameter($estimate, "time")) /60) + 1

			Local $splitChar = "==================================="
			$splitChar &= $splitChar & $splitChar
			LogWrite($n, " ")
			LogWrite($n, $splitChar)
			LogWrite($n, " Automation test for CopTrax DVR box " & $boxID[$n])
			LogWrite($n, " Current version of the test server : " & FileGetVersion ( @ScriptFullPath ))

			Local $clientVersion = $msg[4]	; get the automation client version
			Local $latestVersion = FileGetVersion($workDir & "latest\CopTraxAutomationClient.exe")
			If _VersionCompare($clientVersion, $latestVersion) < 0 Then
				PushCommand($n, "update C:\CopTraxAutomation\tmp\CopTraxAutomationClient.exe restart restarttest")	; add two restart in purpose
				LogWrite($n, "Find latest automation tester in Server. Updating client to " & $latestVersion & ". Test will restart.")
			Else
				LogWrite($n, "The latest automation test app version is " & $latestVersion & ". App in client is up-to-date.")
			EndIf

			If Not StringRegExp($boxID[$n], "[A-Za-z]{2}[0-9]{6}")  Then
				PushCommand($n, "reboot")	; seems there exists mis-matching problems in the client box, reboot to fix it
				LogWrite($automationLogPort, $boxID[$n] & " firmware error. Cannot read serial number.")
				LogWrite($n, $boxID[$n] & " firmware error. Cannot read serial number.")
			EndIf
			GUICtrlSetColor($nGUI[$n], $COLOR_BLACK)
			GUICtrlSetColor($pGUI[$n], $COLOR_BLUE)

            LogWrite($n, " Test case is read from " & $filename)
            LogWrite($n, " - " & $commands[$n])
			LogWrite($n, " Number of test commands: " & $commandsNumber & ". Estimated test time in minutes: " & $totalTestTime & ".")
			LogWrite($n, $splitChar)
			LogWrite($n, "(Client) " & $reply)	; write the returned results into the log file
			LogWrite($automationLogPort, "START AUTOMATION TEST for CopTrax DVR " & $boxID[$n])
			LogWrite($automationLogPort, $boxID[$n] & " Number of test commands: " & $commandsNumber & ". Estimated test time in minutes: " & $totalTestTime & ".")
			$totalCommands[$n] = $commandsNumber
	EndSwitch

	If StringInStr(StringLower($reply), "failed") Then
		PopCommand($n)	; unhold the test command by pop the hold command
		$testFailures[$n] += 1
		GUICtrlSetColor($nGUI[$n], $COLOR_RED)
		GUICtrlSetColor($pGUI[$n], $COLOR_RED)
		LogWrite($automationLogPort, $boxID[$n] & " " & $reply)
		Return
	EndIf

	If StringInStr(StringLower($reply), "fatal") Then
		$testFailures[$n] += 1
		GUICtrlSetColor($nGUI[$n], $COLOR_RED)
		GUICtrlSetColor($pGUI[$n], $COLOR_RED)

		PushCommand($n, "hold reboot")	; seems there exists mis-matching problems in the client box, reboot to fix it
		LogWrite($automationLogPort, $boxID[$n] & " firmware error. Cannot read serial number.")
		LogWrite($n, $boxID[$n] & " firmware error. Cannot read serial number.")
		Return
	EndIf

	If StringInStr(StringLower($reply), "quit") Then
		If StringLen($commands[$n]) > 5 Then
			LogWrite($automationLogPort, $boxID[$n] & " Tests will restart.")
			GUICtrlSetData($nGUI[$n], $boxID[$n] & " restart")
		Else
			If $testFailures[$n] = 0 Then
				LogWrite($n, "All tests passed.")
				LogWrite($automationLogPort, "All tests passed.")
				LogWrite($automationLogPort, "END AUTOMATION TEST for CopTrax DVR " & $boxID[$n])
				GUICtrlSetColor($pGUI[$n], $COLOR_GREEN)
				GUICtrlSetData($nGUI[$n], $boxID[$n] & " PASSED")
			Else
				LogWrite($n, "Tests failed with " & $testFailures[$n] & " failures.")
				LogWrite($automationLogPort, "Tests failed with " & $testFailures[$n] & " failures.")
				LogWrite($automationLogPort, $boxID[$n] & " ALL TESTS DID NOT PASS.")
				GUICtrlSetData($nGUI[$n], $boxID[$n] & " FAILED")
			EndIf
			$testEndTime[$n] = 0
		EndIf
		CloseConnection($n)
		Return
	EndIf

	If StringInStr(StringLower($reply), "passed") Or StringInStr(StringLower($reply), "continue") Then
		PopCommand($n)	; unhold the test command by pop the hold command
	EndIf

	$testEnd = (GUIGetMsg() = $GUI_EVENT_CLOSE)
EndFunc

Func OnAutoItExit()
   TCPShutdown() ; Close the TCP service.
   Local $i
   For $i = 0 To $maxConnections
	  If $logFiles[$i] <> 0 Then
		 FileClose($logFiles[$i])
		 $logFiles[$i] = 0
	  EndIf
   Next
   FileClose($logFiles[$automationLogPort])
   FileClose($logFiles[$piLogPort])
EndFunc   ;==>OnAutoItExit

Func AcceptConnection ()
	If $totalConnection = $maxConnections Then Return	;Makes sure no more Connections can be made.
	Local $Accept = TCPAccept($TCPListen)     ;Accepts incomming connections.
	If $Accept < 0 Then Return

	Local $IP = SocketToIP($Accept)
	Local $currentTime = TimerDiff($hTimer)
	Local $i = 0
	Local $port = 0
	For $i = $maxConnections To 1 Step -1
		If $boxIP[$i] = $IP Then
			If $sockets[$i] > 0 Then
				TCPCloseSocket($sockets[$i])
				$sockets[$i] = -1
			EndIf

			$port = $i
			ExitLoop
		EndIf
		If $sockets[$i] < 0 Then	;Find the first open socket.
			$port = $i
		EndIf
	Next

	$sockets[$port] = $Accept	;assigns that socket the incomming connection.
	$logFiles[$port] = ""	; Clear the client name for future updating from the client
	$commands[$port] = "hold"	; Stores hold command to temperally hold the the commands until gets a name reply
	$heartBeatTimers[$port] = $currentTime + 1000*60
	$commandTimers[$port] = $currentTime + 1000	; Set command timer to be 1s later
	$connectionTimers[$port] = $currentTime + 2000*60	; Set connection lost timer to be 2mins later
	$totalConnection += 1   ;adds one to the Socket list.
	$testFailures[$port] = 0	; initialize the result true until any failure
	$transFiles[$port] = ""
	$fileToBeSent[$port] = ""
	$boxIP[$port] = $IP
	$batchWait[$port] = True	; Default is true, not to hold other boxes until was set by BatchTest mode=start
EndFunc

Func PopCommand($n)
   Local $newCommand = StringSplit(StringLower($commands[$n]), " ")
   If $newCommand[0] > 1 Then
	  Local $lengthCommand = StringLen($newCommand[1] & " ")
	  $commands[$n] = StringTrimLeft($commands[$n],$lengthCommand)
	  return $newCommand[1]
   Else
	  return ""
   EndIf
EndFunc

Func PushCommand($n, $newCommand)
   $commands[$n] = $newCommand & " " & $commands[$n]
EndFunc

Func SendCommand($n, $command)
	If $n > 0 Then
		TCPSend($sockets[$n], $command)
		$heartBeatTimers[$n] = TimerDiff($hTimer) + 60 * 1000
	Else
		If $socketRaspberryPi < 0 Then
			LogWrite($automationLogPort, "(Server) Raspberry Pi not connected yet. " & $command & " was not sent.")
			Return
		EndIf

		If ($command = "h0") Or ($command = "q0") Then
			$piCommandHold = False
		EndIf

		If $piCommandHold Then
			LogWrite($piLogPort, "(Server) Raspberry Pi hold the duplicated " & $command & ".")
			Return
		EndIf

		$piHeartbeatTime = TimerDiff($hTimer) + $piHeartbeatInterval;
		$commandID += 1
		If $commandID > 9 Then $commandID = 0
		If TCPSend($socketRaspberryPi, $command & $commandID & " ") = 0 Then
			LogWrite($piLogPort, "(Server) Connection to Raspberry Pi was lost.")
			$socketRaspberryPi = 0
		Else
			LogWrite($piLogPort, "(Server) Sent " & $command & " to Raspberry Pi.")
			$piCommandHold = ($command <> "h0")
		EndIf
		$piHeartbeatTime = TimerDiff($hTimer) + $piHeartbeatInterval;
	EndIf
EndFunc

Func HotKeyPressed()
   Switch @HotKeyPressed ; The last hotkey pressed.
	  Case "!{Esc}" ; KeyStroke is the {ESC} hotkey. to stop testing and quit
	  $testEnd = True	;	Stop testing marker

    EndSwitch
 EndFunc   ;==>HotKeyPressed

Func SocketToIP($iSocket)
    Local $tSockAddr = 0, $aRet = 0
    $tSockAddr = DllStructCreate("short;ushort;uint;char[8]")
    $aRet = DllCall("Ws2_32.dll", "int", "getpeername", "int", $iSocket, "struct*", $tSockAddr, "int*", DllStructGetSize($tSockAddr))
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
