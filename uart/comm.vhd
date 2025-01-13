----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 23.12.2023 21:50:06
-- Design Name: 
-- Module Name: comm - Behavioral
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

entity comm is
    generic (
        CLK_FREQ    : POSITIVE := 100000000;
        BAUD_RATE   : POSITIVE := 1000000;
        BUF_SIZE    : POSITIVE := 131072
    );
    port(
        clk: in std_logic;
        uart_in: in std_logic;
        reset: in std_logic;        
        uart_out: out std_logic;
        data_in: in std_logic_vector(7 downto 0);
        write : in std_logic;
        read : in std_logic;
        data_out: out std_logic_vector(7 downto 0);
        data_available: out std_logic
    );
end comm;

architecture Behavioral of comm is

    component uart_tx is
        GENERIC (
            CLK_FREQ : POSITIVE := CLK_FREQ;
            BAUD_RATE : POSITIVE := BAUD_RATE
        );
        port(
            clk: in std_logic;
            data_valid: in std_logic;
            data: in std_logic_vector(7 downto 0);
            reset: in std_logic;
            busy: out std_logic;
            uart_tx_out: out std_logic
        );
    end component uart_tx;
    
    component uart_rx is
        GENERIC (
            CLK_FREQ : POSITIVE := CLK_FREQ;
            BAUD_RATE : POSITIVE := BAUD_RATE
        );
        port(
            clk: in std_logic;
            uart_rx_in: in std_logic;
            reset: in std_logic;
            data_valid: out std_logic;
            working: out std_logic;
            data: out std_logic_vector(7 downto 0)   
        );
    end component uart_rx;

    constant buff_size: natural := BUF_SIZE;
   
    type buff_type is array (0 to buff_size-1) of std_logic_vector (7 downto 0);   
    signal buff_tx : buff_type; 
--    signal buff_rx : buff_type; 
    
    signal istart_buff_tx : natural range 0 to (buff_size-1) := 0;
    signal istart_uart_tx: natural range 0 to (buff_size-1) := 0;
    signal valid_tx_wire: std_logic := '0';
    signal data_tx_wire: std_logic_vector(7 downto 0) := "00000000";
    signal busy_tx_wire: std_logic := '0';
    
    signal data_avl_wire : std_logic := '0';
--    signal istart_buff_rx : natural range 0 to (buff_size-1) := 0;
--    signal istart_uart_rx: natural range 0 to (buff_size-1) := 0;
    signal busy_rx_wire: std_logic := '0';
--    signal correct_busy : natural range 0 to 7 := 0;
    signal data_rx_wire: std_logic_vector(7 downto 0) := "00000000";
    signal valid_rx_wire: std_logic := '0';
    
begin



my_uart_tx: uart_tx
    port map(
        clk => clk,
        data_valid => valid_tx_wire,
        data => data_tx_wire,
        reset => reset,
        busy => busy_tx_wire,
        uart_tx_out => uart_out
    );
    
my_uart_rx: uart_rx
    port map(
        clk => clk,
        data => data_rx_wire,
        reset => reset,
        uart_rx_in => uart_in,
        working => busy_rx_wire,
        data_valid => valid_rx_wire
    );


write_to_buffer:
process(clk, reset) is
begin 
    if reset = '1' then
        istart_buff_tx <= 0;
  
    elsif rising_edge(clk) then
        if write = '1' then
            buff_tx(istart_buff_tx) <= data_in;
            
            if (istart_buff_tx + 1) = buff_size then
                istart_buff_tx <= 0;
            else
                istart_buff_tx <= istart_buff_tx + 1;
            end if;
        end if;
    end if; 
end process;

flush_buffer: 
process(clk, reset) is
begin
    if reset = '1' then
        istart_uart_tx <= 0;
        
    elsif rising_edge(clk) then
        valid_tx_wire <= '0'; 
        if not (istart_buff_tx = istart_uart_tx) then
            if busy_tx_wire = '0' then
                data_tx_wire <= buff_tx(istart_uart_tx);
                valid_tx_wire <= '1'; 
                
                if (istart_uart_tx + 1) = buff_size then
                    istart_uart_tx <= 0;
                else
                    istart_uart_tx <= istart_uart_tx + 1;
                end if;
            end if;
        end if;
    end if;
    
end process;


data_available <= data_avl_wire AND (NOT read);
handle_incoming_data:
process(clk, reset)
begin
    if reset = '1' then
        data_avl_wire <= '0';

    elsif rising_edge(clk) then
        if valid_rx_wire = '1' then        
            data_out <= data_rx_wire;  
            data_avl_wire <= '1'; 
        end if;
        
        if read = '1' then
            data_avl_wire <= '0';
        end if;
    end if;
end process;

--read_and_save_to_buffer:
--process(clk, reset) is
--begin
--    if reset = '1' then
--        istart_uart_rx <= 0;
        
--    elsif rising_edge(clk) then
--        if valid_rx_wire = '1' then        
--            buff_rx(istart_uart_rx) <= data_rx_wire;            
             
--            if (istart_uart_rx + 1) = buff_size then
--                istart_uart_rx <= 0;
--            else    
--                istart_uart_rx <= istart_uart_rx + 1;          
--            end if;
--        end if;
--    end if;
--end process;


--make_data_available:
--process(clk, reset) is
--begin
--    if reset = '1' then
--        istart_buff_rx <= 0;
        
--    elsif rising_edge(clk) then
--        data_out <= buff_rx(istart_buff_rx);
--        if read = '1' then
--            if (istart_buff_rx + 1) = buff_size then
--                istart_buff_rx <= 0;
--            else
--                istart_buff_rx <= istart_buff_rx + 1;
--            end if;
--            data_available <= '0';
--        else
--            if (istart_buff_rx = istart_uart_rx) then
--                data_available <= '0';
--            else
--                data_available <= '1';
--            end if;
--        end if;
--    end if;

--end process;



--set_available_signal: process(istart_buff_rx, istart_uart_rx, read) is
--begin
--    if istart_buff_rx = istart_uart_rx OR (read = '1' and (istart_uart_rx - istart_buff_rx) = 1) then
--        data_available <= '0';
--    else
--        data_available <= '1';    
--    end if;
--end process;

end Behavioral;

















