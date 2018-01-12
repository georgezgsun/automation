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
void delay(int milliseconds);

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
        exit;
    }

    memset(&serv_addr, 0, sizeof(serv_addr));
//    bzero((char *) &serv_addr, sizeof(serv_addr));

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
        exit;
    }
    listen(listenfd, 10);

    printf("Waiting for connection on port %d \r\n", port);
    socklen_t client = sizeof(cli_addr);
    connfd = 0;
    bool trigger = false;
    int tempfd = 0;
    string reply = "";
    GPIO_Handler * gpio = new GPIO_Handler();
    clock_t timeout = 0;
    int read_size = 0;
    int write_size = 0;
    bool received = false;
    string command = "";
    int num = 0;
    string id = "";

    bool testEnd = false;
    while(!testEnd)
    {
        tempfd = accept(listenfd, (struct sockaddr*)&cli_addr, &client);
        if (tempfd > 0)
        {
            printf("New Client connected @ %d\r\n", tempfd);
            if (connfd > 0)
            {
                printf("Closed the previous connection @ %d\r\n", connfd);
                close(connfd);
            }
            connfd = tempfd;
        }

        if (connfd > 0)
        {
            read_size = read(connfd, receiveBuff, 64);
            if (read_size > 0)
            {
                printf("Received command from the automation server: %s with size %d\n",receiveBuff,read_size);
                if (read_size > 10)
                {
                    testEnd = true;
                    printf("Change the test flag to true. \n");
                }
            }
            else
            {
                write_size = write(connfd, "Waiting for new command.", 24);
                printf(".");
            }

            if (read_size >= 3)
            {
                command = receiveBuff[0];
                num = receiveBuff[1]-48;
                id = receiveBuff[2];
                received = true;
                read_size = 0;

                reply = "";
                bool result = false;
                if (command == "t")
                {
                    switch (num) 
                    {
                        case 1 :
                            gpio->Enable_Trigger_1();
                            usleep(1000*1000);
                            gpio->Disable_Trigger_1();
                            reply = "OK";
                            break;
                        case 3 :
                            gpio->Enable_Trigger_2();
                            usleep(1000*1000);
                            gpio->Disable_Trigger_2();
                            reply = "OK";
                            break;
                        case 4 :
                            gpio->Enable_Trigger_3();
                            usleep(1000*1000);
                            gpio->Disable_Trigger_3();
                            reply = "OK";
                            break;
                        case 5 :
                            gpio->Enable_Trigger_4();
                            usleep(1000*1000);
                            gpio->Disable_Trigger_4();
                            reply = "OK";
                            break;
                        case 6 :
                            gpio->Enable_Trigger_5();
                            usleep(1000*1000);
                            gpio->Disable_Trigger_5();
                            reply = "OK";
                            break;
                        case 7 :
                            gpio->Enable_Trigger_6();
                            usleep(1000*1000);
                            gpio->Disable_Trigger_6();
                            reply = "OK";
                    }
                }

                if (command == "r")
                {
                    reply = "OK";
                }

                if (command == "m")
                {
                    switch (num) 
                    {
                        case 1 :
                            gpio->Enable_Mic_Trigger_1();
                            usleep(1000*1000);
                            gpio->Disable_Mic_Trigger_1();
                            reply = "OK";
                            break;
                        case 2 :
                            gpio->Enable_Mic_Trigger_2();
                            usleep(1000*1000);
                            gpio->Disable_Mic_Trigger_2();
                            reply = "OK";
                            break;
                    }
                }

                if (reply == "OK")
                {
                    printf("Trigger %s%d signal was sent sucessfully.\n", command, num);
                    reply = reply + receiveBuff[2]; 
                    std::copy(reply.begin(), reply.begin() + 3, sendBuff);
                    write_size = write(connfd, sendBuff, 3);
                    printf("Reply %s was sent.\n", sendBuff);
                }
                else                
                {
                    write_size = write(connfd, "Unknown command.", 16);
                    printf("Unknown command.\n");
                }
            } //end of size == 3
        } // end of connfd > 0
        else
        {
            printf("?");
        }
        usleep(100*1000);
    }

    printf("Test finished.\n");

    close(connfd);
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

void delay(int milliseconds)
{
    // Stroing start time
    clock_t start_time = clock();
 
    // looping till required time is not acheived
    while (clock() < start_time + milliseconds)
        ;
}
