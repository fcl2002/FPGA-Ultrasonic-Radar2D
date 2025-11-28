#include "sys/alt_stdio.h"
#include <stdio.h>
#include <unistd.h> // Para usleep
#include "io.h"     // Para IORD
#include "system.h" // Definições de endereço

int main()
{
    alt_putstr("=== Iniciando Teste do Radar 2D ===\n");

    while (1)
    {
        // Lê o registrador de 32 bits do IP
        alt_u32 data = IORD(TELEMETRE_US_AVALON_0_BASE, 0);

        // Separa os dados conforme a lógica do VHDL
        // Bits 0 a 9: Distância calculada pelo hardware (0-1023 cm)
        int dist_hardware = data & 0x3FF;

        // Bits 10 a 31: Contador Bruto (Ciclos de clock)
        int raw_cycles = data >> 10;

        float dist_precisa = (float)raw_cycles * 0.00034;

        printf("Dist : %d cm \n", dist_hardware/2, raw_cycles);

        // Delay de 200ms para facilitar a leitura
        usleep(200000);
    }

    return 0;
}
