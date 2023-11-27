library IEEE;
use ieee.std_logic_1164.ALL;
use ieee.numeric_std.all;
use ieee.std_logic_unsigned.all;

entity usart_tx_module is
    
    generic (
        CLKS_PER_BIT        : integer := 65535
    );
    
    port(
        -- Control bit
        txd_empty_o         : out std_logic;
        txd_trigger_i       : in  std_logic;

        -- host interface
        txd_data_i          : in  std_logic_vector(7 downto 0);
        baudrate_i          : in  std_logic_vector(15 downto 0);
        
        -- hardware pins
        txd_line_o          : out std_logic;

        -- system inteface
        master_clk_i        : in  std_logic;            -- Master clock
        reset_i             : in  std_logic             -- Reset, active low
        );

end usart_tx_module;

architecture rtl of usart_tx_module is
    type fsm_state_type is (STATE_IDLE, STATE_DATA_BITS, STATE_STOP_BIT, STATE_CLEANUP);

    signal state_x          : fsm_state_type := STATE_IDLE;
    signal state_r          : fsm_state_type := STATE_IDLE;
    
    signal txd_empty_x      : std_logic := '0';
    signal txd_empty_r      : std_logic := '0';

    signal txd_line_x       : std_logic := '0';
    signal txd_line_r       : std_logic := '0';
    
    signal txd_trigger_r    : std_logic := '0';

    signal bit_index_x      : integer range 0 to 7 := 0;  -- 8 Bits Total
    signal bit_index_r      : integer range 0 to 7 := 0;  -- 8 Bits Total

    signal txd_data_x       : std_logic_vector(7 downto 0);
    signal txd_data_r       : std_logic_vector(7 downto 0);

    signal clk_divider_x    : integer range 0 to CLKS_PER_BIT-1 := 0;
    signal clk_divider_r    : integer range 0 to CLKS_PER_BIT-1 := 0;
    signal divider_value    : integer := to_integer(signed(baudrate_i));
    
begin

    txd_empty_o             <= txd_empty_r;
    txd_line_o              <= txd_line_r;
    
    divider_value           <= to_integer(signed(baudrate_i));
    

    process(state_r, txd_empty_r, txd_line_r, txd_data_r, bit_index_r, clk_divider_r, txd_data_i, txd_trigger_r, divider_value)
    begin    
        
        state_x             <= state_r;
        txd_empty_x         <= txd_empty_r;
        txd_line_x          <= txd_line_r;
        txd_data_x          <= txd_data_r;
        bit_index_x         <= bit_index_r;
        clk_divider_x       <= clk_divider_r;

        if (clk_divider_r /= 0) then
            clk_divider_x   <= clk_divider_r - 1;
        else
            
            case state_r is        
                when STATE_IDLE =>
                    if (txd_trigger_r = '1') then
                        state_x         <= STATE_DATA_BITS;
                        clk_divider_x   <= divider_value - 1;
                        txd_data_x      <= txd_data_i;
                        txd_line_x      <= '0';
                        txd_empty_x     <= '0';
                        bit_index_x     <= 0;
                    end if;
                    
                when STATE_DATA_BITS =>
                    txd_line_x          <= txd_data_r(bit_index_r);
                    clk_divider_x       <= divider_value - 1;

                    if (bit_index_r < 7) then
                        bit_index_x     <= bit_index_r + 1;
                        
                    else
                        state_x         <= STATE_STOP_BIT;

                    end if;

                when STATE_STOP_BIT =>
                    state_x             <= STATE_CLEANUP;
                    clk_divider_x       <= divider_value - 1;
                    txd_line_x          <= '1';
                    txd_empty_x         <= '1';
                    
                when STATE_CLEANUP =>
                    if (txd_trigger_r = '0') then
                        state_x         <= STATE_IDLE;
                    end if;
            end case;
        end if;
    end process;
    
    process (master_clk_i)
    begin
        if rising_edge(master_clk_i) then
            if (reset_i = '0') then
                state_r             <= STATE_IDLE;
                txd_empty_r         <= '1';
                txd_line_r          <= '1';
                txd_data_r          <= "00000000";
                bit_index_r         <= 0;
                clk_divider_r       <= 0;                
                
            else
                state_r             <= state_x;
                txd_empty_r         <= txd_empty_x;
                txd_line_r          <= txd_line_x;
                txd_data_r          <= txd_data_x;
                bit_index_r         <= bit_index_x;
                clk_divider_r       <= clk_divider_x;       
                
                txd_trigger_r       <= txd_trigger_i;
                
            end if;
      end if;
    end process;
    
end rtl;
