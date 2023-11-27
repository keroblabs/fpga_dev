library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;

entity usart_scheduler is
    Port ( 
        -- memory interface
        mem_wr_en_o             : out   std_logic;
        mem_addr_o              : out   std_logic_vector(25 downto 0);
        mem_rw_req_o            : out   std_logic;
        mem_rw_done_i           : in    std_logic;
        mem_data_rd_i           : in    std_logic_vector(7 downto 0);
        mem_data_wr_o           : out   std_logic_vector(7 downto 0);
       
        txd_line                : inout std_logic;
        rxd_line                : inout std_logic;
        
        rx_done                 : out   std_logic;
        write_en                : in    std_logic;
        tx_done                 : out   std_logic;

        tx_byte                 : in    std_logic_vector(7 downto 0) := "00000000";
        rx_byte                 : out   std_logic_vector(7 downto 0) := "00000000";

        dma_busy_o              : out   std_logic;
        
        -- system interface
        baudrate                : in    std_logic_vector(15 downto 0) := "0000000000000000";
        master_clk_i            : in    std_logic;
        reset_i                 : in    std_logic
    );    
end usart_scheduler;

architecture rtl of usart_scheduler is

begin    

    usart_dma : entity work.usart_dma(rtl)
    port map ( 
        -- usart interface
        txd_line                => rxd_line,
        rxd_line                => txd_line,
       
        -- memory interface
        mem_wr_en_o             => mem_wr_en_o,
        mem_addr_o              => mem_addr_o,
        mem_rw_req_o            => mem_rw_req_o,
        mem_rw_done_i           => mem_rw_done_i,
        mem_data_rd_i           => mem_data_rd_i,
        mem_data_wr_o           => mem_data_wr_o,
        
        dma_busy_o              => dma_busy_o,

        -- system interface
        baudrate                => baudrate,
        master_clk_i            => master_clk_i,
        reset_i                 => reset_i
    );   
    
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
        rxd_line_i          => rxd_line,

        -- system inteface
        master_clk_i        => master_clk_i,
        reset_i             => reset_i
    );
    
end rtl;