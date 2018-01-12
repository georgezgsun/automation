#include "GPIO_Bank.h"

class GPIO_Handler
{
    union
    {
        unsigned char Data;
        struct
        {
            char Trigger1:1;
            char Trigger2:1;
            char Trigger3:1;
            char Trigger4:1;
            char Trigger5:1;
            char Trigger6:1;
            char unused:2;
        }Bits;
    }Triggers;

    union
    {
        unsigned char Data;
        struct
        {
            char Power:1;
            char Ignition:1;
            char Mic_Trigger_1:1;
            char Mic_Trigger_2:1;
            char unused:4;
        }Bits;
    }Power_Mic_Enables;

    GPIO_Bank * Triggers_Bank;
    GPIO_Bank * Power_Mic;

    void Send_Triggers();
    void Send_Power_Mic_Enables();
public:
    GPIO_Handler();
    ~GPIO_Handler();
    void Enable_Trigger_1();
    void Disable_Trigger_1();
    void Enable_Trigger_2();
    void Disable_Trigger_2();
    void Enable_Trigger_3();
    void Disable_Trigger_3();
    void Enable_Trigger_4();
    void Disable_Trigger_4();
    void Enable_Trigger_5();
    void Disable_Trigger_5();
    void Enable_Trigger_6();
    void Disable_Trigger_6();
    void Enable_Power();
    void Disable_Power();
    void Enable_Ignition();
    void Disable_Ignition();
    void Enable_Mic_Trigger_1();
    void Disable_Mic_Trigger_1();
    void Enable_Mic_Trigger_2();
    void Disable_Mic_Trigger_2();
};
