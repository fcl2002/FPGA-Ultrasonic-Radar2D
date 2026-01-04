library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity DE10_Lite_Computer is
    Port (
        -- Clock pins
        CLOCK_50          : in  std_logic;
        CLOCK2_50         : in  std_logic;
        CLOCK_ADC_10      : in  std_logic;

        -- ARDUINO
        ARDUINO_IO        : inout std_logic_vector(15 downto 0);
        ARDUINO_RESET_N   : inout std_logic;

        -- SDRAM
        DRAM_ADDR         : out std_logic_vector(12 downto 0);
        DRAM_BA           : out std_logic_vector(1 downto 0);
        DRAM_CAS_N        : out std_logic;
        DRAM_CKE          : out std_logic;
        DRAM_CLK          : out std_logic;
        DRAM_CS_N         : out std_logic;
        DRAM_DQ           : inout std_logic_vector(15 downto 0);
        DRAM_LDQM         : out std_logic;
        DRAM_RAS_N        : out std_logic;
        DRAM_UDQM         : out std_logic;
        DRAM_WE_N         : out std_logic;

        -- Accelerometer
        G_SENSOR_CS_N     : out std_logic;
        G_SENSOR_INT      : in  std_logic_vector(2 downto 1);
        G_SENSOR_SCLK     : out std_logic;
        G_SENSOR_SDI      : inout std_logic;
        G_SENSOR_SDO      : inout std_logic;

        -- 40-Pin Headers
        GPIO              : inout std_logic_vector(35 downto 0);

        -- Seven Segment Displays
        HEX0              : out std_logic_vector(7 downto 0);
        HEX1              : out std_logic_vector(7 downto 0);
        HEX2              : out std_logic_vector(7 downto 0);
        HEX3              : out std_logic_vector(7 downto 0);
        HEX4              : out std_logic_vector(7 downto 0);
        HEX5              : out std_logic_vector(7 downto 0);

        -- Pushbuttons
        KEY               : in  std_logic_vector(1 downto 0);

        -- LEDs
        LEDR              : out std_logic_vector(9 downto 0);

        -- Slider Switches
        SW                : in  std_logic_vector(9 downto 0);

        -- VGA
        VGA_B             : out std_logic_vector(3 downto 0);
        VGA_G             : out std_logic_vector(3 downto 0);
        VGA_HS            : out std_logic;
        VGA_R             : out std_logic_vector(3 downto 0);
        VGA_VS            : out std_logic
    );
end entity;

architecture Behavioral of DE10_Lite_Computer is

    -- Sinais internos
    signal hex3_hex0 : std_logic_vector(31 downto 0);
    signal hex5_hex4 : std_logic_vector(15 downto 0);
    signal sdram_dqm : std_logic_vector(1 downto 0);
    
	 signal dummy_arduino : std_logic_vector(15 downto 0);
	 
    -- COMPONENTE ATUALIZADO (Incluindo Servo, Telemetre e UART)
    component Computer_System is
        port (
            arduino_gpio_export            : inout std_logic_vector(15 downto 0) := (others => 'X');
            arduino_reset_n_export         : out   std_logic;
            hex3_hex0_export               : out   std_logic_vector(31 downto 0);
            hex5_hex4_export               : out   std_logic_vector(15 downto 0);
            leds_export                    : out   std_logic_vector(9 downto 0);
            pushbuttons_export             : in    std_logic_vector(1 downto 0)  := (others => 'X');
            sdram_addr                     : out   std_logic_vector(12 downto 0);
            sdram_ba                       : out   std_logic_vector(1 downto 0);
            sdram_cas_n                    : out   std_logic;
            sdram_cke                      : out   std_logic;
            sdram_cs_n                     : out   std_logic;
            sdram_dq                       : inout std_logic_vector(15 downto 0) := (others => 'X');
            sdram_dqm                      : out   std_logic_vector(1 downto 0);
            sdram_ras_n                    : out   std_logic;
            sdram_we_n                     : out   std_logic;
            sdram_clk_clk                  : out   std_logic;
            slider_switches_export         : in    std_logic_vector(9 downto 0)  := (others => 'X');
            system_pll_ref_clk_clk         : in    std_logic                     := 'X';
            system_pll_ref_reset_reset     : in    std_logic                     := 'X';
            vga_CLK                        : out   std_logic;
            vga_HS                         : out   std_logic;
            vga_VS                         : out   std_logic;
            vga_BLANK                      : out   std_logic;
            vga_SYNC                       : out   std_logic;
            vga_R                          : out   std_logic_vector(3 downto 0);
            vga_G                          : out   std_logic_vector(3 downto 0);
            vga_B                          : out   std_logic_vector(3 downto 0);
            video_pll_ref_clk_clk          : in    std_logic                     := 'X';
            video_pll_ref_reset_reset      : in    std_logic                     := 'X';
            
            -- Portas do Seu Projeto
            telemetre_us_dist              : out   std_logic_vector(9 downto 0);
            telemetre_us_echo              : in    std_logic                     := 'X';
            telemetre_us_trig              : out   std_logic;
            
            -- Porta do Servo
            servo_pwm_writeresponsevalid_n : out   std_logic;

            -- [NOVO] Porta da UART (TX e RX)
            -- Nomes gerados pelo Qsys baseados em "uart_external" + nome do sinal interno
            uart_external_uart_rx          : in    std_logic                     := 'X';
            uart_external_uart_tx          : out   std_logic
        );
    end component Computer_System;

