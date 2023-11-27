library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;

entity usart_dma is
    generic(
        DEBUG_RATE_MAX          : integer := 500000000;
        DEBUG_RATE              : integer := 400000000
    );
    
    Port ( 
        -- usart interface
        txd_line                : out   std_logic;
        rxd_line                : in    std_logic;
        
        -- memory interface
        mem_wr_en_o             : out   std_logic;
        mem_addr_o              : out   std_logic_vector(25 downto 0);
        mem_rw_req_o            : out   std_logic;
        mem_rw_done_i           : in    std_logic;
        mem_data_rd_i           : in    std_logic_vector(7 downto 0);
        mem_data_wr_o           : out   std_logic_vector(7 downto 0);
        
        -- debug lines
        dma_busy_o              : out   std_logic;

        -- system interface
        baudrate                : in    std_logic_vector(15 downto 0) := "0000000000000000";
        master_clk_i            : in    std_logic;
        reset_i                 : in    std_logic
    );    
end usart_dma;

architecture rtl of usart_dma is
    type fsm_state_type  is (STATE_IDLE, STATE_WAIT, STATE_ADDR0, STATE_ADDR1, STATE_ADDR2, 
                             STATE_DATA_RD0_D, STATE_DATA_RD0, STATE_DATA_RD1_D, STATE_DATA_RD1, STATE_DATA_RD2, STATE_DATA_RD3, STATE_DATA_RD4,
                             STATE_DATA_WR0, STATE_DATA_WR1, STATE_DATA_WR2_D, STATE_DATA_WR2, STATE_DATA_WR3,
                             STATE_DEBUG_0, STATE_DEBUG_1, STATE_DEBUG_2_D, STATE_DEBUG_2, STATE_DEBUG_3 );

    signal state_x              : fsm_state_type := STATE_IDLE;
    signal state_r              : fsm_state_type := STATE_IDLE;

    signal state_next_x         : fsm_state_type := STATE_IDLE;
    signal state_next_r         : fsm_state_type := STATE_IDLE;

    signal rx_byte_t            : std_logic_vector(7 downto 0);
    signal rx_byte_r            : std_logic_vector(7 downto 0);

    signal tx_byte_x            : std_logic_vector(7 downto 0);
    signal tx_byte_r            : std_logic_vector(7 downto 0);

    signal rx_done_t            : std_logic;
    signal rx_done_r            : std_logic;

    signal tx_trigger_x         : std_logic;
    signal tx_trigger_r         : std_logic;

    signal dma_busy_x           : std_logic;
    signal dma_busy_r           : std_logic;

    signal tx_empty_t           : std_logic;
    signal tx_empty_r           : std_logic;

    signal debug_flipflop_x     : std_logic;
    signal debug_flipflop_r     : std_logic;

    signal write_en_x           : std_logic;
    signal write_en_r           : std_logic;
    
    signal data_wr_x            : std_logic_vector(7 downto 0);
    signal data_wr_r            : std_logic_vector(7 downto 0);

    signal req_addr_x           : std_logic_vector(25 downto 0);
    signal req_addr_r           : std_logic_vector(25 downto 0);
   
    signal mem_wr_en_x          : std_logic;
    signal mem_wr_en_r          : std_logic;

    signal mem_addr_x           : std_logic_vector(25 downto 0);
    signal mem_addr_r           : std_logic_vector(25 downto 0);

    signal mem_rw_req_x         : std_logic;
    signal mem_rw_req_r         : std_logic;

    signal mem_data_wr_x        : std_logic_vector(7 downto 0);
    signal mem_data_wr_r        : std_logic_vector(7 downto 0);

    signal mem_rw_done_r        : std_logic;
    signal mem_data_rd_r        : std_logic_vector(7 downto 0);
    
    signal debug_timer_x        : integer range 0 to DEBUG_RATE_MAX-1 := 0;
    signal debug_timer_r        : integer range 0 to DEBUG_RATE_MAX-1 := 0;

    signal debug_rate_r         : integer range 0 to DEBUG_RATE_MAX-1 := 0;

    signal debug_info_x         : std_logic_vector(7 downto 0);
    signal debug_info_r         : std_logic_vector(7 downto 0);


