#include "Audio_Thread.h"
#include <stdlib.h>

void * Audio_Thread(void * argument)
{
    while(1)
    {
        system("aplay /home/pi/Music/piano2.wav");
    }
}
