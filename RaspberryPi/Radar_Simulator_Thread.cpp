#include "Radar_Simulator_Thread.h"
#include "Radar_Simulator.h"
#include <unistd.h>

extern Radar_Simulator Radar;

void * Radar_Simulator_Thread(void * argument)
{
    while(1)
    {
        sleep(1);
        Radar.Send_Radar_Data();
    }
}

