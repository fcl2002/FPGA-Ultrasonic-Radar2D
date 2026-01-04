library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity UART_IP is
  generic (
    CLK_FREQ_HZ : positive := 50_000_000;
    BAUD_RATE   : positive := 115_200
  );
  port (
    clk      : in  std_logic;
    reset_n  : in  std_logic;

    rx       : in  std_logic;
    tx       : out std_logic;

    tx_start : in  std_logic;
    tx_data  : in  std_logic_vector(7 downto 0);
    tx_busy  : out std_logic;

    rx_data  : out std_logic_vector(7 downto 0);
    rx_valid : out std_logic;
    rx_ack   : in  std_logic
  );
end entity;

architecture rtl of UART_IP is

  constant BAUD_DIV  : positive := (CLK_FREQ_HZ + (BAUD_RATE/2)) / BAUD_RATE;
  constant HALF_BAUD : positive := BAUD_DIV / 2;

  signal rx_ff0, rx_ff1 : std_logic := '1';

  type tx_state_t is (TX_S_IDLE, TX_S_START, TX_S_DATA, TX_S_STOP);
  signal tx_state   : tx_state_t := TX_S_IDLE;
  signal tx_cnt     : integer range 0 to BAUD_DIV-1 := 0;
  signal tx_bit_idx : integer range 0 to 7 := 0;
  signal tx_shift   : std_logic_vector(7 downto 0) := (others => '0');
  signal tx_reg     : std_logic := '1';

  -- RX: vamos usar contador que pode ir até (BAUD_DIV + HALF_BAUD)
  type rx_state_t is (RX_S_IDLE, RX_S_START, RX_S_DATA, RX_S_STOP);
  signal rx_state   : rx_state_t := RX_S_IDLE;
  signal rx_cnt     : integer range 0 to BAUD_DIV + HALF_BAUD := 0;
  signal rx_bit_idx : integer range 0 to 7 := 0;
  signal rx_shift   : std_logic_vector(7 downto 0) := (others => '0');
  signal rx_valid_r : std_logic := '0';

begin

  tx <= tx_reg;

  -- RX synchronizer (2 FF)
  process(clk)
  begin
    if rising_edge(clk) then
      if reset_n = '0' then
        rx_ff0 <= '1';
        rx_ff1 <= '1';
      else
        rx_ff0 <= rx;
        rx_ff1 <= rx_ff0;
      end if;
    end if;
  end process;

  -- ===================== TX (ok) =====================
  process(clk)
  begin
    if rising_edge(clk) then
      if reset_n = '0' then
        tx_state   <= TX_S_IDLE;
        tx_cnt     <= 0;
        tx_bit_idx <= 0;
        tx_shift   <= (others => '0');
        tx_reg     <= '1';
      else
        case tx_state is
          when TX_S_IDLE =>
            tx_reg     <= '1';
            tx_cnt     <= 0;
            tx_bit_idx <= 0;
            if tx_start = '1' then
              tx_shift <= tx_data;
              tx_cnt   <= 0;
              tx_state <= TX_S_START;
            end if;

          when TX_S_START =>
            tx_reg <= '0';
            if tx_cnt = BAUD_DIV-1 then
              tx_cnt     <= 0;
              tx_reg     <= tx_shift(0);
              tx_bit_idx <= 0;
              tx_state   <= TX_S_DATA;
            else
              tx_cnt <= tx_cnt + 1;
            end if;

          when TX_S_DATA =>
            if tx_cnt = BAUD_DIV-1 then
              tx_cnt <= 0;
              if tx_bit_idx = 7 then
                tx_reg   <= '1';
                tx_state <= TX_S_STOP;
              else
                tx_bit_idx <= tx_bit_idx + 1;
                tx_reg     <= tx_shift(tx_bit_idx + 1);
              end if;
            else
              tx_cnt <= tx_cnt + 1;
            end if;

          when TX_S_STOP =>
            tx_reg <= '1';
            if tx_cnt = BAUD_DIV-1 then
              tx_cnt   <= 0;
              tx_state <= TX_S_IDLE;
            else
              tx_cnt <= tx_cnt + 1;
            end if;
        end case;
      end if;
    end if;
  end process;

  tx_busy <= '0' when tx_state = TX_S_IDLE else '1';

  -- ===================== RX (corrigido) =====================
  process(clk)
  begin
    if rising_edge(clk) then
      if reset_n = '0' then
        rx_state   <= RX_S_IDLE;
        rx_cnt     <= 0;
        rx_bit_idx <= 0;
        rx_shift   <= (others => '0');
        rx_valid_r <= '0';
      else
        if rx_ack = '1' then
          rx_valid_r <= '0';
        end if;

        case rx_state is
          when RX_S_IDLE =>
            rx_cnt     <= 0;
            rx_bit_idx <= 0;
            if rx_ff1 = '0' then
              -- caiu: possível start
              rx_cnt   <= 0;
              rx_state <= RX_S_START;
            end if;

          when RX_S_START =>
            -- esperar 1.5 baud para amostrar no centro do bit0
            if rx_cnt = (BAUD_DIV + HALF_BAUD - 1) then
              rx_cnt <= 0;
              -- amostra bit0 no centro
              rx_shift(0) <= rx_ff1;
              rx_bit_idx  <= 1;
              rx_state    <= RX_S_DATA;
            else
              rx_cnt <= rx_cnt + 1;
            end if;

          when RX_S_DATA =>
            if rx_cnt = BAUD_DIV-1 then
              rx_cnt <= 0;
              rx_shift(rx_bit_idx) <= rx_ff1;

              if rx_bit_idx = 7 then
                rx_state <= RX_S_STOP;
              else
                rx_bit_idx <= rx_bit_idx + 1;
              end if;
            else
              rx_cnt <= rx_cnt + 1;
            end if;

          when RX_S_STOP =>
            if rx_cnt = BAUD_DIV-1 then
              rx_cnt <= 0;
              if rx_ff1 = '1' then
                rx_valid_r <= '1';
              end if;
              rx_state <= RX_S_IDLE;
            else
              rx_cnt <= rx_cnt + 1;
            end if;

        end case;
      end if;
    end if;
  end process;

  rx_data  <= rx_shift;
  rx_valid <= rx_valid_r;

end architecture;