begin

    -- Controle da SDRAM
    DRAM_UDQM <= sdram_dqm(1);    
    DRAM_LDQM <= sdram_dqm(0);

    -- Controle dos Displays
    HEX0 <= not hex3_hex0(7 downto 0);
    HEX1 <= not hex3_hex0(15 downto 8);
    HEX2 <= not hex3_hex0(23 downto 16);
    HEX3 <= not hex3_hex0(31 downto 24);
    HEX4 <= not hex5_hex4(7 downto 0);
    HEX5 <= not hex5_hex4(15 downto 8);

    -- Instanciação do Sistema
    The_System : component Computer_System port map (
            system_pll_ref_clk_clk         => CLOCK_50,
            system_pll_ref_reset_reset     => '0',
            video_pll_ref_clk_clk          => CLOCK2_50,
            video_pll_ref_reset_reset      => '0',

            arduino_gpio_export            => dummy_arduino,
            arduino_reset_n_export         => ARDUINO_RESET_N,
            slider_switches_export         => SW,
            pushbuttons_export             => not KEY(1 downto 0),
            
            -- LEDs: Conectados ao Telemetre para visualização da distância
            leds_export                    => open, 
            
            hex3_hex0_export               => hex3_hex0,
            hex5_hex4_export               => hex5_hex4,

            -- VGA
            vga_CLK                        => open,
            vga_BLANK                      => open,
            vga_SYNC                       => open,
            vga_HS                         => VGA_HS,
            vga_VS                         => VGA_VS,
            vga_R                          => VGA_R,
            vga_G                          => VGA_G,
            vga_B                          => VGA_B,

            sdram_clk_clk                  => DRAM_CLK,
            sdram_addr                     => DRAM_ADDR,
            sdram_ba                       => DRAM_BA,
            sdram_cas_n                    => DRAM_CAS_N,
            sdram_cke                      => DRAM_CKE,
            sdram_cs_n                     => DRAM_CS_N,
            sdram_dq                       => DRAM_DQ,
            sdram_dqm                      => sdram_dqm, 
            sdram_ras_n                    => DRAM_RAS_N,
            sdram_we_n                     => DRAM_WE_N,

            -- CONEXÕES DO RADAR --
            
            -- 1. Telemetre (Sensor Ultrassom)
            telemetre_us_dist              => LEDR,       -- Visualizar distância nos LEDs
            telemetre_us_trig              => GPIO(1),    -- Pino W10 (JP1 Pino 2)
            telemetre_us_echo              => GPIO(3),    -- Pino W9  (JP1 Pino 4)
            
            -- 2. Servomotor
            servo_pwm_writeresponsevalid_n => GPIO(0),

            -- 3. UART (Serial para o PC)
            -- Conectamos nos primeiros pinos do Arduino Header
            uart_external_uart_rx          => ARDUINO_IO(0), -- RX (Recebe)
            uart_external_uart_tx          => ARDUINO_IO(1)  -- TX (Envia)
        );

end architecture;