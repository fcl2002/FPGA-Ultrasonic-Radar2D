library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

-- IP autonome pour le télémètre ultrasonique HC-SR04
-- Entrées :
--   clk   : horloge 50 MHz
--   rst_n : reset actif à l'état bas
--   echo  : signal de retour du capteur
-- Sorties :
--   trig    : impulsion de déclenchement (>= 10 µs)
--   dist_cm : distance mesurée en centimètres (0..1023)

entity Telemetre_IP_Standalone is
    port (
        clk      : in  std_logic;
        rst_n    : in  std_logic;
        echo     : in  std_logic;
        trig     : out std_logic;
        dist_cm  : out std_logic_vector(9 downto 0)
    );
end entity Telemetre_IP_Standalone;

architecture Behavioral of Telemetre_IP_Standalone is

    -- Horloge système : 50 MHz -> période = 20 ns
    constant CLK_FREQ_HZ           : integer := 50000000;

    -- Durée de l’impulsion TRIG : 10 µs
    constant TRIG_PULSE_US         : integer := 10;
    constant TRIG_PULSE_CYCLES     : integer := (CLK_FREQ_HZ / 1000000) * TRIG_PULSE_US;  -- 50e6/1e6 * 10 = 500 cycles

    -- Période minimale entre deux mesures (~60 ms recommandées par la datasheet)
    constant MEASURE_PERIOD_MS     : integer := 60;
    constant MEASURE_PERIOD_CYCLES : integer := (CLK_FREQ_HZ / 1000) * MEASURE_PERIOD_MS; -- 50e6/1e3 * 60 = 3.000.000 cycles

    -- Conversion temps (en cycles) -> distance (en cm)
    -- 1 cm ≈ 58 µs
    -- 1 µs = 50 cycles (à 50 MHz)
    -- Donc 1 cm ≈ 58 * 50 = 2900 cycles
    constant CYCLES_PER_CM         : integer := 2900;

    -- Machine d'états pour le contrôle de la mesure
    type state_type is (
        IDLE,           -- Attente avant une nouvelle mesure
        TRIG_PULSE,     -- Génération de l’impulsion TRIG
        WAIT_ECHO,      -- Attente du front montant de ECHO
        MEASURE_ECHO,   -- Comptage pendant que ECHO = '1'
        WAIT_BETWEEN    -- Attente entre deux mesures
    );
    signal state : state_type;

    -- Registres internes
    signal trig_reg          : std_logic := '0';

    signal trig_counter      : unsigned(9 downto 0)   := (others => '0');  -- Compteur pour la durée de TRIG
    signal measure_counter   : unsigned(21 downto 0)  := (others => '0');  -- Compteur pour la durée de ECHO
    signal period_counter    : unsigned(21 downto 0)  := (others => '0');  -- Compteur pour l’intervalle entre mesures

    signal distance_reg      : unsigned(9 downto 0)   := (others => '0');

    -- Synchronisation et détection de fronts sur ECHO
    signal echo_sync_1       : std_logic := '0';
    signal echo_sync_2       : std_logic := '0';

    signal rising_echo       : std_logic;
    signal falling_echo      : std_logic;

begin

    -- Connexion des sorties aux registres internes
    trig    <= trig_reg;
    dist_cm <= std_logic_vector(distance_reg);

    -- Détection de fronts sur le signal ECHO synchronisé
    rising_echo  <= '1' when (echo_sync_2 = '0' and echo_sync_1 = '1') else '0';
    falling_echo <= '1' when (echo_sync_2 = '1' and echo_sync_1 = '0') else '0';

    -- Processus principal : machine d'états + compteurs
    process(clk, rst_n)
        variable temp_distance_int : integer;
    begin
        if rst_n = '0' then
            -- Reset asynchrone actif à l'état bas
            state           <= IDLE;
            trig_reg        <= '0';

            trig_counter    <= (others => '0');
            measure_counter <= (others => '0');
            period_counter  <= (others => '0');

            distance_reg    <= (others => '0');

            echo_sync_1     <= '0';
            echo_sync_2     <= '0';

        elsif rising_edge(clk) then

            -- Synchronisation du signal ECHO (réduction du risque de métastabilité)
            echo_sync_1 <= echo;
            echo_sync_2 <= echo_sync_1;

            case state is

                ----------------------------------------------------------------
                when IDLE =>
                    -- Préparation d'un nouveau cycle de mesure
                    trig_reg        <= '0';
                    trig_counter    <= (others => '0');
                    measure_counter <= (others => '0');
                    period_counter  <= (others => '0');
                    state           <= TRIG_PULSE;

                ----------------------------------------------------------------
                when TRIG_PULSE =>
                    -- Génération du pulse TRIG (10 µs)
                    trig_reg <= '1';

                    if trig_counter = to_unsigned(TRIG_PULSE_CYCLES - 1, trig_counter'length) then
                        trig_reg     <= '0';
                        trig_counter <= (others => '0');
                        -- Passage à l'attente du signal ECHO
                        state        <= WAIT_ECHO;
                    else
                        trig_counter <= trig_counter + 1;
                    end if;

                ----------------------------------------------------------------
                when WAIT_ECHO =>
                    -- Attente du front montant de ECHO pour démarrer la mesure
                    if rising_echo = '1' then
                        measure_counter <= (others => '0');
                        state           <= MEASURE_ECHO;
                    end if;
                    -- (Optionnel : on pourrait ajouter un timeout ici si ECHO ne monte jamais)

                ----------------------------------------------------------------
                when MEASURE_ECHO =>
                    -- Pendant que ECHO = '1', on incrémente le compteur
                    if echo_sync_2 = '1' then
                        measure_counter <= measure_counter + 1;
                    end if;

                    -- Sur le front descendant de ECHO, on convertit en distance
                    if falling_echo = '1' then
                        -- distance (cm) = nombre_de_cycles / CYCLES_PER_CM
                        temp_distance_int := (to_integer(measure_counter) + CYCLES_PER_CM/2) / CYCLES_PER_CM;

                        -- Saturation simple sur la plage du registre (0..1023)
                        if temp_distance_int < 0 then
                            temp_distance_int := 0;
                        elsif temp_distance_int > 1023 then
                            temp_distance_int := 1023;
                        end if;

                        distance_reg   <= to_unsigned(temp_distance_int, distance_reg'length);
                        period_counter <= (others => '0');
                        state          <= WAIT_BETWEEN;
                    end if;

                ----------------------------------------------------------------
                when WAIT_BETWEEN =>
                    -- Intervalle minimal entre deux mesures (≈ 60 ms)
                    if period_counter = to_unsigned(MEASURE_PERIOD_CYCLES - 1, period_counter'length) then
                        period_counter <= (others => '0');
                        state          <= TRIG_PULSE;  -- Démarre une nouvelle mesure
                    else
                        period_counter <= period_counter + 1;
                    end if;

            end case;
        end if;
    end process;

end architecture Behavioral;