begin    
    
    mem_wr_en_o             <= mem_wr_en_r;
    mem_rw_req_o            <= mem_rw_req_r;
    mem_data_wr_o           <= mem_data_wr_r;
    mem_addr_o              <= mem_addr_r;
    dma_busy_o              <= dma_busy_r;
    
    usart_tx_block : entity work.usart_tx_module(rtl)
    port map (
        
        -- Control bit
        txd_empty_o         => tx_empty_t,
        txd_trigger_i       => tx_trigger_r,

        -- host interface
        txd_data_i          => tx_byte_r,
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
        rxd_done_o          => rx_done_t,
    
        -- host interface
        rxd_data_o          => rx_byte_t,
        baudrate_i          => baudrate,
        
        -- hardware pins
        rxd_line_i          => rxd_line,

        -- system inteface
        master_clk_i        => master_clk_i,
        reset_i             => reset_i
    );
    
    process(state_r, state_next_r, write_en_r, rx_done_r, tx_empty_r, rx_byte_r, tx_trigger_r,
            mem_wr_en_r, mem_addr_r, mem_data_wr_r, mem_rw_req_r, dma_busy_r,
            debug_timer_r, debug_info_r, debug_rate_r, debug_flipflop_r,
            tx_byte_r, req_addr_r, mem_rw_done_r, mem_data_rd_r)
    begin
        debug_timer_x       <= debug_timer_r   + 1;

        state_x             <= state_r;
        state_next_x        <= state_next_r;
        write_en_x          <= write_en_r;                
        tx_trigger_x        <= tx_trigger_r;
        req_addr_x          <= req_addr_r;
        
        tx_byte_x           <= tx_byte_r;
        
        mem_wr_en_x         <= mem_wr_en_r;
        mem_addr_x          <= mem_addr_r;
        mem_data_wr_x       <= mem_data_wr_r;
        mem_rw_req_x        <= mem_rw_req_r;

        dma_busy_x          <= dma_busy_r;
        debug_info_x        <= debug_info_r;
        
        debug_flipflop_x    <= debug_flipflop_r;

        if ((debug_timer_r > debug_rate_r) and (state_r /= STATE_IDLE)) then
            state_x         <= STATE_IDLE;      

        end if;
            
        case state_r is
            when STATE_IDLE =>
                if (debug_timer_r > debug_rate_r) then
                    
                    if (debug_flipflop_r = '0') then
                        debug_info_x            <= debug_info_r    + 1;
                        mem_addr_x              <= req_addr_r;
                        mem_data_wr_x           <= debug_info_r;
                        mem_wr_en_x             <= '0';
                        state_x                 <= STATE_DEBUG_0;
                        debug_flipflop_x        <= '1';
                        
                    else
                        mem_addr_x              <= req_addr_r;
                        mem_wr_en_x             <= '1';
                        state_x                 <= STATE_DEBUG_3;
                        debug_flipflop_x        <= '0';

                    end if;
                    
                    debug_timer_x               <= 0;

                elsif (rx_done_r = '1') then
                    if (rx_byte_r(7 downto 6) = "10") then
                        state_next_x                <= STATE_ADDR0;
                        state_x                     <= STATE_WAIT;
                        write_en_x                  <= rx_byte_r(5);
                        req_addr_x(25 downto 21)    <= rx_byte_r(4 downto 0);
                        dma_busy_x                  <= '1';

                    elsif ((rx_byte_r(7 downto 6) = "11") and (rx_byte_r(4 downto 0) = "00011")) then
                        state_x                     <= STATE_WAIT;
                        write_en_x                  <= rx_byte_r(5);
                        dma_busy_x                  <= '1';

                        if (rx_byte_r(5) = '1') then
                            state_next_x            <= STATE_DATA_RD0;
                            
                        else
                            state_next_x            <= STATE_DATA_WR0;
                            
                        end if;
                        
                    end if;
                end if;

            when STATE_WAIT =>
                if (rx_done_r = '0') then
                    state_x                     <= state_next_r;
                end if;

            when STATE_ADDR0 =>
                if (rx_done_r = '1') then
                    if (rx_byte_r(7) = '0') then
                        state_next_x                <= STATE_ADDR1;
                        state_x                     <= STATE_WAIT;
                        req_addr_x(20 downto 14)    <= rx_byte_r(6 downto 0);
                        
                    else
                        state_x                     <= STATE_IDLE;
                        
                    end if;

                end if;
        
            when STATE_ADDR1 =>
                if (rx_done_r = '1') then
                    if (rx_byte_r(7) = '0') then
                        state_next_x                <= STATE_ADDR2;
                        state_x                     <= STATE_WAIT;
                        req_addr_x(13 downto 7)     <= rx_byte_r(6 downto 0);
                        
                    else
                        state_x                     <= STATE_IDLE;
                        
                    end if;
                    
                end if;

            when STATE_ADDR2 =>
                if (rx_done_r = '1') then
                    if (rx_byte_r(7) = '0') then
                        if (write_en_r = '1') then
                            state_next_x            <= STATE_DATA_RD0_D;
                            mem_wr_en_x             <= write_en_r;

                            mem_addr_x(25 downto 7) <= req_addr_r(25 downto 7);
                            mem_addr_x(6 downto 0)  <= rx_byte_r(6 downto 0);

                        else
                            state_next_x            <= STATE_DATA_WR0;
                            
                        end if;
                        
                        state_x                     <= STATE_WAIT;
                        req_addr_x(6 downto 0)      <= rx_byte_r(6 downto 0);

                    else
                        state_x                     <= STATE_IDLE;
                        
                    end if;
                end if;
                
            when STATE_DATA_RD0_D =>
                state_x                         <= STATE_DATA_RD0;

            when STATE_DATA_RD0 =>
                state_x                         <= STATE_DATA_RD1_D;
                mem_rw_req_x                    <= '1';
                
            when STATE_DATA_RD1_D =>
                if (mem_rw_done_r = '0') then
                    state_x                     <= STATE_DATA_RD1;
                end if;

            when STATE_DATA_RD1 =>
                if (mem_rw_done_r = '1') then
                    mem_rw_req_x                <= '0';
                    tx_byte_x                   <= mem_data_rd_r;
                    state_x                     <= STATE_DATA_RD2;
                end if;

            when STATE_DATA_RD2 =>
                tx_trigger_x                    <= '1';
                state_x                         <= STATE_DATA_RD3;

            when STATE_DATA_RD3 =>
                if (tx_empty_r = '0') then
                    tx_trigger_x                <= '0';
                    state_x                     <= STATE_DATA_RD4;
                end if;

            when STATE_DATA_RD4 =>
                if (tx_empty_r = '1') then
                    --req_addr_x                  <= req_addr_r + 1;
                    state_x                     <= STATE_IDLE;
                    dma_busy_x                  <= '0';

                end if;

            when STATE_DATA_WR0 =>
                if (rx_done_r = '1') then
                    mem_addr_x                  <= req_addr_r;
                    mem_data_wr_x               <= rx_byte_r;
                    mem_wr_en_x                 <= write_en_r;
                    state_next_x                <= STATE_DATA_WR1;
                    state_x                     <= STATE_WAIT;

                end if;
                
            when STATE_DATA_WR1 =>
                state_x                         <= STATE_DATA_WR2;

            when STATE_DATA_WR2 =>
                mem_rw_req_x                    <= '1';
                state_x                         <= STATE_DATA_WR2_D;

            when STATE_DATA_WR2_D =>
                if (mem_rw_done_r = '0') then
                    state_x                     <= STATE_DATA_WR3;
                end if;

            when STATE_DATA_WR3 =>
                if (mem_rw_done_r = '1') then
                    mem_rw_req_x                <= '0';
                    --req_addr_x                  <= req_addr_r + 1;
                    state_x                     <= STATE_IDLE;
                    dma_busy_x                  <= '0';
                end if;
                
            when STATE_DEBUG_0 =>
                state_x                         <= STATE_DEBUG_1;

            when STATE_DEBUG_1 =>
                mem_rw_req_x                    <= '1';
                state_x                         <= STATE_DEBUG_2_D;
                
            when STATE_DEBUG_2_D =>
                if (mem_rw_done_r = '0') then
                    state_x                     <= STATE_DEBUG_2;
                end if;

            when STATE_DEBUG_2 =>
                if (mem_rw_done_r = '1') then
                    mem_rw_req_x                <= '0';
                    mem_addr_x                  <= req_addr_r;
                    mem_wr_en_x                 <= '1';
                    state_x                     <= STATE_DEBUG_3;

                end if;

            when STATE_DEBUG_3 =>
                state_x                         <= STATE_DATA_RD0;

        end case;
    end process;
    
    process (master_clk_i)
    begin
        if falling_edge(master_clk_i) then
            if (reset_i = '0') then
                state_r             <= STATE_IDLE;
                state_next_r        <= STATE_IDLE;
                write_en_r          <= '0';                
                rx_done_r           <= '0';
                tx_empty_r          <= '0';
                rx_byte_r           <= "00000000";
                tx_trigger_r        <= '0';
                req_addr_r          <= "00000000000000000000000000";
                
                tx_byte_r           <= "00000000";
                
                mem_wr_en_r         <= '0';
                mem_addr_r          <= "00000000000000000000000000";
                mem_data_wr_r       <= "00000000";
                mem_rw_req_r        <= '0';
                
                mem_rw_done_r       <= '0';
                mem_data_rd_r       <= "00000000";
                
                dma_busy_r          <= '0';
                
                debug_info_r        <= "00000000";
                debug_rate_r        <= DEBUG_RATE;
                debug_timer_r       <= 0;
                
                debug_flipflop_r    <= '0';

            else
                state_r             <= state_x;
                state_next_r        <= state_next_x;
                write_en_r          <= write_en_x;                
                rx_done_r           <= rx_done_t;
                tx_empty_r          <= tx_empty_t;
                rx_byte_r           <= rx_byte_t;
                tx_trigger_r        <= tx_trigger_x;
                req_addr_r          <= req_addr_x;

                tx_byte_r           <= tx_byte_x;

                mem_wr_en_r         <= mem_wr_en_x;
                mem_addr_r          <= mem_addr_x;
                mem_data_wr_r       <= mem_data_wr_x;
                mem_rw_req_r        <= mem_rw_req_x;

                mem_rw_done_r       <= mem_rw_done_i;
                mem_data_rd_r       <= mem_data_rd_i;
                
                dma_busy_r          <= dma_busy_x;
                
                debug_info_r        <= debug_info_x;
                debug_timer_r       <= debug_timer_x;
                
                debug_flipflop_r    <= debug_flipflop_x;
                
            end if;
      end if;
    end process;    
end rtl;