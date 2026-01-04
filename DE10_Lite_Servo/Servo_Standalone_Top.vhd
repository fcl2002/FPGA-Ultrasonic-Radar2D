library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

-- Top Level para teste físico do Servo
-- Conecta:
--   CLOCK_50 -> Clock do IP
--   KEY(0)   -> Reset
--   SW(7..0) -> Posição (0 a 255)
--   GPIO(0)  -> Saída PWM para o Servo

entity Servo_Standalone_Top is
    port (
        MAX10_CLK1_50 : in  std_logic;
        KEY           : in  std_logic_vector(1 downto 0);
        SW            : in  std_logic_vector(9 downto 0);
        GPIO          : out std_logic_vector(35 downto 0)
    );
end entity Servo_Standalone_Top;

architecture Behavioral of Servo_Standalone_Top is

    component IP_Servomoteur is
        port (
            clk      : in  std_logic;
            rst_n    : in  std_logic;
            position : in  std_logic_vector(7 downto 0);
            commande : out std_logic
        );
    end component;

begin

    -- Instância do seu controlador
    U0 : IP_Servomoteur
        port map (
            clk      => MAX10_CLK1_50,
            rst_n    => KEY(0),       -- Botão direito é o Reset
            position => SW(7 downto 0), -- Switches 0 a 7 definem o ângulo
            commande => GPIO(0)       -- Pino GPIO[0] (PIN_V10) vai pro Servo
        );

end architecture Behavioral;