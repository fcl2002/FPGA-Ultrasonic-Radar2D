#include <stdio.h>
#include <stdlib.h>
#include <math.h>
#include "system.h"
#include "io.h"
#include "alt_types.h"
#include "altera_up_avalon_video_dma_controller.h"

// ==========================================
// CONFIGURAÇÕES
// ==========================================
#define VIRTUAL_WIDTH    320
#define VIRTUAL_HEIGHT   240
#define VIRTUAL_CENTER_X 160
#define VIRTUAL_CENTER_Y 220
#define RADAR_RADIUS     180
#define MIN_DISTANCE     4
#define PI               3.14159265359

// Cores (RGB 565)
#define COLOR_BLACK 0x0000
#define COLOR_WHITE 0xFFFF
#define COLOR_GREEN 0x07E0
#define COLOR_RED   0xF800

// Hardware
#define PIXEL_BUF_CTRL_BASE VGA_SUBSYSTEM_VGA_PIXEL_DMA_BASE
#define CHAR_BUF_BASE       VGA_SUBSYSTEM_CHAR_BUF_SUBSYSTEM_ONCHIP_SRAM_BASE

alt_up_video_dma_dev *pixel_dma_dev;

// Escala Automática
int scale_factor = 1;
int screen_width_real = 320;
int screen_height_real = 240;

// ==========================================
// FUNÇÕES AUXILIARES
// ==========================================

void vga_clear_text() {
    int offset;
    for (offset = 0; offset < (80 * 60); offset++) {
        IOWR_8DIRECT(CHAR_BUF_BASE, offset, ' ');
    }
}

void vga_write_text(int x, int y, char *text_ptr) {
    unsigned int offset = (y << 7) + x;
    while (*text_ptr) {
        IOWR_8DIRECT(CHAR_BUF_BASE, offset, *text_ptr);
        text_ptr++;
        offset++;
    }
}

// Wrapper para Hardware Line com Escala
void draw_hardware_line(int x0, int y0, int x1, int y1, int color) {
    int rx0 = x0 / scale_factor;
    int ry0 = y0 / scale_factor;
    int rx1 = x1 / scale_factor;
    int ry1 = y1 / scale_factor;

    // Proteção de limites
    if (rx0 < 0) rx0 = 0; if (rx0 >= screen_width_real) rx0 = screen_width_real - 1;
    if (ry0 < 0) ry0 = 0; if (ry0 >= screen_height_real) ry0 = screen_height_real - 1;
    if (rx1 < 0) rx1 = 0; if (rx1 >= screen_width_real) rx1 = screen_width_real - 1;
    if (ry1 < 0) ry1 = 0; if (ry1 >= screen_height_real) ry1 = screen_height_real - 1;

    alt_up_video_dma_draw_line(pixel_dma_dev, color, rx0, ry0, rx1, ry1, 0);
}

// ==========================================
// FUNÇÕES PRINCIPAIS
// ==========================================

void init_vga() {
    pixel_dma_dev = alt_up_video_dma_open_dev("/dev/VGA_Subsystem_VGA_Pixel_DMA");
    if (pixel_dma_dev == NULL) {
        printf("ERRO: VGA Pixel DMA nao encontrado.\n");
        return;
    }

    // Auto-Detecção de Resolução
    volatile int *video_resolution = (int *)(PIXEL_BUF_CTRL_BASE + 0x8);
    screen_width_real = *video_resolution & 0xFFFF;
    screen_height_real = (*video_resolution >> 16) & 0xFFFF;

    if (screen_width_real == 160) scale_factor = 2;
    else scale_factor = 1;

    alt_up_video_dma_screen_clear(pixel_dma_dev, 0);
    vga_clear_text();

    // Desenha borda
    int prev_x = VIRTUAL_CENTER_X - RADAR_RADIUS;
    int prev_y = VIRTUAL_CENTER_Y;

    for(int angle = 180; angle >= 0; angle -= 5) {
        double rad = angle * PI / 180.0;
        int curr_x = VIRTUAL_CENTER_X - (int)(cos(rad) * RADAR_RADIUS);
        int curr_y = VIRTUAL_CENTER_Y - (int)(sin(rad) * RADAR_RADIUS);
        draw_hardware_line(prev_x, prev_y, curr_x, curr_y, COLOR_WHITE);
        prev_x = curr_x;
        prev_y = curr_y;
    }

    vga_write_text(25, 1, "RADAR ULTRASSONICO");
    vga_write_text(2, 57, "Dist: ");
    vga_write_text(2, 58, "Ang : ");
}

void update_radar_view(int angle, int distance) {
    if (pixel_dma_dev == NULL) return;

    static int last_dist_text = -1;
    char buf[30];

    // Clamping da distância
    int safe_dist = distance;
    if(safe_dist < MIN_DISTANCE) safe_dist = MIN_DISTANCE;
    if(safe_dist > RADAR_RADIUS) safe_dist = RADAR_RADIUS;

    double rad = angle * PI / 180.0;

    // Cálculo dos Pontos
    // Centro = (160, 220)
    // Objeto = Ponto onde a linha muda de verde para vermelho
    int obj_x = VIRTUAL_CENTER_X - (int)(cos(rad) * safe_dist);
    int obj_y = VIRTUAL_CENTER_Y - (int)(sin(rad) * safe_dist);

    // Borda = Final do radar
    int max_x = VIRTUAL_CENTER_X - (int)(cos(rad) * RADAR_RADIUS);
    int max_y = VIRTUAL_CENTER_Y - (int)(sin(rad) * RADAR_RADIUS);

    // ============================================================
    // DESENHAR O RAIO (Sem apagar o anterior!)
    // ============================================================

    // 1. Desenha a parte VERDE (Caminho livre até o objeto)
    // Isso vai SOBRESCREVER qualquer coisa que estava aqui antes (atualizando o mapa)
    draw_hardware_line(VIRTUAL_CENTER_X, VIRTUAL_CENTER_Y, obj_x, obj_y, COLOR_GREEN);

    // 2. Desenha a parte VERMELHA (Bloqueio ou espaço vazio atrás do objeto)
    // Só desenha se tiver espaço entre o objeto e a borda
    if (safe_dist < RADAR_RADIUS) {
        draw_hardware_line(obj_x, obj_y, max_x, max_y, COLOR_RED);
    }

    // ============================================================
    // ATUALIZAR TEXTO
    // ============================================================
    if (last_dist_text != distance) {
        if (distance >= RADAR_RADIUS) sprintf(buf, "--- cm   ");
        else sprintf(buf, "%3d cm   ", distance);
        vga_write_text(8, 57, buf);
        last_dist_text = distance;
    }

    sprintf(buf, "%3d deg  ", angle);
    vga_write_text(8, 58, buf);
}
