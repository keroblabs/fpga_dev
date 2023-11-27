library IEEE;
use ieee.std_logic_1164.ALL;
use ieee.numeric_std.all;
use ieee.std_logic_unsigned.all;
library pll_control;

entity soc_toplevel is
    
    port(
      -- Host side - USART DMA 
      txd_line                      : out   std_logic;
      rxd_line                      : in    std_logic;
    
      -- debug interface
      i_pll_locked                  : out   std_logic;
      sdram_ready_o                 : out   std_logic;
      dma_busy_o                    : out   std_logic;
      refresh_busy_o                : out   std_logic := '0';
      memory_busy_o                 : out   std_logic := '0';
      
      -- SDRAM side
      sdCke_o                       : out   std_logic;                        -- G17 - Clock-enable to SDRAM
      sdCe_bo                       : out   std_logic;                        -- P17 - Chip-select to SDRAM
      sdRas_bo                      : out   std_logic;                        -- P16 - SDRAM row address strobe
      sdCas_bo                      : out   std_logic;                        -- T19 - SDRAM column address strobe
      sdWe_bo                       : out   std_logic;                        -- U20 - SDRAM write enable
      sdBs_o                        : out   std_logic_vector( 1 downto 0);    -- P18.P19 - SDRAM bank address
      sdAddr_o                      : out   std_logic_vector(12 downto 0);    -- H20.H18.N19.J19.J18.K17.K16.L18.L19.L17.M16.M20.M18               - SDRAM row/column address
      sdData0_io                    : inout std_logic_vector(15 downto 0);    -- N21.N20.P22.R22.R21.T22.M22.M21.U22.V21.W21.W22.Y21.Y22.AB22.AA22 - Data to/from SDRAM
      sdData1_io                    : inout std_logic_vector(15 downto 0);    -- B21.A22.B22.C21.D21.D22.E20.E22.F22.G21.G22.H21.J21.J22.K21 .K22  - Data to/from SDRAM
      sdDqml0_o                     : out   std_logic;                        -- U21 Enable lower-byte of SDRAM databus if true
      sdDqmh0_o                     : out   std_logic;                        -- L22 Enable upper-byte of SDRAM databus if true
      sdDqml1_o                     : out   std_logic;                        -- K20 Enable lower-byte of SDRAM databus if true
      sdDqmh1_o                     : out   std_logic;                        -- E21 Enable upper-byte of SDRAM databus if true
      
      -- system interface
      clk_126m_o                    : out   std_logic;                        -- G18
      clk_50m_i                     : in    std_logic;
      reset_i                       : in    std_logic := '0'
      
    );
end soc_toplevel;

architecture rtl of soc_toplevel is
      signal baudrate               : std_logic_vector(15 downto 0) := "0000000000000000";
      signal mem_refresh_rate       : std_logic_vector(9 downto 0) := "0000000000";
      signal simulation             : std_logic := '0';
      signal clk_sdram_i            : std_logic;

      signal host_request_i         : std_logic;
      signal host_done_o            : std_logic;
      signal host_addr_i            : std_logic_vector(25 downto 0);
      signal host_we_i              : std_logic;
      signal host_data_rd_o         : std_logic_vector(7  downto 0);
      signal host_data_wr_i         : std_logic_vector(7  downto 0);
      
begin
    clk_126m_o          <= clk_sdram_i;
    
    --                      3333222211110000
    baudrate            <= "0000110011010001";
    
    --                      2211110000
    mem_refresh_rate    <= "0101110010";
    
    simulation          <= '0';
    
    pll_control_comp : entity pll_control.pll_control(rtl)
    port map (
        refclk      => clk_50m_i,    --  refclk.clk
        rst         => not reset_i,      --  reset.reset
        outclk_0    => clk_sdram_i,  --  outclk0.clk
        locked      => i_pll_locked  --  locked.export
    );
        
    memory_interface: entity work.sdram_interface(rtl)
    port map (
        -- Host side - CPU1
        host_request_i          => host_request_i,
        host_done_o             => host_done_o,
        host_addr_i             => host_addr_i,
        host_we_i               => host_we_i,
        host_data_rd_o          => host_data_rd_o,
        host_data_wr_i          => host_data_wr_i,
        
        sdram_ready_o           => sdram_ready_o,
        refresh_busy_o          => refresh_busy_o,
        memory_busy_o           => memory_busy_o,
        
        -- SDRAM side
        sdCke_o                 => sdCke_o,
        sdCe_bo                 => sdCe_bo,
        sdRas_bo                => sdRas_bo,
        sdCas_bo                => sdCas_bo,
        sdWe_bo                 => sdWe_bo,
        sdBs_o                  => sdBs_o,
        sdAddr_o                => sdAddr_o,
        sdData0_io              => sdData0_io,
        sdData1_io              => sdData1_io,
        sdDqml0_o               => sdDqml0_o,
        sdDqmh0_o               => sdDqmh0_o,
        sdDqml1_o               => sdDqml1_o,
        sdDqmh1_o               => sdDqmh1_o,
                                    
        -- system interface
        simulation              => simulation,
        refresh_rate_i          => mem_refresh_rate,
        clk_sdram_i             => clk_sdram_i,
        reset_i                 => reset_i
        );    
    
    usart_dma : entity work.usart_dma(rtl)
    port map ( 
        -- usart interface
        txd_line                => txd_line,
        rxd_line                => rxd_line,
       
        -- memory interface
        mem_rw_req_o            => host_request_i,
        mem_rw_done_i           => host_done_o,
        mem_addr_o              => host_addr_i,
        mem_wr_en_o             => host_we_i,
        mem_data_rd_i           => host_data_rd_o,
        mem_data_wr_o           => host_data_wr_i,
        
        dma_busy_o              => dma_busy_o,

        -- system interface
        baudrate                => baudrate,
        master_clk_i            => clk_sdram_i,
        reset_i                 => reset_i
    ); 
    
    
    
end rtl;
    