----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 15.11.2023 09:55:29
-- Design Name: 
-- Module Name: tx_fsm - Behavioral
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

ENTITY tx_fsm IS
    PORT (
        clk : IN STD_LOGIC;
        baudrate_out : IN STD_LOGIC;
        data_valid : IN STD_LOGIC;
        data : IN STD_LOGIC_VECTOR(7 DOWNTO 0);
        reset : in std_logic;
        activate_sample_gen : OUT STD_LOGIC;
        uart_tx : OUT STD_LOGIC;
        busy : OUT STD_LOGIC
    );
END tx_fsm;

ARCHITECTURE Behavioral OF tx_fsm IS

    TYPE state_t IS (IDLE, VALID, START, BIT0, BIT1, BIT2, BIT3, BIT4, BIT5, BIT6, BIT7, SSTOP);
    SIGNAL state : state_t := IDLE;
--    SIGNAL nextstate : state_t;
    SIGNAL databuf : STD_LOGIC_VECTOR(7 DOWNTO 0);
    CONSTANT idle_bit : STD_LOGIC := '1';
    CONSTANT start_bit : STD_LOGIC := '0';
    CONSTANT stop_bit : STD_LOGIC := '1';
    
    signal busy_wire : STD_LOGIC := '0';
    signal uart_tx_signal : std_logic := idle_bit;

BEGIN

    busy <= busy_wire OR data_valid;

    PROCESS (clk, reset) IS
    BEGIN
        
        if rising_edge(clk) THEN 
            if reset = '1' then
                state <= IDLE;  
                uart_tx_signal <= idle_bit;
            end if;
            CASE state IS
                WHEN IDLE =>
                    uart_tx_signal <= idle_bit;
                    busy_wire <= '0';
                    activate_sample_gen <= '0';
                    IF data_valid = '1' THEN
                        busy_wire <= '1';
                        databuf <= data;
                        activate_sample_gen <= '1';
                        state <= START;
                    END IF;
    
--                WHEN VALID =>
--                    busy <= '1';
--                    state <= START;
    
                WHEN START =>
                    uart_tx_signal <= start_bit;
                    IF baudrate_out = '1' THEN
                        state <= BIT0;
                    END IF;
    
                WHEN BIT0 =>
                    uart_tx_signal <= databuf(0);
                    IF baudrate_out = '1' THEN
                        state <= BIT1;
                    END IF;
                WHEN BIT1 =>
                    uart_tx_signal <= databuf(1);
                    IF baudrate_out = '1' THEN
                        state <= BIT2;
                    END IF;
                WHEN BIT2 =>
                    uart_tx_signal <= databuf(2);
                    IF baudrate_out = '1' THEN
                        state <= BIT3;
                    END IF;
                WHEN BIT3 =>
                    uart_tx_signal <= databuf(3);
                    IF baudrate_out = '1' THEN
                        state <= BIT4;
                    END IF;
                WHEN BIT4 =>
                    uart_tx_signal <= databuf(4);
                    IF baudrate_out = '1' THEN
                        state <= BIT5;
                    END IF;
                WHEN BIT5 =>
                    uart_tx_signal <= databuf(5);
                    IF baudrate_out = '1' THEN
                        state <= BIT6;
                    END IF;
                WHEN BIT6 =>
                    uart_tx_signal <= databuf(6);
                    IF baudrate_out = '1' THEN
                        state <= BIT7;
                    END IF;
                WHEN BIT7 =>
                    uart_tx_signal <= databuf(7);
                    IF baudrate_out = '1' THEN
                        state <= SSTOP;
                    END IF;
                WHEN SSTOP =>
                    uart_tx_signal <= stop_bit;
                    IF baudrate_out = '1' THEN
                        state <= IDLE;
                    END IF;
                WHEN OTHERS =>
                    state <= IDLE;
            END CASE;
        end if;
    END PROCESS;
    
    uart_tx <= uart_tx_signal;
    

END Behavioral;