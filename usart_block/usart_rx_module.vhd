library IEEE;
use ieee.std_logic_1164.ALL;
use ieee.numeric_std.all;
use ieee.std_logic_unsigned.all;

entity usart_rx_module is
    
    generic (
        CLKS_PER_BIT        : integer := 262144;
        WATCHDOG_PERIOD     : integer := 16
    );
    
    port(
        -- Control bit
        rxd_done_o          : out std_logic;
    
        -- host interface
        rxd_data_o          : out std_logic_vector(7 downto 0);
        baudrate_i          : in  std_logic_vector(15 downto 0);
        
        -- hardware pins
        rxd_line_i          : in  std_logic;

        -- system inteface
        master_clk_i        : in  std_logic;            -- Master clock
        reset_i             : in  std_logic             -- Reset, active low
        );

end usart_rx_module;

architecture rtl of usart_rx_module is
    type fsm_state_type  is (STATE_IDLE, STATE_START_BIT, STATE_DATA_BITS, STATE_STOP_BIT, STATE_CLEANUP);

    signal state_x          : fsm_state_type := STATE_IDLE;
    signal state_r          : fsm_state_type := STATE_IDLE;

    signal bit_index_x      : integer range 0 to 7 := 0;  -- 8 Bits Total
    signal bit_index_r      : integer range 0 to 7 := 0;  -- 8 Bits Total

    signal rxd_data_x       : std_logic_vector(7 downto 0);
    signal rxd_data_r       : std_logic_vector(7 downto 0);

    signal rxd_done_x       : std_logic;
    signal rxd_done_r       : std_logic;

    signal clk_divider_x    : integer range 0 to CLKS_PER_BIT-1 := 0;
    signal clk_divider_r    : integer range 0 to CLKS_PER_BIT-1 := 0;
    
    --signal watchdog_x       : integer range 0 to CLKS_PER_BIT-1 := 0;
    --signal watchdog_r       : integer range 0 to CLKS_PER_BIT-1 := 0;

    signal divider_value_r  : integer range 0 to CLKS_PER_BIT-1 := 0;
    --signal watchdog_value_r : integer range 0 to CLKS_PER_BIT-1 := 0;

begin

    rxd_done_o              <= rxd_done_r;
    
    process(state_r, bit_index_r, rxd_data_r, rxd_done_r, clk_divider_r, rxd_line_i, divider_value_r)
    begin
        
        state_x             <= state_r;
        bit_index_x         <= bit_index_r;
        rxd_data_x          <= rxd_data_r;
        clk_divider_x       <= clk_divider_r;
        --watchdog_x          <= watchdog_r;
        
        rxd_done_x          <= rxd_done_r;

        --if ((watchdog_r /= 0) and (state_r /= STATE_IDLE)) then
        --    watchdog_x      <= watchdog_r - 1;
            
        --else
        --    state_x         <= STATE_IDLE;
            
        --end if;

        if (clk_divider_r /= 0) then
            clk_divider_x <= clk_divider_r - 1;
        else

            -- usart rx state machine
            case state_r is
                when STATE_IDLE =>
                    if (rxd_line_i = '0') then
                        state_x         <= STATE_START_BIT;
                        -- wait for half-length bit
                        clk_divider_x   <= ((divider_value_r - 1)/2);
                        --watchdog_x      <= watchdog_value_r - 1;
                        
                    end if;
                    
                when STATE_START_BIT =>
                    if (rxd_line_i = '0') then
                        state_x         <= STATE_DATA_BITS;
                        bit_index_x     <= 0;
                        clk_divider_x   <= divider_value_r - 1;

                    else
                        state_x         <= STATE_CLEANUP;

                    end if;
                    
                when STATE_DATA_BITS =>
                    rxd_data_x(bit_index_r) <= rxd_line_i;
                    clk_divider_x       <= divider_value_r - 1;

                    if (bit_index_r < 7) then
                        bit_index_x     <= bit_index_r + 1;

                    else
                        state_x         <= STATE_STOP_BIT;

                    end if;
                        
                when STATE_STOP_BIT =>
                    if (rxd_line_i = '1') then
                        rxd_done_x      <= '1';
                        state_x         <= STATE_CLEANUP;
                        clk_divider_x   <= ((divider_value_r-1)/2);
                        
                    end if;
                    
                when STATE_CLEANUP =>                
                    rxd_done_x          <= '0';
                    state_x             <= STATE_IDLE;
                    
            end case;
        end if;
    end process;
    
    process (master_clk_i)
    begin
        if rising_edge(master_clk_i) then
            if (reset_i = '0') then
                state_r             <= STATE_IDLE;
                bit_index_r         <= 0;
                clk_divider_r       <= 0;
                rxd_data_r          <= "00000000";
                rxd_done_r          <= '1';
                divider_value_r     <= 0;
                --watchdog_r          <= 0;
                --watchdog_value_r    <= 200000;

            else
                state_r             <= state_x;
                bit_index_r         <= bit_index_x;
                clk_divider_r       <= clk_divider_x;
                rxd_data_r          <= rxd_data_x;
                rxd_done_r          <= rxd_done_x;
                --watchdog_r          <= watchdog_x;
                
                divider_value_r     <= to_integer(signed(baudrate_i));

                if (rxd_done_x = '1') then
                    rxd_data_o      <= rxd_data_x;
                end if;
                
                
            end if;
      end if;
    end process;
    
end rtl;
