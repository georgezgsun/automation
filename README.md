#The CopTrax automation triggers simulator
This is a project that uses raspberry pi to simulate triggers, RADAR signals, and audio signals for CopTrax automation test. 
##The triggers used for CopTrax automations are:
-Siren, 
-Light bar, 
-Aux 4, 
-Aux 5, 
-Aux 6, 
-start/stop, 
-ignition. 
##The simulated RADAR signals have two purposes. 
1. to tell the firmware on the CopTrax unit to disable the charging of the Lithium Battery. 
2. to simulate the target vechicle speed.

To achieve the simulation, 4 modules are prepared. 
1.The main or the centrer module will implement the central control of all the simulations. In brief, it get the instructions from the remote automation server on the intra networks. Then execute the instruction by output the required signals over the GPIOs and reply the results to the server. 
2.The radar module will simulate the RADAR signals. 
3.The audio module will play the pre-saved audio files. 
4.And the trigger module will output the trigger signals.

The proposal on the communication protocol between the automation server and raspberry pi are listed as followings.
-The Raspberry Pi simulator acts as the server in the TCP/IP Socket communication. It listens on the port 16869 for any connection from the automation server.
-The automation server tries to connect  the Raspberry Pi on it IP address and port 10.0.9.199:16869.
-When the connection is accepted by Raspberry Pi, both Raspberry Pi and the automation server store the socket for future communication.
-The commands the automation server sending to Raspberry Pi and the replies the Raspberry Pi sending back will always be three bytes, where the first two bytes are command and parameter, the third byte is the id. Any space character in the beginning will be consider as the separation between commands. For example, t11 m02 t33 …
-The command can be sent individually or in sequence in a TCP/IP packet. For example, TCPSend “t11” and TCPSend “t11 m02 t33” are all acceptable.
-The server sends the commands and does not wait for any instant replies. It will read the replies later.
-Raspberry Pi receives a packet, parses the command sequence from it, executes the commands in sequence one by one, and sends a reply after executing any commands.  
-The automation server will send heart beat command to Raspberry Pi every minute.
-In case the automation server does not receive any replies from Raspberry Pi for more than 2 mins, the automation server will consider the connection lost. It will try to setup another connect immediately.
###Recommended commands and parameters from the automation server to Raspberry Pi will be as followings: 
1. t1 - trigger the siren button 
2. t3 - trigger the light bar button 
3. t4 – trigger the Aux 4 button 
4. t5 – trigger the Aux 5 button 
5. t6 – trigger the Aux 6 button 
6. t7 – trigger the start/stop recording button 
7. m0 – stop playing audio file to the mic 
8. m1 – trigger the button on the microphone 
9. m2 … m9 play the corresponding audio file if any to the mic 
10. r0 – the firmware will stop charging the lithium ion battery 
11. r1 … r9 play the corresponding radar file if any to the RADAR port 
12. i0 – set the ignition switch to off 
13. i1 – set the ignition switch to on 
14. h0 .. h9 heart beat handshake signal only
###Recommended replies from the Raspberry Pi to automation server will be as followings: 
1. OK – The corresponding command (with the same ID)has been executed successfully. 
2. NO - The corresponding command (with the same ID)was not executed or something wrong.
This protocol is used for the communication between the automation server and Raspberry Pi only. The automation server will do the translation of human readable commands to this protocol. And the Raspberry Pi will do the translation of this protocol to the real action.
