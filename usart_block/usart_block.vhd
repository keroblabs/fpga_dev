library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;

entity usart_block is
    Port ( 
        txd_line              : inout STD_LOGIC;
        rxd_line              : inout STD_LOGIC;
        
        rx_done               : out   STD_LOGIC;
        loop_back             : in    STD_LOGIC;

        tx_byte               : in    STD_LOGIC_VECTOR(7 downto 0) := "00000000";
        rx_byte               : out   STD_LOGIC_VECTOR(7 downto 0) := "00000000";
        
        write_en              : in    STD_LOGIC;
        tx_done               : out   STD_LOGIC;

        baudrate              : in    STD_LOGIC_VECTOR(15 downto 0) := "0000000000000000";
        master_clk_i          : in    STD_LOGIC;
        reset_i               : in    STD_LOGIC
    );    
end usart_block;

architecture rtl of usart_block is
    signal temp_rxd           : STD_LOGIC := '0';

begin    
    usart_tx_block : entity work.usart_tx_module(rtl)
    port map (
        
        -- Control bit
        txd_empty_o         => tx_done,
        txd_trigger_i       => write_en,

        -- host interface
        txd_data_i          => tx_byte,
        baudrate_i          => baudrate,
        
        -- hardware pins
        txd_line_o          => txd_line,

        -- system inteface
        master_clk_i        => master_clk_i,
        reset_i             => reset_i
    );
        
    usart_rx_block : entity work.usart_rx_module(rtl)
    port map (
        -- Control bit
        rxd_done_o          => rx_done,
    
        -- host interface
        rxd_data_o          => rx_byte,
        baudrate_i          => baudrate,
        
        -- hardware pins
        rxd_line_i          => temp_rxd,

        -- system inteface
        master_clk_i        => master_clk_i,
        reset_i             => reset_i
    );
    
    temp_rxd <= (rxd_line and not loop_back) or (txd_line and loop_back);
    
end rtl;