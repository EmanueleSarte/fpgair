----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 22.11.2023 13:48:43
-- Design Name: 
-- Module Name: rx_fsm - Behavioral
-- Project Name: 
-- Target Devices: 
-- Tool Versions: 
-- Description: 
-- 
-- Dependencies: 
-- 
-- Revision:
-- Revision 0.01 - File Created
-- Additional Comments:
-- 
----------------------------------------------------------------------------------
LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;

-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
--use IEEE.NUMERIC_STD.ALL;

-- Uncomment the following library declaration if instantiating
-- any Xilinx leaf cells in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

ENTITY rx_fsm IS
    PORT (
        clk : IN STD_LOGIC;
        uart_rx : IN STD_LOGIC;
        sample_gen_in : IN STD_LOGIC;
        reset : in STD_LOGIC;
        working : out std_logic;
        activate_sample_gen : OUT STD_LOGIC;
        data_valid : OUT STD_LOGIC;
        data : OUT STD_LOGIC_VECTOR(7 DOWNTO 0)
    );
END rx_fsm;

ARCHITECTURE Behavioral OF rx_fsm IS

--    COMPONENT ila_0
--        PORT (
--            clk : IN STD_LOGIC;
--            probe0 : IN STD_LOGIC_VECTOR(0 DOWNTO 0); 
--            probe1 : IN STD_LOGIC_VECTOR(0 DOWNTO 0);
--            probe2 : IN STD_LOGIC_VECTOR(0 DOWNTO 0)
--        );
--    END COMPONENT;

    TYPE state_t IS (IDLE, START, BIT0, BIT1, BIT2, BIT3, BIT4, BIT5, BIT6, BIT7, SSTOP, VALID);
    SIGNAL state : state_t := IDLE;
--    SIGNAL nextstate : state_t;
    SIGNAL databuf : STD_LOGIC_VECTOR(7 DOWNTO 0);
    
    CONSTANT idle_bit : STD_LOGIC := '1';
    CONSTANT start_bit : STD_LOGIC := '0';
    CONSTANT stop_bit : STD_LOGIC := '1';

BEGIN

    PROCESS (clk, reset) IS
    BEGIN
    
        if reset = '1' then
            state <= IDLE;
        elsif rising_edge(clk) THEN
            CASE state IS
                WHEN IDLE =>
--                    data <= (others => '0');
                    data_valid <= '0';
                    working <= '0';
                    activate_sample_gen <= '0';
                    
                    IF uart_rx = start_bit THEN
                        state <= START;
                    END IF;
    
                WHEN START =>
                    activate_sample_gen <= '1';
                    working <= '1';
                    
                    IF sample_gen_in = '1' THEN
                        state <= BIT0;
                    END IF;
    
                WHEN BIT0 =>
                    databuf(0) <= uart_rx;
                    
                    IF sample_gen_in = '1' THEN
                        state <= BIT1;
                    END IF;
                WHEN BIT1 =>
                    databuf(1) <= uart_rx;
                    
                    IF sample_gen_in = '1' THEN
                        state <= BIT2;
                    END IF;
                WHEN BIT2 =>
                    databuf(2) <= uart_rx;
                    
                    IF sample_gen_in = '1' THEN
                        state <= BIT3;
                    END IF;
                WHEN BIT3 =>
                    databuf(3) <= uart_rx;
                    
                    IF sample_gen_in = '1' THEN
                        state <= BIT4;
                    END IF;
                WHEN BIT4 =>
                    databuf(4) <= uart_rx;
                    
                    IF sample_gen_in = '1' THEN
                        state <= BIT5;
                    END IF;
                WHEN BIT5 =>
                    databuf(5) <= uart_rx;
                    
                    IF sample_gen_in = '1' THEN
                        state <= BIT6;
                    END IF;
                WHEN BIT6 =>
                    databuf(6) <= uart_rx;
                    
                    IF sample_gen_in = '1' THEN
                        state <= BIT7;
                    END IF;
                WHEN BIT7 =>
                    databuf(7) <= uart_rx;
                    
                    IF sample_gen_in = '1' THEN
                        state <= VALID;
                    END IF;
                WHEN VALID =>
                    data_valid <= '1';
                    data <= databuf;
                    state <= SSTOP;
                    
                WHEN SSTOP =>
                    data_valid <= '0';
                    
                    IF sample_gen_in = '1' THEN
                        state <= IDLE;
                    END IF;
                WHEN OTHERS =>
                    state <= IDLE;
            
            end case;       
        end if;
    END PROCESS;


END Behavioral;