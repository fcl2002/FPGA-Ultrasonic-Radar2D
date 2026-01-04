library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity UART_Standalone is
  port (
    CLOCK_50 : in  std_logic;
    KEY      : in  std_logic_vector(0 downto 0);

    GPIO_12   : out std_logic;  -- uart_tx
    GPIO_13   : in  std_logic   -- uart_rx
  );
end entity;

architecture rtl of UART_Standalone is

  signal reset_n  : std_logic;

  signal tx_start : std_logic := '0';
  signal tx_data  : std_logic_vector(7 downto 0) := (others => '0');
  signal tx_busy  : std_logic;

  signal rx_data  : std_logic_vector(7 downto 0);
  signal rx_valid : std_logic;
  signal rx_ack   : std_logic := '0';

  signal rx_valid_d : std_logic := '0';
  signal rx_event   : std_logic := '0';

  type st_t is (S_IDLE, S_LOAD, S_PULSE, S_WAIT_TX);
  signal st : st_t := S_IDLE;

  signal byte_latched : std_logic_vector(7 downto 0) := (others => '0');

begin

  reset_n <= KEY(0);

  u_uart : entity work.UART_IP
    generic map (
      CLK_FREQ_HZ => 50_000_000,
      BAUD_RATE   => 115_200
    )
    port map (
      clk      => CLOCK_50,
      reset_n  => reset_n,

      rx       => GPIO_13,
      tx       => GPIO_12,

      tx_start => tx_start,
      tx_data  => tx_data,
      tx_busy  => tx_busy,

      rx_data  => rx_data,
      rx_valid => rx_valid,
      rx_ack   => rx_ack
    );

  process(CLOCK_50)
  begin
    if rising_edge(CLOCK_50) then
      if reset_n = '0' then
        rx_valid_d <= '0';
      else
        rx_valid_d <= rx_valid;
      end if;
    end if;
  end process;

  rx_event <= '1' when (rx_valid = '1' and rx_valid_d = '0') else '0';

  process(CLOCK_50)
  begin
    if rising_edge(CLOCK_50) then
      if reset_n = '0' then
        tx_start     <= '0';
        tx_data      <= (others => '0');
        rx_ack       <= '0';
        byte_latched <= (others => '0');
        st           <= S_IDLE;
      else
        tx_start <= '0';
        rx_ack   <= '0';

        case st is
          when S_IDLE =>
            if rx_event = '1' then
              byte_latched <= rx_data;
              rx_ack       <= '1';      -- consome já
              st           <= S_LOAD;
            end if;

          when S_LOAD =>
            if tx_busy = '0' then
              tx_data <= byte_latched;  -- estabiliza 1 ciclo antes do start
              st <= S_PULSE;
            end if;

          when S_PULSE =>
            tx_start <= '1';
            st <= S_WAIT_TX;

          when S_WAIT_TX =>
            if tx_busy = '0' then
              st <= S_IDLE;
            end if;

        end case;
      end if;
    end if;
  end process;

end architecture;