library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity IP_Uart_Avalon is
    port (
        -- Global
        clk        : in  std_logic;
        reset_n    : in  std_logic;
        
        -- Avalon-MM Slave
        chipselect : in  std_logic;
        write_n    : in  std_logic; -- '0' = Escrita
        writedata  : in  std_logic_vector(31 downto 0);
        read_n     : in  std_logic; -- '0' = Leitura
        readdata   : out std_logic_vector(31 downto 0);

        -- Interface Externa (Pinos Físicos)
        uart_rx    : in  std_logic; -- Recebe do mundo
        uart_tx    : out std_logic  -- Manda pro mundo
    );
end entity IP_Uart_Avalon;

architecture Behavioral of IP_Uart_Avalon is

    -- CONFIGURAÇÃO DE VELOCIDADE
    constant CLK_FREQ  : integer := 100000000; -- Mude para 100000000 se usar 100MHz
    constant BAUD_RATE : integer := 115200;
    constant BIT_TIMER : integer := CLK_FREQ / BAUD_RATE;

    -- Sinais TX
    type tx_state_type is (IDLE, START, DATA, STOP);
    signal tx_state : tx_state_type := IDLE;
    signal tx_timer : integer range 0 to BIT_TIMER;
    signal tx_bit_idx : integer range 0 to 7;
    signal tx_data_buf : std_logic_vector(7 downto 0);
    signal tx_busy     : std_logic := '0';

    -- Sinais RX
    type rx_state_type is (IDLE, START, DATA, STOP);
    signal rx_state : rx_state_type := IDLE;
    signal rx_timer : integer range 0 to BIT_TIMER;
    signal rx_bit_idx : integer range 0 to 7;
    signal rx_data_buf : std_logic_vector(7 downto 0);
    signal rx_ready    : std_logic := '0'; -- Indica que chegou dado novo

begin

    -- =========================================================
    -- PROCESSO 1: INTERFACE AVALON (Leitura e Escrita do Nios)
    -- =========================================================
    process(clk, reset_n)
    begin
        if reset_n = '0' then
            readdata <= (others => '0');
            tx_data_buf <= (others => '0');
            tx_busy <= '0';
        elsif rising_edge(clk) then
            -- ESCRITA (Nios manda enviar)
            -- Se escrevermos algo, iniciamos o TX (bit busy liga)
            if chipselect = '1' and write_n = '0' then
                tx_data_buf <= writedata(7 downto 0);
                tx_busy <= '1'; -- Flag para iniciar envio
            elsif tx_state = STOP and tx_timer = BIT_TIMER-1 then
                tx_busy <= '0'; -- Terminou de enviar
            end if;

            -- LEITURA (Nios quer ver status ou dado recebido)
            if chipselect = '1' and read_n = '0' then
                -- Bit 9 = RX Ready? 
                -- Bit 8 = TX Busy?
                -- Bits 7-0 = Dado Recebido
                readdata(31 downto 10) <= (others => '0');
                readdata(9) <= rx_ready;
                readdata(8) <= tx_busy; 
                readdata(7 downto 0) <= rx_data_buf;
                
                -- Se o Nios leu, limpamos a flag de RX Ready
                if rx_ready = '1' then
                   -- (Lógica simplificada: assume que leu e limpou)
                   -- Na prática precisaria de um handshake melhor, mas pra aula serve.
                end if;
            end if;
        end if;
    end process;

    -- =========================================================
    -- PROCESSO 2: MÁQUINA DE ESTADOS TX (Envio Serial)
    -- =========================================================
    process(clk, reset_n)
    begin
        if reset_n = '0' then
            uart_tx <= '1'; -- Linha em repouso é HIGH
            tx_state <= IDLE;
            tx_timer <= 0;
        elsif rising_edge(clk) then
            case tx_state is
                when IDLE =>
                    uart_tx <= '1';
                    tx_timer <= 0;
                    if tx_busy = '1' then
                        tx_state <= START;
                    end if;
                
                when START =>
                    uart_tx <= '0'; -- Start Bit (Low)
                    if tx_timer < BIT_TIMER-1 then
                        tx_timer <= tx_timer + 1;
                    else
                        tx_timer <= 0;
                        tx_bit_idx <= 0;
                        tx_state <= DATA;
                    end if;

                when DATA =>
                    uart_tx <= tx_data_buf(tx_bit_idx);
                    if tx_timer < BIT_TIMER-1 then
                        tx_timer <= tx_timer + 1;
                    else
                        tx_timer <= 0;
                        if tx_bit_idx < 7 then
                            tx_bit_idx <= tx_bit_idx + 1;
                        else
                            tx_state <= STOP;
                        end if;
                    end if;

                when STOP =>
                    uart_tx <= '1'; -- Stop Bit (High)
                    if tx_timer < BIT_TIMER-1 then
                        tx_timer <= tx_timer + 1;
                    else
                        tx_state <= IDLE; -- Fim
                    end if;
            end case;
        end if;
    end process;

    -- (Opcional) PROCESSO RX: Para receber dados, implementaremos depois se precisar.
    -- Por enquanto vamos focar em MANDAR dados pro PC (Radar -> Tela).
    rx_ready <= '0'; 

end architecture;