----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 13.11.2023 11:15:19
-- Design Name: 
-- Module Name: baud_gen - Behavioral
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

ENTITY baud_gen IS
    GENERIC (
        CLK_FREQ : POSITIVE := 10000;
        BAUD_RATE : POSITIVE := 500;
        ACTIVE_BIT : STD_LOGIC := '1';
        DELAY : NATURAL := 50
    );
    PORT (
        clk : IN STD_LOGIC;
        active : IN STD_LOGIC;
        baud_out : OUT STD_LOGIC
    );
END baud_gen;

ARCHITECTURE Behavioral OF baud_gen IS

    SIGNAL istep : NATURAL := CLK_FREQ / BAUD_RATE;
    SIGNAL actual_delay : NATURAL:= (DELAY * istep) / 100;
    SIGNAL counter : NATURAL := actual_delay;

BEGIN

    PROCESS (clk)
    BEGIN
        IF rising_edge(clk) THEN
            IF active = ACTIVE_BIT THEN
                IF counter = istep THEN
                    baud_out <= '1';
                    counter <= 1;
                ELSE
                    baud_out <= '0';
                    counter <= counter + 1;
                END IF;
            ELSE
                baud_out <= '0';
                counter <= actual_delay;
            END IF;
        END IF;
    END PROCESS;
END Behavioral;