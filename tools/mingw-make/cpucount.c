#include <windows.h>
#include <stdio.h>

int main(int argc, char* argv[])
{
    SYSTEM_INFO SystemInformation;

    if (argc == 1)
    {
        GetSystemInfo(&SystemInformation);
        printf("%ld\n", SystemInformation.dwNumberOfProcessors);
        return 0;
    }
    else if (!strcmp(argv[1], "-x2"))
    {
        GetSystemInfo(&SystemInformation);
        printf("%ld\n", (SystemInformation.dwNumberOfProcessors + SystemInformation.dwNumberOfProcessors));
        return 0;
    }
    else
    {
        printf("Unknown parameter specified. Exiting.\n");
        return 1;
    }
}
