library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity IP_Servo_Avalon is
    port (
        clk        : in  std_logic;
        reset_n    : in  std_logic;
        chipselect : in  std_logic;
        write_n    : in  std_logic;
        writedata  : in  std_logic_vector(31 downto 0);
        commande   : out std_logic
    );
end entity IP_Servo_Avalon;

architecture Behavioral of IP_Servo_Avalon is

    -- =============================================================
    -- CONFIGURAÇÃO PARA CLOCK DE 100 MHz (NIOS II SYSTEM)
    -- =============================================================
    constant CLK_FREQ       : integer := 100000000; -- 100 MHz
    constant PWM_FREQ       : integer := 50;        -- 50 Hz (Padrão Servo)
    
    -- O período total em ciclos: 100.000.000 / 50 = 2.000.000 ciclos
    constant PERIOD_CYCLES  : integer := CLK_FREQ / PWM_FREQ;

    -- Range Estendido: 0.5ms a 2.5ms
    -- 0.5ms = 0.0005 * 100.000.000 = 50.000 ciclos
    constant MIN_PULSE_CYCLES : integer := 50000;   
    
    -- Cálculo do Passo:
    -- Max (2.5ms) = 250.000 ciclos
    -- Delta = 250.000 - 50.000 = 200.000 ciclos
    -- Por degrau (8 bits): 200.000 / 255 = 784 ciclos
    constant CYCLES_PER_STEP  : integer := 784;

    -- Posição Inicial Segura: 128 (Meio)
    signal reg_position : std_logic_vector(7 downto 0) := std_logic_vector(to_unsigned(128, 8));

    signal pwm_counter : integer range 0 to PERIOD_CYCLES := 0;
    signal high_time   : integer range 0 to PERIOD_CYCLES := 0;

begin

    -- Calcula largura do pulso
    high_time <= MIN_PULSE_CYCLES + (to_integer(unsigned(reg_position)) * CYCLES_PER_STEP);

    -- Processo de Escrita via Avalon
    process(clk, reset_n)
    begin
        if reset_n = '0' then
            reg_position <= std_logic_vector(to_unsigned(128, 8)); -- Reset no Meio
        elsif rising_edge(clk) then
            if chipselect = '1' and write_n = '0' then
                reg_position <= writedata(7 downto 0);
            end if;
        end if;
    end process;

    -- Processo Gerador de PWM
    process(clk, reset_n)
    begin
        if reset_n = '0' then
            pwm_counter <= 0;
            commande    <= '0';
        elsif rising_edge(clk) then
            
            -- Contador de 0 até 2.000.000 (Garante 20ms exatos)
            if pwm_counter < PERIOD_CYCLES - 1 then
                pwm_counter <= pwm_counter + 1;
            else
                pwm_counter <= 0;
            end if;

            -- Comparador
            if pwm_counter < high_time then
                commande <= '1';
            else
                commande <= '0';
            end if;
        end if;
    end process;

end architecture Behavioral;