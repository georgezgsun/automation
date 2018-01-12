#include <termios.h>

enum TRANSMITTING_FORMAT{ eNONE = 0, eB_FORMAT, eBE_FORMAT_1_ZONE, eBE_FORMAT_2_ZONES,eBE_FORMAT_3_ZONES, eBE_FORMAT_4_ZONES, eINVALID_FORMAT };

class Radar_Simulator
{
    TRANSMITTING_FORMAT Current_Transmitting_Format;
    static const char Format_B_Buffer[];
    static const int Format_B_Buffer_Size;
    static const char Format_BE_1_Zone_Buffer[];
    static const int Format_BE_1_Zone_Buffer_Size;
    static const char Format_BE_2_Zone_Buffer[];
    static const int Format_BE_2_Zone_Buffer_Size;
    static const char Format_BE_3_Zone_Buffer[];
    static const int Format_BE_3_Zone_Buffer_Size;
    static const char Format_BE_4_Zone_Buffer[];
    static const int Format_BE_4_Zone_Buffer_Size;
    static const char Invalid_Format_Buffer[];
    static const int Invalid_Format_Buffer_Size;
    static const char Battery_Charger_Disable_Buffer[];
    static const int Battery_Charger_Disable_Buffer_Size;
    int Serial_Handle;

    void Open_Serial_Port();
    void Close_Serial_Port();
    void Write_Data_To_Serial_Port(const char * data, int data_size);

public:
    Radar_Simulator();
    ~Radar_Simulator();
    void Send_Radar_Data();
    void Set_Format_To_Send(TRANSMITTING_FORMAT format);
    TRANSMITTING_FORMAT Get_Format_Being_Sent();
};
