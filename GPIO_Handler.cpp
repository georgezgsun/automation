#include "GPIO_Handler.h"
#include <stdio.h>
GPIO_Handler::GPIO_Handler()
{
    Triggers.Data = 0;
    Power_Mic_Enables.Data = 0;

    Triggers_Bank = new GPIO_Bank(0x19);
    Triggers_Bank->Set_Configuration(0xC0);
    Triggers_Bank->Set_Outputs(Triggers.Data);
    Triggers_Bank->Set_Polarity(0x00);

    Power_Mic = new GPIO_Bank(0x1B);
    Power_Mic->Set_Configuration(0xF0);
    Power_Mic->Set_Outputs(Power_Mic_Enables.Data);
    Power_Mic->Set_Polarity(0x00);
}

GPIO_Handler::~GPIO_Handler()
{
}

void GPIO_Handler::Send_Triggers()
{
    Triggers_Bank->Set_Outputs(Triggers.Data);
    printf("Send triggers: %d\r\n",Triggers.Data);
}

void GPIO_Handler::Send_Power_Mic_Enables()
{
    Power_Mic->Set_Outputs(Power_Mic_Enables.Data);
}

void GPIO_Handler::Enable_Trigger_1()
{
    Triggers.Bits.Trigger1 = 1;
    Send_Triggers();
}

void GPIO_Handler::Disable_Trigger_1()
{
    Triggers.Bits.Trigger1 = 0;
    Send_Triggers();
}

void GPIO_Handler::Enable_Trigger_2()
{
    Triggers.Bits.Trigger2 = 1;
    Send_Triggers();
}

void GPIO_Handler::Disable_Trigger_2()
{
    Triggers.Bits.Trigger2 = 0;
    Send_Triggers();
}

void GPIO_Handler::Enable_Trigger_3()
{
    Triggers.Bits.Trigger3 = 1;
    Send_Triggers();
}

void GPIO_Handler::Disable_Trigger_3()
{
    Triggers.Bits.Trigger3 = 0;
    Send_Triggers();
}

void GPIO_Handler::Enable_Trigger_4()
{
    Triggers.Bits.Trigger4 = 1;
    Send_Triggers();
}

void GPIO_Handler::Disable_Trigger_4()
{
    Triggers.Bits.Trigger4 = 0;
    Send_Triggers();
}

void GPIO_Handler::Enable_Trigger_5()
{
    Triggers.Bits.Trigger5 = 1;
    Send_Triggers();
}

void GPIO_Handler::Disable_Trigger_5()
{
    Triggers.Bits.Trigger5 = 0;
    Send_Triggers();
}

void GPIO_Handler::Enable_Trigger_6()
{
    Triggers.Bits.Trigger6 = 1;
    Send_Triggers();
}

void GPIO_Handler::Disable_Trigger_6()
{
    Triggers.Bits.Trigger6 = 0;
    Send_Triggers();
}

void GPIO_Handler::Enable_Power()
{
    Power_Mic_Enables.Bits.Power = 1;
    Send_Power_Mic_Enables();
}

void GPIO_Handler::Disable_Power()
{
    Power_Mic_Enables.Bits.Power = 0;
    Send_Power_Mic_Enables();
}

void GPIO_Handler::Enable_Ignition()
{
    Power_Mic_Enables.Bits.Ignition = 1;
    Send_Power_Mic_Enables();
}

void GPIO_Handler::Disable_Ignition()
{
    Power_Mic_Enables.Bits.Ignition = 0;
    Send_Power_Mic_Enables();
}

void GPIO_Handler::Enable_Mic_Trigger_1()
{
    Power_Mic_Enables.Bits.Mic_Trigger_1 = 1;
    Send_Power_Mic_Enables();
}

void GPIO_Handler::Disable_Mic_Trigger_1()
{
    Power_Mic_Enables.Bits.Mic_Trigger_1 = 0;
    Send_Power_Mic_Enables();
}
void GPIO_Handler::Enable_Mic_Trigger_2()
{
    Power_Mic_Enables.Bits.Mic_Trigger_2 = 1;
    Send_Power_Mic_Enables();
}

void GPIO_Handler::Disable_Mic_Trigger_2()
{
    Power_Mic_Enables.Bits.Mic_Trigger_2 = 0;
    Send_Power_Mic_Enables();
}
