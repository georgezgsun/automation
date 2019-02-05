#include "GPIO_Bank.h"
#include <wiringPiI2C.h>

GPIO_Bank::GPIO_Bank(unsigned char address)
{
    GPIO_file = wiringPiI2CSetup(address);
}

GPIO_Bank::~GPIO_Bank()
{

}

void GPIO_Bank::Set_Configuration(unsigned char selection)
{
    wiringPiI2CWriteReg8(GPIO_file,0x03,selection);
}

void GPIO_Bank::Set_Outputs(unsigned char selection)
{
    wiringPiI2CWriteReg8(GPIO_file,0x01,selection);
}

unsigned char GPIO_Bank::Read_Inputs()
{
    return (wiringPiI2CReadReg8(GPIO_file,0x00));
}

void GPIO_Bank::Set_Polarity(unsigned char selection)
{
    wiringPiI2CWriteReg8(GPIO_file,0x02,selection);
}
