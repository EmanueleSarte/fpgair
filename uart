----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 13.11.2023 11:14:19
-- Design Name: 
-- Module Name: top - Behavioral
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

entity uart_tx is
    GENERIC (
        CLK_FREQ : POSITIVE := 100000000;
        BAUD_RATE : POSITIVE := 1000000
    );
    port(
        clk: in std_logic;
        data_valid: in std_logic;
        data: in std_logic_vector(7 downto 0);
        reset: in std_logic;
        busy: out std_logic;
        uart_tx_out: out std_logic
    );
end uart_tx;

architecture Behavioral of uart_tx is

--    COMPONENT ila_0
--        PORT (
--            clk : IN STD_LOGIC;
--            probe0 : IN STD_LOGIC_VECTOR(0 DOWNTO 0); 
--            probe1 : IN STD_LOGIC_VECTOR(0 DOWNTO 0);
--            probe2 : IN STD_LOGIC_VECTOR(0 DOWNTO 0)
--        );
--    END COMPONENT;

    component baud_gen is
        GENERIC (
        CLK_FREQ : POSITIVE := CLK_FREQ;
        BAUD_RATE : POSITIVE := BAUD_RATE;
        ACTIVE_BIT : STD_LOGIC := '1';
        DELAY : NATURAL := 0
        );
        PORT (
            clk : IN STD_LOGIC;
            active : IN STD_LOGIC;
            baud_out : OUT STD_LOGIC
        );
    end component;
    component tx_fsm is
        port(
            clk: in std_logic;
            baudrate_out: in std_logic;
            data_valid: in std_logic;
            data: in std_logic_vector(7 downto 0);
            reset: in std_logic;
            activate_sample_gen: out std_logic;
            uart_tx: out std_logic;
            busy: out std_logic
        );
    end component;
    
    signal baud_wire : std_logic := '0';
    signal activate_gen_wire: STD_LOGIC := '1';

begin

my_baudgen: baud_gen
    port map(
        clk => clk,
        baud_out => baud_wire,
        active => activate_gen_wire
    );
    
my_tx_fsm: tx_fsm
    port map(
        clk => clk,
        baudrate_out => baud_wire,
        reset => reset,
        data_valid => data_valid,
        data => data,
        activate_sample_gen => activate_gen_wire,
        uart_tx => uart_tx_out,
        busy => busy
    );

--debug_core : ila_0
--PORT MAP (
--	clk => clk,
--	probe0(0) => baud_wire, 
--	probe1(0) => data(2),
--	probe2(0) => data(3)
--);

end Behavioral;
