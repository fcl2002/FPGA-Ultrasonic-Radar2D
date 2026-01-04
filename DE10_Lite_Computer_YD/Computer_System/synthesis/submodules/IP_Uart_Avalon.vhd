library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity IP_UART_Avalon is
    generic (
        -- For 50 MHz and 115200 baud (1x sampling): 50e6 / 115200 ≈ 434
        G_DIV_FACTOR : integer := 434
    );
    port
    (
        clk           : in  std_logic;
        reset_n       : in  std_logic;

        -- Avalon-MM slave (no address port, active-low control signals)
        chipselect_n  : in  std_logic;
        read_n        : in  std_logic;
        readdata      : out std_logic_vector(31 downto 0);
        write_n       : in  std_logic;
        writedata     : in  std_logic_vector(31 downto 0);

        -- Conduit
        uart_tx       : out std_logic;
        uart_rx       : in  std_logic
    );
end entity;

architecture Behavioral of IP_UART_Avalon is

    -- RX state machine
    type StateType_RX is (Wait_data, Load_data, Wait_end, Save_byte);
    signal State_Rx      : StateType_RX := Wait_data;
    signal bit_Rx        : integer range 0 to 9 := 0;
    signal byte_Rx       : std_logic_vector(7 downto 0) := (others => '0');
    signal byte_Rx_out   : std_logic_vector(7 downto 0) := (others => '0');

    -- TX state machine
    type StateType_TX is (Idle, Wait_Release, Load_reg, Send_start, Send_byte, Send_stop);
    signal State_Tx      : StateType_TX := Idle;
    signal bit_Tx        : integer range 0 to 9 := 0;
    signal byte_Tx       : std_logic_vector(7 downto 0) := (others => '0');

    signal frame_shift   : std_logic_vector(9 downto 0) := (others => '1'); -- start+data+stop
    signal load_r        : std_logic := '0';

    -- "Pseudo-address" encoded in writedata[31:30]
    signal Address       : std_logic_vector(1 downto 0) := (others => '0');

    -- Tick generator (1 tick per bit)
    signal counter       : integer := 0;
    signal Tick          : std_logic := '0';

begin

    -- Tick generator: Tick pulses once every G_DIV_FACTOR clock cycles
    process (clk, reset_n)
    begin
        if reset_n = '0' then
            counter <= 0;
            Tick <= '0';
        elsif rising_edge(clk) then
            if counter = G_DIV_FACTOR - 1 then
                counter <= 0;
                Tick <= '1';
            else
                counter <= counter + 1;
                Tick <= '0';
            end if;
        end if;
    end process;

    -- Avalon read/write handling (same philosophy as your friend's code)
    process (clk, reset_n)
    begin
        if reset_n = '0' then
            byte_Tx   <= (others => '0');
            load_r    <= '0';
            Address   <= (others => '0');
            readdata  <= (others => '0');
        elsif rising_edge(clk) then

            -- Default read data
            readdata <= (others => '0');

            -- Latch the "pseudo-address" from writedata MSBs (as in your friend's design)
            Address <= writedata(31 downto 30);

            -- Write transaction (active-low signals)
            if chipselect_n = '0' and write_n = '0' then
                case Address is
                    when "00" =>  -- LOAD register (bit0)
                        load_r <= writedata(0);

                    when "01" =>  -- TX byte register
                        byte_Tx <= writedata(7 downto 0);

                    when others =>
                        null;
                end case;

            -- Read transaction (active-low signals)
            elsif chipselect_n = '0' and read_n = '0' then
                case Address is
                    when "10" =>  -- RX byte register
                        readdata(7 downto 0) <= byte_Rx_out;

                    when others =>
                        readdata <= (others => '0');
                end case;
            end if;
        end if;
    end process;

    -- UART TX/RX FSMs driven by Tick (prioritize TX when active)
    process (clk, reset_n)
    begin
        if reset_n = '0' then
            -- RX reset
            State_Rx <= Wait_data;
            bit_Rx <= 0;
            byte_Rx <= (others => '0');
            byte_Rx_out <= (others => '0');

            -- TX reset
            State_Tx <= Idle;
            uart_tx <= '1';
            bit_Tx <= 0;
            frame_shift <= (others => '1');

        elsif rising_edge(clk) then
            if Tick = '1' then

                -- TX has priority
                if load_r = '1' or State_Tx /= Idle then
                    case State_Tx is

                        when Idle =>
                            if load_r = '1' then
                                State_Tx <= Load_reg;
                            end if;
                            -- Reset RX when TX starts (same behavior as friend's code)
                            State_Rx <= Wait_data;

                        when Load_reg =>
                            -- Build frame: start(0) + data(LSB first) + stop(1)
                            frame_shift <= '1' & byte_Tx & '0';
                            bit_Tx <= 0;
                            State_Tx <= Send_start;

                        when Send_start =>
                            uart_tx <= frame_shift(bit_Tx);
                            bit_Tx <= bit_Tx + 1;
                            State_Tx <= Send_byte;

                        when Send_byte =>
                            uart_tx <= frame_shift(bit_Tx);
                            if bit_Tx = 8 then
                                State_Tx <= Send_stop;
                            else
                                bit_Tx <= bit_Tx + 1;
                            end if;

                        when Send_stop =>
                            uart_tx <= '1';
                            State_Tx <= Wait_Release;

                        when Wait_Release =>
                            if load_r = '0' then
                                State_Tx <= Idle;
                            end if;

                        when others =>
                            State_Tx <= Idle;

                    end case;

                -- RX (only when TX is idle)
                else
                    case State_Rx is

                        when Wait_data =>
                            if uart_rx = '0' then
                                State_Rx <= Load_data;
                                bit_Rx <= 0;
                            end if;

                        when Load_data =>
                            if bit_Rx = 8 then
                                State_Rx <= Wait_end;
                            else
                                byte_Rx(bit_Rx) <= uart_rx;
                                bit_Rx <= bit_Rx + 1;
                            end if;

                        when Wait_end =>
                            if uart_rx = '1' then
                                State_Rx <= Save_byte;
                                byte_Rx_out <= byte_Rx;
                                byte_Rx <= (others => '0');
                            end if;

                        when Save_byte =>
                            State_Rx <= Wait_data;

                        when others =>
                            State_Rx <= Wait_data;

                    end case;
                end if;

            end if;
        end if;
    end process;

end architecture;
