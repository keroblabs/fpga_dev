library IEEE;
use ieee.std_logic_1164.ALL;
use ieee.numeric_std.all;
use ieee.std_logic_unsigned.all;

entity sdram_interface is
    generic (
        REFRESH_MAX_CNT         : integer := 1024;
        DEFAULT_REFRESH_RATE    : integer := 880
    );
    
    port(
        -- host interface
        host_request_i      : in  std_logic;
        host_done_o         : out std_logic;
        host_addr_i         : in  std_logic_vector(25 downto 0);
        host_we_i           : in  std_logic;
        host_data_rd_o      : out std_logic_vector(7  downto 0);
        host_data_wr_i      : in  std_logic_vector(7  downto 0);

        sdram_ready_o       : out std_logic := '0';    -- Set to '1' when the memory is ready
        refresh_busy_o      : out std_logic := '0';
        memory_busy_o       : out std_logic := '0';

        -- sdram interface
        sdCke_o             : out std_logic;           -- Clock-enable to SDRAM
        sdCe_bo             : out std_logic;           -- Chip-select to SDRAM
        sdRas_bo            : out std_logic;           -- SDRAM row address strobe
        sdCas_bo            : out std_logic;           -- SDRAM column address strobe
        sdWe_bo             : out std_logic;           -- SDRAM write enable
        sdBs_o              : out std_logic_vector( 1 downto 0);   -- SDRAM bank address
        sdAddr_o            : out std_logic_vector(12 downto 0);   -- SDRAM row/column address
        sdData0_io          : inout std_logic_vector(15 downto 0); -- Data to/from SDRAM
        sdData1_io          : inout std_logic_vector(15 downto 0); -- Data to/from SDRAM
        sdDqml0_o           : out std_logic;           -- Enable lower-byte of SDRAM databus if true
        sdDqmh0_o           : out std_logic;           -- Enable upper-byte of SDRAM databus if true
        sdDqml1_o           : out std_logic;           -- Enable lower-byte of SDRAM databus if true
        sdDqmh1_o           : out std_logic;           -- Enable upper-byte of SDRAM databus if true

        -- system inteface
        simulation          : in  std_logic;
        refresh_rate_i      : in  std_logic_vector(9 downto 0);
        clk_sdram_i         : in  std_logic;            -- Master clock
        reset_i             : in  std_logic             -- Reset, active low
    );

end sdram_interface;

architecture rtl of sdram_interface is
    type fsm_state_type is (STATE_IDLE, STATE_STARTED, STATE_BUSY, STATE_DONE, STATE_WAIT, 
                            STATE_REFRESH_STARTED, STATE_REFRESH_BUSY);

    signal state_x          : fsm_state_type := STATE_IDLE;
    signal state_r          : fsm_state_type := STATE_IDLE;

    signal mem_rw_x         : std_logic := '0';
    signal mem_rw_r         : std_logic := '0';
    
    signal mem_we_x         : std_logic := '0';
    signal mem_we_r         : std_logic := '0';
    
    signal host_done_x      : std_logic := '0';
    signal host_done_r      : std_logic := '0';

    signal mem_data_x       : std_logic_vector(31 downto 0);
    signal mem_data_r       : std_logic_vector(31 downto 0);

    signal mem_addr_x       : std_logic_vector(23 downto 0);
    signal mem_addr_r       : std_logic_vector(23 downto 0);
    
    signal host_data_rd_x   : std_logic_vector(7 downto 0);
    signal host_data_rd_r   : std_logic_vector(7 downto 0);

    signal lb0_x, ub0_x     : std_logic;
    signal lb1_x, ub1_x     : std_logic;
    signal lb0_r, ub0_r     : std_logic;
    signal lb1_r, ub1_r     : std_logic;

    signal mem_refresh_x    : std_logic := '0';
    signal mem_refresh_r    : std_logic := '0';

    signal refresh_timer_x  : integer range 0 to REFRESH_MAX_CNT-1 := 0;
    signal refresh_timer_r  : integer range 0 to REFRESH_MAX_CNT-1 := 0;

    signal refresh_rate_r   : integer range 0 to REFRESH_MAX_CNT-1 := 0;
    
    signal mem_done_i       : std_logic;
    signal mem_data_i       : std_logic_vector(31 downto 0);

