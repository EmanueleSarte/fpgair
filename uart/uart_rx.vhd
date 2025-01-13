----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 23.11.2023 15:44:43
-- Design Name: 
-- Module Name: uart_rx - Behavioral
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


library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
--use IEEE.NUMERIC_STD.ALL;

-- Uncomment the following library declaration if instantiating
-- any Xilinx leaf cells in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

entity uart_rx is
    GENERIC (
            CLK_FREQ : POSITIVE := 100000000;
            BAUD_RATE : POSITIVE := 1000000
    );
    port(
        clk: in std_logic;
        uart_rx_in: in std_logic;
        reset: in std_logic;
        working: out std_logic;
        data_valid: out std_logic;
        data: out std_logic_vector(7 downto 0)
    );
end uart_rx;

architecture Behavioral of uart_rx is

--    COMPONENT ila_0
--        PORT (
--            clk : IN STD_LOGIC;
--            probe0 : IN STD_LOGIC_VECTOR(0 DOWNTO 0); 
--            probe1 : IN STD_LOGIC_VECTOR(0 DOWNTO 0);
--            probe2 : IN STD_LOGIC_VECTOR(0 DOWNTO 0)
--        );
--    END COMPONENT  ;

     COMPONENT rx_fsm IS
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
    END COMPONENT;
    
    COMPONENT baud_gen IS
        GENERIC (
            CLK_FREQ : POSITIVE := CLK_FREQ;
            BAUD_RATE : POSITIVE := BAUD_RATE;
            ACTIVE_BIT : STD_LOGIC := '1';
            DELAY : POSITIVE := 50
        );
        PORT (
            clk : IN STD_LOGIC;
            active : IN STD_LOGIC;
            baud_out : OUT STD_LOGIC
        );
    END COMPONENT;

    SIGNAL active_wire : STD_LOGIC := '0';
    SIGNAL baud_wire : STD_LOGIC := '0';

begin

my_baud_gen: baud_gen
    port map(
        clk => clk,
        active => active_wire,
        baud_out => baud_wire
    );
    
my_rx_fsm: rx_fsm
    port map(
        clk => clk,
        uart_rx => uart_rx_in,
        sample_gen_in => baud_wire,
        reset => reset,
        working => working,
        activate_sample_gen => active_wire, 
        data_valid => data_valid,
        data => data
    );

--debug_core : ila_0
--PORT MAP (
--	clk => clk,
--	probe0(0) => uart_rx, 
--	probe1(0) => baud_wire,
--	probe2(0) => active_wire
--);


end Behavioral;
