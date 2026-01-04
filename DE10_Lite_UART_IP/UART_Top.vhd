library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity UART_Top is
  port (
    CLOCK_50 : in  std_logic;
    KEY      : in  std_logic_vector(1 downto 0); -- KEY(0) used as reset button (active low on board)
    GPIO     : inout std_logic_vector(35 downto 0);
    LEDR     : out std_logic_vector(9 downto 0)
  );
end entity;

architecture rtl of UART_Top is

  -- Board reset: KEY(0) is active-low when pressed
  signal reset_n : std_logic;

  -- UART wiring
  signal uart_rx : std_logic;
  signal uart_tx : std_logic;

  -- UART handshake signals
  signal tx_start : std_logic := '0';
  signal tx_data  : std_logic_vector(7 downto 0) := (others => '0');
  signal tx_busy  : std_logic;

  signal rx_data  : std_logic_vector(7 downto 0);
  signal rx_valid : std_logic;
  signal rx_ack   : std_logic := '0';

  -- Simple echo state
  type echo_state_t is (E_IDLE, E_WAIT_TX_FREE, E_PULSE_START, E_WAIT_DONE);
  signal echo_state : echo_state_t := E_IDLE;

begin

  reset_n <= KEY(0); -- not pressed => '1', pressed => '0'

  -- Connect your chosen GPIO pins
  -- RX comes from the PC (USB-UART TX) into FPGA
  uart_rx <= GPIO(13);

  -- TX goes from FPGA to PC (USB-UART RX)
  GPIO(12) <= uart_tx;

  -- Visual debug: show last received byte on LEDs (lower 8 bits)
  LEDR(7 downto 0) <= rx_data;
  LEDR(8) <= rx_valid;
  LEDR(9) <= tx_busy;

  u_uart : entity work.UART_IP
    generic map (
      CLK_FREQ_HZ => 50_000_000,
      BAUD_RATE   => 115_200
    )
    port map (
      clk      => CLOCK_50,
      reset_n  => reset_n,
      rx       => uart_rx,
      tx       => uart_tx,
      tx_start => tx_start,
      tx_data  => tx_data,
      tx_busy  => tx_busy,
      rx_data  => rx_data,
      rx_valid => rx_valid,
      rx_ack   => rx_ack
    );

  -- Echo logic:
  -- When a byte is received (rx_valid=1), acknowledge it and retransmit same byte.
  process(CLOCK_50)
  begin
    if rising_edge(CLOCK_50) then
      if reset_n = '0' then
        tx_start   <= '0';
        tx_data    <= (others => '0');
        rx_ack     <= '0';
        echo_state <= E_IDLE;
      else
        -- defaults
        tx_start <= '0';
        rx_ack   <= '0';

        case echo_state is
          when E_IDLE =>
            if rx_valid = '1' then
              -- latch byte and ack reception
              tx_data    <= rx_data;
              rx_ack     <= '1';          -- clear rx_valid inside UART_IP
              echo_state <= E_WAIT_TX_FREE;
            end if;

          when E_WAIT_TX_FREE =>
            if tx_busy = '0' then
              echo_state <= E_PULSE_START;
            end if;

          when E_PULSE_START =>
            -- single-cycle start pulse
            tx_start   <= '1';
            echo_state <= E_WAIT_DONE;

          when E_WAIT_DONE =>
            -- wait until transmitter finishes
            if tx_busy = '0' then
              echo_state <= E_IDLE;
            end if;

        end case;
      end if;
    end if;
  end process;

end architecture;
