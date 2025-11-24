library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

-- Banc de test pour l’IP Telemetre_IP_Standalone
-- Objectif : simuler un signal ECHO correspondant à une distance connue
-- et vérifier la valeur de dist_cm en sortie.

entity Telemetre_IP_Standalone_TB is
end entity;

architecture Behavioral of Telemetre_IP_Standalone_TB is

    -- Composant à tester (Unit Under Test)
    component Telemetre_IP_Standalone is
        port (
            clk      : in  std_logic;
            rst_n    : in  std_logic;
            echo     : in  std_logic;
            trig     : out std_logic;
            dist_cm  : out std_logic_vector(9 downto 0)
        );
    end component;

    -- Signaux internes du testbench
    signal clk_tb     : std_logic := '0';
    signal rst_n_tb   : std_logic := '0';
    signal echo_tb    : std_logic := '0';
    signal trig_tb    : std_logic;
    signal dist_tb    : std_logic_vector(9 downto 0);

    -- Constantes pour la simulation
    constant CLK_PERIOD    : time := 20 ns;      -- 50 MHz
    constant DIST_CM_TEST  : integer := 100;     -- Distance simulée = 100 cm
    -- Durée correspondante du signal ECHO :
    -- 1 cm ≈ 58 µs → 100 cm = 5800 µs = 5,8 ms
    constant ECHO_TIME_150 : time := 8700 us;
	 constant ECHO_TIME_100 : time := 5800 us;
	 constant ECHO_TIME_50  : time := 2900 us;

begin

    --------------------------------------------------------------------
    -- Génération de l’horloge 50 MHz
    --------------------------------------------------------------------
    clk_process : process
    begin
        clk_tb <= '0';
        wait for CLK_PERIOD/2;
        clk_tb <= '1';
        wait for CLK_PERIOD/2;
    end process;


    --------------------------------------------------------------------
    -- Instanciation de l’UUT
    --------------------------------------------------------------------
    UUT : Telemetre_IP_Standalone
        port map (
            clk     => clk_tb,
            rst_n   => rst_n_tb,
            echo    => echo_tb,
            trig    => trig_tb,
            dist_cm => dist_tb
        );


    --------------------------------------------------------------------
    -- Processus de stimulation
    --------------------------------------------------------------------
    stim_proc : process
    begin
        
        -- 1) Reset initial
        rst_n_tb <= '0';
        wait for 200 ns;
        rst_n_tb <= '1';

        -- Attente d’un premier cycle TRIG généré par l’UUT
        wait for 3 ms;

        -- 2) Première mesure : obstacle à 150 cm
        echo_tb <= '1';
        wait for ECHO_TIME_150;
        echo_tb <= '0';

        -- Attente pour laisser le temps au calcul de distance
        wait for 80 ms;
		  
		  -- 3) Deuxième mesure : obstacle à 100 cm
        echo_tb <= '1';
        wait for ECHO_TIME_100;
        echo_tb <= '0';

        -- Attente pour laisser le temps au calcul de distance
        wait for 80 ms;
		  
		  -- 4) Troisième mesure : obstacle à 50 cm
        echo_tb <= '1';
        wait for ECHO_TIME_50;
        echo_tb <= '0';

        -- Attente pour laisser le temps au calcul de distance
        wait for 20 ms;

        -- Fin de la simulation
        wait;
    end process;

end architecture Behavioral;
