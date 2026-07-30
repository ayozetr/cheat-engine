#include <stdio.h>
#include <unistd.h>

volatile int valor = 1234567;

int main(void) {
    FILE *f;
    f = fopen("/tmp/diana.pid", "w"); fprintf(f, "%d\n", getpid()); fclose(f);
    f = fopen("/tmp/diana.addr", "w"); fprintf(f, "%lX\n", (unsigned long)&valor); fclose(f);
    printf("diana pid=%d valor=%d en %p\n", getpid(), valor, (void*)&valor);
    fflush(stdout);
    for (;;) {
        sleep(1);
        printf("valor=%d\n", valor);
        fflush(stdout);
    }
    return 0;
}
