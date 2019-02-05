#include "Radar_Simulator.h"
#include <termios.h>
#include <fcntl.h>
#include <strings.h>
#include <unistd.h>
#include <stdio.h>

const int Radar_Simulator::Format_B_Buffer_Size = 16;
const char Radar_Simulator::Format_B_Buffer[] = {0x81,0x77,0x44,'0','2','5','0','5','0','0','7','5','1','0','0',0x0D};
const char Radar_Simulator::Battery_Charger_Disable_Buffer[] = {'D'};
const int Radar_Simulator::Battery_Charger_Disable_Buffer_Size = 1;

Radar_Simulator::Radar_Simulator()
{
    Current_Transmitting_Format = eB_FORMAT;
    Open_Serial_Port();
}

Radar_Simulator::~Radar_Simulator()
{
    Close_Serial_Port();
}

void Radar_Simulator::Send_Radar_Data()
{
    // Always send the battery charger disable command.
    Write_Data_To_Serial_Port(Battery_Charger_Disable_Buffer,Battery_Charger_Disable_Buffer_Size);
    switch(Current_Transmitting_Format)
    {
        case eNONE: // Do nothing
            break;
        case eB_FORMAT: Write_Data_To_Serial_Port(Format_B_Buffer,Format_B_Buffer_Size);
            break;
        case eBE_FORMAT_1_ZONE:
            break;
        case eBE_FORMAT_2_ZONES:
            break;
        case eBE_FORMAT_3_ZONES:
            break;
        case eBE_FORMAT_4_ZONES:
            break;
        case eINVALID_FORMAT:
            break;
        default: Current_Transmitting_Format = eNONE;
            break;
    }
}

void Radar_Simulator::Set_Format_To_Send(TRANSMITTING_FORMAT format)
{
    Current_Transmitting_Format = format;
}

TRANSMITTING_FORMAT Radar_Simulator::Get_Format_Being_Sent()
{
    return Current_Transmitting_Format;
}

/* PRIVATE FUNCTIONS */
void Radar_Simulator::Open_Serial_Port()
{
    Serial_Handle = open( "/dev/serial0", O_RDWR | O_NONBLOCK);
    if(Serial_Handle < 0)
        printf("ERROR ON SERIAL\r\n");
    struct termios oldTermios, newTermios;
    
    tcgetattr(Serial_Handle, &oldTermios);
    bzero(&newTermios, sizeof(newTermios));
    
    newTermios = oldTermios;
    newTermios.c_iflag = 0;
    newTermios.c_oflag = 0;
    newTermios.c_cflag = CS8|CREAD|CLOCAL;
    newTermios.c_lflag = 0;
    newTermios.c_cc[VMIN] = 1;
    newTermios.c_cc[VTIME] = 5;
    
    cfsetispeed(&newTermios, B1200);
    cfsetospeed(&newTermios, B1200);
    cfmakeraw(&newTermios);
    
    tcflush(Serial_Handle, TCIOFLUSH);
    tcsetattr(Serial_Handle, TCSANOW, &newTermios);
}

void Radar_Simulator::Close_Serial_Port()
{

}

void Radar_Simulator::Write_Data_To_Serial_Port(const char * data, int data_size)
{
    write( Serial_Handle, data, data_size);
}
