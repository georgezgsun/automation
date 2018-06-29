#include <iostream>
#include <pthread.h>
#include <sys/socket.h>
#include <arpa/inet.h>
#include <string.h>
#include <unistd.h>
#include "Radar_Simulator.h"
#include "Radar_Simulator_Thread.h"
#include "Audio_Thread.h"
#include "GPIO_Handler.h"
#include <time.h>

Radar_Simulator Radar;
GPIO_Handler Gpio_Handler;

using namespace std;

void Start_Radar_Thread(pthread_t * thread);
void Start_Audio_Thread(pthread_t * thread);

int main()
{
	pthread_t radar_thread, audio_thread;

	Start_Radar_Thread(&radar_thread);
	//Start_Audio_Thread(&audio_thread);

	int listenfd = 0;
	int connfd = 0;
	int port = 8080;
	struct sockaddr_in serv_addr,cli_addr;

	char sendBuff[64] = {0};
	char receiveBuff[64] = {0};

	listenfd = socket(AF_INET, SOCK_STREAM, 0);
	if (listenfd < 0)
	{
		printf("ERROR opening socket");
		exit(0);
	}

	//memset(&serv_addr, 0, sizeof(serv_addr));
	bzero((char *) &serv_addr, sizeof(serv_addr));

	// Set Address family = Internet, TCP/IP
	serv_addr.sin_family = AF_INET;
	// Set IP address to localhost
	serv_addr.sin_addr.s_addr = INADDR_ANY; //INADDR_ANY = 0.0.0.0
	// Set port number, using htons function to use proper byte order
	serv_addr.sin_port = htons(port);

	if (bind(listenfd, (struct sockaddr *) &serv_addr, sizeof(serv_addr)) < 0)
	{
		printf("ERROR on binding: sin_family = %u, sin_addr.s_addr = %u\n", AF_INET, htonl(INADDR_ANY));
		close(listenfd);
		exit(0);
	}
	listen(listenfd, 10);

	printf("Clocks in one second is %d. \r\n", CLOCKS_PER_SEC);
	printf("Waiting for connection on port %d \r\n", port);
	socklen_t client = sizeof(cli_addr);
	connfd = 0;
	bool trigger = false;
	int tempfd = 0;
	string reply = "";
	GPIO_Handler * gpio = new GPIO_Handler();
//	sleep(10);
	gpio->Enable_Power();
//	sleep(10);
	gpio->Enable_Ignition();
	Radar_Simulator * Radar = new Radar_Simulator();
    
	int read_size = 0;
	int write_size = 0;
	bool received = false;
	int command = 0;
	int num = 0;
	string id = "";
	char gpioreading;

	bool testEnd = false;
	while(!testEnd)
	{
		connfd = accept(listenfd, (struct sockaddr*)&cli_addr, &client);
		if (connfd <= 0)
			continue;

		printf("Got a new connection requist. The connection was successfully established as %d.\n", connfd);

		read_size = read(connfd, receiveBuff, 64);
		if (read_size <= 0)
		{
			close(connfd);
			continue;
		}
			
		printf("Received command from the automation server: %s with size %d\n",receiveBuff,read_size);

		if (read_size != 4)
		{
			write_size = write(connfd, "Unknown command.", 16);
			printf("Invalid command %s\n", receiveBuff);
			close(connfd);
			testEnd = (read_size > 10);
			continue;
		}

		command = (receiveBuff[0]-97) * 8 + receiveBuff[1] - 48;
		id = receiveBuff[2];
		read_size = 0;
		reply = "NO";
		switch (command)
		{
			case 153 :  // "t1"=(116-97)*8+1=153
				gpio->Enable_Trigger_1();
				usleep(1000*1000);
				gpio->Disable_Trigger_1();
				reply = "Siren";
				break;
			case 155 : // "t3"=(116-97)*8+3=155
				gpio->Enable_Trigger_2();
				usleep(1000*1000);
				gpio->Disable_Trigger_2();
				reply = "Light bar";
				break;
			case 156 :  // "t4"=(116-97)*8+4=156
				gpio->Enable_Trigger_3();
				usleep(1000*1000);
				gpio->Disable_Trigger_3();
				reply = "Aux 4";
				break;
			case 157 :  // "t5"=(116-97)*8+5=157
				gpio->Enable_Trigger_4();
				usleep(1000*1000);
				gpio->Disable_Trigger_4();
				reply = "Aux 5";
				break;
			case 158 :  // "t6"=(116-97)*8+6=158
				gpio->Enable_Trigger_5();
				usleep(1000*1000);
				gpio->Disable_Trigger_5();
				reply = "Aux 6";
				break;
			case 159 :  // "t7"=(116-97)*8+7=159
				gpio->Enable_Trigger_6();
				usleep(1000*1000);
				gpio->Disable_Trigger_6();
				reply = "Light switch";
				break;
			case 97 : // "m1"=(109-97)*8+1=97
				gpio->Enable_Mic_Trigger_1();
				usleep(1000*1000);
				gpio->Disable_Mic_Trigger_1();
				reply = "Mic 1";
				break;                    
			case 98 : // "m2"=(109-98)*8+1=98
				gpio->Enable_Mic_Trigger_2();
				usleep(1000*1000);
				gpio->Disable_Mic_Trigger_2();
				reply = "Mic 2";
				break;
			case 145 : // "r1"=(114-97)*8+1=145
				reply = "Radar";
				break;
			case 56 : // "h0"=(104-97)*8+0=56
				//gpioreading = gpio->Read_Inputs();
				//gpio->Disable_Mic_Trigger_2();
				reply = "Heartbeat";
				break;
			case 128 : // "q0"=(113-97)*8+0=128
				testEnd = true;
				reply = "quit";
				break;
		}

		if (reply != "NO")
		{
			printf("Trigger %s signal was executed.\n", receiveBuff);
			reply = reply + receiveBuff[2];
			std::copy(reply.begin(), reply.end(), sendBuff);
			write_size = write(connfd, sendBuff, 3);
			printf("Reply %s was sent.\n", sendBuff);
		}
		else
		{
			write_size = write(connfd, "Unknown command.", 16);
			printf("Unknown command %s.\n", receiveBuff);
		}

		sleep(5000);
		close(connfd);
		printf("Close current connection @%d, waiting for future connection.\n", connfd);
		
		Radar->Send_Radar_Data();
		sleep(10);
	}

	printf("Test finished.\n");

	close(listenfd);

	printf("Bye.\n");
	//    pthread_join(radar_thread,NULL);

	return 0;
} // end of main

void Start_Radar_Thread(pthread_t * thread)
{
    pthread_create( thread, NULL, Radar_Simulator_Thread, NULL);
}

void Start_Audio_Thread(pthread_t * thread)
{
    pthread_create(thread, NULL, Audio_Thread, NULL);
}
