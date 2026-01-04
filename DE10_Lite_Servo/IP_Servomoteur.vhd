library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

-- Controlador de Servomotor PWM (Faixa Estendida)
-- Clock Base: 50 MHz
-- Período: 20 ms (50 Hz)
-- Pulso Min (Pos 0):   0.5 ms
-- Pulso Max (Pos 255): 2.5 ms

entity IP_Servomoteur is
    port (
        clk      : in  std_logic;
        rst_n    : in  std_logic;
        position : in  std_logic_vector(7 downto 0); -- 0 a 255
        commande : out std_logic                     -- Sinal PWM
    );
end entity IP_Servomoteur;

architecture Behavioral of IP_Servomoteur is

    -- Constantes para 50 MHz
    constant CLK_FREQ       : integer := 50000000;
    constant PWM_FREQ       : integer := 50; -- 50 Hz (20 ms)
    constant PERIOD_CYCLES  : integer := CLK_FREQ / PWM_FREQ; -- 1.000.000 ciclos

    -- Limites ajustados para 0.5ms a 2.5ms
    constant MIN_PULSE_CYCLES : integer := 25000;   -- 0.5 ms
    
    -- Fator de multiplicação: (125000 - 25000) / 255 ≈ 392
    constant CYCLES_PER_STEP  : integer := 392;

    signal pwm_counter : integer range 0 to PERIOD_CYCLES := 0;
    signal high_time   : integer range 0 to PERIOD_CYCLES := 0;

begin

    -- Calcula a largura do pulso: Base (0.5ms) + (Posição * Passo)
    high_time <= MIN_PULSE_CYCLES + (to_integer(unsigned(position)) * CYCLES_PER_STEP);

    process(clk, rst_n)
    begin
        if rst_n = '0' then
            pwm_counter <= 0;
            commande    <= '0';
        elsif rising_edge(clk) then
            
            -- Contador principal de 0 a 1.000.000 (20ms)
            if pwm_counter < PERIOD_CYCLES - 1 then
                pwm_counter <= pwm_counter + 1;
            else
                pwm_counter <= 0;
            end if;

            -- Comparador PWM
            if pwm_counter < high_time then
                commande <= '1';
            else
                commande <= '0';
            end if;
            
        end if;
    end process;

end architecture Behavioral;