library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;


-- This component performs the integer division between two unsigned integers

entity uint_divider is
    GENERIC(
        NUM_BITS    : POSITIVE  := 10       -- The bits of the dividend (also called here numerator)
    );
    PORT(
        clk         :   IN  STD_LOGIC;
        enable      :   IN  STD_LOGIC;                      -- activate the division component if '1' for one clock ycle 
        num         :   IN  INTEGER RANGE 0 TO 2**NUM_BITS-1;   -- The dividend
        den         :   IN  INTEGER RANGE 1 TO 2**NUM_BITS-1;   -- The divisor
        ready       :   OUT STD_LOGIC := '0';                   -- '1' when the division finished and the result is ready
        res         :   OUT INTEGER RANGE 0 TO 2**NUM_BITS-1 := 0   -- The result
    );
end uint_divider;

architecture Behavioral of uint_divider is
    
    CONSTANT DEN_BITS : POSITIVE  := NUM_BITS;  -- Number of bits of the divisor (also called here denominator) 
    
    SIGNAL enabled  :   STD_LOGIC := '0';                   -- '1' if it's actually calculating a division
    SIGNAL num_copy :   UNSIGNED(NUM_BITS-1 downto 0);      -- Internal storage of the numerator
    SIGNAL den_copy :   UNSIGNED(DEN_BITS-1 downto 0);      -- Internal storage of the denominator
    SIGNAL cnt_bits :   INTEGER     RANGE -1 to NUM_BITS-1 := 0;    -- it counts the steps of the division
    SIGNAL res_copy :   UNSIGNED(NUM_BITS-1 downto 0);              -- here we store the result and the intermediary results

begin

process(clk)
begin
    if rising_edge(clk) then
        ready <= '0';
        if enable = '1' then
        
            if num = 0 then -- If the numerator is zero, then output zero
                res <= 0;
                ready <= '1';
                enabled <= '0';
            else
                num_copy <= TO_UNSIGNED(num, NUM_BITS);         -- Store the numerator and the denominator
                den_copy <= TO_UNSIGNED(den, DEN_BITS);
                res_copy <= (others => '0');
                enabled <= '1';
                cnt_bits <= NUM_BITS - 1;                       -- Start the counter from as the index of the most significant bit
            end if;
        elsif enabled = '1' then
            if cnt_bits >= 0 then
                if den_copy < 2**(NUM_BITS - cnt_bits) then -- to avoid overflow
                    if shift_left(den_copy, cnt_bits) <= (num_copy - den_copy * res_copy) then
                         res_copy <= res_copy + 2**cnt_bits;
                    end if;
                end if;
                cnt_bits <= cnt_bits - 1;
            else
                res <= TO_INTEGER(res_copy);
                enabled <= '0';
                ready <= '1';
            end if;
        end if;
    end if;

end process;


end Behavioral;



















