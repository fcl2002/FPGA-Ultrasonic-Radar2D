library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

-- IP Télémètre Ultrason HC-SR04 avec interface Avalon-MM (lecture seule)
-- Cette IP réalise entièrement la mesure de distance (TRIG/ECHO)
-- puis expose la distance en cm au processeur NIOS II via un registre Avalon.
-- Les signaux TRIG, ECHO et dist_cm sont également fournis via un conduit.

entity Telemetre_us_Avalon is
    port (
        -- Horloge / reset
        clk        : in  std_logic;
        rst_n      : in  std_logic;

        -- Interface Avalon-MM (esclave, lecture seule)
        chipselect : in  std_logic;
        read_n     : in  std_logic;
        readdata   : out std_logic_vector(31 downto 0);

        -- Interface capteur ultrason HC-SR04
        trig       : out std_logic;
        echo       : in  std_logic;

        -- Sortie brute pour debug
        dist_cm    : out std_logic_vector(9 downto 0)
    );
end entity Telemetre_us_Avalon;

architecture Behavioral of Telemetre_us_Avalon is

    --------------------------------------------------------------------
    -- Constantes internes
    --------------------------------------------------------------------
    constant CLK_FREQ_HZ       : integer := 50000000;
    constant TRIG_PULSE_US     : integer := 10;
    constant TRIG_PULSE_CYCLES : integer :=
           (CLK_FREQ_HZ / 1000000) * TRIG_PULSE_US;

    constant MEASURE_PERIOD_MS     : integer := 60;
    constant MEASURE_PERIOD_CYCLES : integer :=
           (CLK_FREQ_HZ / 1000) * MEASURE_PERIOD_MS;

    constant CYCLES_PER_CM : integer := 2900;
    constant MAX_DISTANCE_CM : integer := 400;

    --------------------------------------------------------------------
    -- États internes
    --------------------------------------------------------------------
    type state_type is (
        IDLE,
        TRIG_PULSE,
        WAIT_ECHO,
        MEASURE_ECHO,
        WAIT_BETWEEN
    );
    signal state : state_type := IDLE;

    --------------------------------------------------------------------
    -- Registres internes
    --------------------------------------------------------------------
    signal trig_reg        : std_logic := '0';

    signal trig_counter    : unsigned(9 downto 0)  := (others => '0');
    signal measure_counter : unsigned(21 downto 0) := (others => '0');
    signal period_counter  : unsigned(21 downto 0) := (others => '0');

    signal distance_reg : unsigned(9 downto 0) := (others => '0');

    --------------------------------------------------------------------
    -- Synchroniseur du signal ECHO : deux bascules D
    --------------------------------------------------------------------
    signal echo_sync_1 : std_logic := '0';
    signal echo_sync_2 : std_logic := '0';
    signal rising_echo, falling_echo : std_logic;

    -- Registre de lecture Avalon
    signal readdata_reg : std_logic_vector(31 downto 0) := (others => '0');

begin

    --------------------------------------------------------------------
    -- Connexion des sorties
    --------------------------------------------------------------------
    trig    <= trig_reg;
    dist_cm <= std_logic_vector(distance_reg);
    readdata <= readdata_reg;

    --------------------------------------------------------------------
    -- Synchronisation du signal ECHO (double bascule D)
    --------------------------------------------------------------------
    process(clk, rst_n)
    begin
        if rst_n = '0' then
            echo_sync_1 <= '0';
            echo_sync_2 <= '0';

        elsif rising_edge(clk) then
            echo_sync_1 <= echo;          -- capture asynchrone
            echo_sync_2 <= echo_sync_1;   -- stabilisation synchronisée
        end if;
    end process;

    -- Détection de fronts propres
    rising_echo  <= '1' when (echo_sync_2 = '0' and echo_sync_1 = '1') else '0';
    falling_echo <= '1' when (echo_sync_2 = '1' and echo_sync_1 = '0') else '0';

    --------------------------------------------------------------------
    -- Machine d'états principale TRIG/ECHO
    --------------------------------------------------------------------
    process(clk, rst_n)
        variable temp_distance : integer;
    begin
        if rst_n = '0' then

            state <= IDLE;
            trig_reg <= '0';
            trig_counter <= (others => '0');
            measure_counter <= (others => '0');
            period_counter <= (others => '0');
            distance_reg <= (others => '0');

        elsif rising_edge(clk) then

            case state is

                ----------------------------------------------------------------
                when IDLE =>
                    trig_reg <= '0';
                    state <= TRIG_PULSE;

                ----------------------------------------------------------------
                when TRIG_PULSE =>
                    trig_reg <= '1';

                    if trig_counter = TRIG_PULSE_CYCLES - 1 then
                        trig_reg <= '0';
                        trig_counter <= (others => '0');
                        state <= WAIT_ECHO;
                    else
                        trig_counter <= trig_counter + 1;
                    end if;

                ----------------------------------------------------------------
                when WAIT_ECHO =>
                    if rising_echo = '1' then
                        measure_counter <= (others => '0');
                        state <= MEASURE_ECHO;
                    end if;

                ----------------------------------------------------------------
                when MEASURE_ECHO =>
                    if echo_sync_2 = '1' then
                        measure_counter <= measure_counter + 1;
                    end if;

                    if falling_echo = '1' then
                        temp_distance :=
                          (to_integer(measure_counter) + CYCLES_PER_CM/2)
                          / CYCLES_PER_CM;

                        if temp_distance < 0 then
                            temp_distance := 0;
                        elsif temp_distance >= MAX_DISTANCE_CM then
                            temp_distance := 0;
                        end if;

                        distance_reg <=
                           to_unsigned(temp_distance, distance_reg'length);

                        period_counter <= (others => '0');
                        state <= WAIT_BETWEEN;
                    end if;

                ----------------------------------------------------------------
                when WAIT_BETWEEN =>
                    if period_counter = MEASURE_PERIOD_CYCLES - 1 then
                        period_counter <= (others => '0');
                        state <= TRIG_PULSE;
                    else
                        period_counter <= period_counter + 1;
                    end if;

            end case;
        end if;
    end process;

    --------------------------------------------------------------------
    -- Interface Avalon-MM : lecture du registre de distance
    --------------------------------------------------------------------
    process(clk, rst_n)
    begin
        if rst_n = '0' then
            readdata_reg <= (others => '0');

        elsif rising_edge(clk) then
            if (chipselect = '1') and (read_n = '0') then
                readdata_reg(9 downto 0)  <= std_logic_vector(distance_reg);
                readdata_reg(31 downto 10) <= (others => '0');
            end if;
        end if;
    end process;

end architecture Behavioral;