begin

    host_done_o             <= host_done_r;
    host_data_rd_o          <= host_data_rd_r;
    refresh_busy_o          <= mem_refresh_r;
    memory_busy_o           <= mem_rw_r;

    sdram_module: entity work.sdram_module(rtl)
    port map (
        -- Host side
        refresh_i               => mem_refresh_r,
        rw_i                    => mem_rw_r,
        we_i                    => mem_we_r,
        addr_i                  => mem_addr_r,
        data_i                  => mem_data_r,
        lb0_i                   => lb0_r,
        ub0_i                   => ub0_r,
        lb1_i                   => lb1_r,
        ub1_i                   => ub1_r,
        ready_o                 => sdram_ready_o,
        done_o                  => mem_done_i,
        data_o                  => mem_data_i,
        
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
        sdDqmh0_o               => sdDqmh0_o,
        sdDqml0_o               => sdDqml0_o,
        sdDqmh1_o               => sdDqmh1_o,
        sdDqml1_o               => sdDqml1_o,
        
        -- system interface
        simulation              => simulation,
        clk_sdram_i             => clk_sdram_i,
        reset_i                 => reset_i

        );    

    process(state_r, refresh_timer_r, mem_refresh_r, mem_rw_r, mem_addr_r, mem_data_r,
            host_done_r, host_data_rd_r, mem_we_r, lb0_r, ub0_r, lb1_r, ub1_r,
            refresh_rate_r,
            host_request_i, host_addr_i, host_we_i, host_data_wr_i, 
            mem_data_i, mem_done_i)
    begin
        state_x             <= state_r;
        refresh_timer_x     <= refresh_timer_r + 1;
        
        mem_refresh_x       <= mem_refresh_r;
        mem_rw_x            <= mem_rw_r;
        mem_addr_x          <= mem_addr_r;
        mem_data_x          <= mem_data_r;

        host_done_x         <= host_done_r;
        host_data_rd_x      <= host_data_rd_r;
        mem_we_x            <= mem_we_r;
        
        lb0_x               <= lb0_r;
        ub0_x               <= ub0_r;
        lb1_x               <= lb1_r;
        ub1_x               <= ub1_r;
        
        case state_r is
            when STATE_IDLE =>

                if (refresh_timer_r > refresh_rate_r) then
                    state_x             <= STATE_REFRESH_STARTED;
                    refresh_timer_x     <= 0;
                    mem_refresh_x       <= '1';

                elsif (host_request_i = '1') then
                    state_x             <= STATE_STARTED;
                    mem_rw_x            <= '1';
                    mem_we_x            <= host_we_i;
                    mem_addr_x          <= host_addr_i(25 downto 2);
                    
                    if (host_addr_i(1 downto 0) = "00") then lb0_x <= '0'; else lb0_x <= not host_we_i; end if;
                    if (host_addr_i(1 downto 0) = "01") then ub0_x <= '0'; else ub0_x <= not host_we_i; end if;
                    if (host_addr_i(1 downto 0) = "10") then lb1_x <= '0'; else lb1_x <= not host_we_i; end if;
                    if (host_addr_i(1 downto 0) = "11") then ub1_x <= '0'; else ub1_x <= not host_we_i; end if;

                    if (host_we_i = '0') then
                        if (host_addr_i(1 downto 0) = "00") then mem_data_x(7  downto  0) <= host_data_wr_i; else mem_data_x(7  downto  0) <= "00000000"; end if;
                        if (host_addr_i(1 downto 0) = "01") then mem_data_x(15 downto  8) <= host_data_wr_i; else mem_data_x(15 downto  8) <= "00000000"; end if;
                        if (host_addr_i(1 downto 0) = "10") then mem_data_x(23 downto 16) <= host_data_wr_i; else mem_data_x(23 downto 16) <= "00000000"; end if;
                        if (host_addr_i(1 downto 0) = "11") then mem_data_x(31 downto 24) <= host_data_wr_i; else mem_data_x(31 downto 24) <= "00000000"; end if;
                        
                    end if;
                    
                end if;
                
            when STATE_REFRESH_STARTED =>
                if (mem_done_i = '0') then
                    state_x         <= STATE_REFRESH_BUSY;
                    
                end if;
                
            when STATE_REFRESH_BUSY =>
                if (mem_done_i = '1') then
                    state_x         <= STATE_IDLE;
                    mem_refresh_x   <= '0';

                end if;

            when STATE_STARTED =>
                if (mem_done_i = '0') then
                    state_x         <= STATE_BUSY;
                    
                end if;
                    
            when STATE_BUSY =>
                if (mem_done_i = '1') then
                    state_x         <= STATE_DONE;
                    
                    lb0_x           <= '0';
                    ub0_x           <= '0';
                    lb0_x           <= '0';
                    ub1_x           <= '0';
                    
                    mem_rw_x        <= '0';

                    if (host_we_i = '1') then
                        if    (host_addr_i(1 downto 0) = "00") then host_data_rd_x  <= mem_data_i(7 downto 0);
                        elsif (host_addr_i(1 downto 0) = "01") then host_data_rd_x  <= mem_data_i(15 downto 8);
                        elsif (host_addr_i(1 downto 0) = "10") then host_data_rd_x  <= mem_data_i(23 downto 16);
                        elsif (host_addr_i(1 downto 0) = "11") then host_data_rd_x  <= mem_data_i(31 downto 24);
                            
                        end if;
                    end if;
                end if;
                
            when STATE_DONE =>
                state_x         <= STATE_WAIT;
                host_done_x     <= '1';

            when STATE_WAIT =>                
                if (host_request_i = '0') then
                    state_x     <= STATE_IDLE;
                    host_done_x <= '0';
                    
                end if;
        end case;
    end process;

    process (clk_sdram_i)
    begin
        if rising_edge(clk_sdram_i) then
            if (reset_i = '0') then
                state_r                 <= STATE_IDLE;
                refresh_timer_r         <= 0;
                
                mem_refresh_r           <= '0';
                mem_rw_r                <= '0';
                mem_addr_r              <= "000000000000000000000000";
                mem_data_r              <= "00000000000000000000000000000000";
                
                host_done_r             <= '0';
                host_data_rd_r          <= "00000000";
                mem_we_r                <= '0';
                
                lb0_r                   <= '0';
                ub0_r                   <= '0';
                lb1_r                   <= '0';
                ub1_r                   <= '0';  

            else
                state_r                 <= state_x;
                refresh_timer_r         <= refresh_timer_x;

                mem_refresh_r           <= mem_refresh_x;
                mem_rw_r                <= mem_rw_x;
                mem_addr_r              <= mem_addr_x;
                mem_data_r              <= mem_data_x;
                
                host_done_r             <= host_done_x;
                host_data_rd_r          <= host_data_rd_x;
                mem_we_r                <= mem_we_x;
               
                lb0_r                   <= lb0_x;
                ub0_r                   <= ub0_x;
                lb1_r                   <= lb1_x;
                ub1_r                   <= ub1_x;  
                
                refresh_rate_r          <= to_integer(signed(refresh_rate_i));

            end if;
      end if;
    end process;
    
end rtl;
