library IEEE;

use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity freq_finder is
    GENERIC(
        FREQ     : POSITIVE  := 21500;                  -- The frequency to find in the samples
        FS       : POSITIVE  := 44100;                  -- Sampling frequency, should not be change, but for now it's here
        DATA_SIZE: POSITIVE  := 24;                     -- Dim of the sampled data
        BITS_BUF : POSITIVE  := 10;                     -- Bits for the number of sampling
        BITS_FREQ : POSITIVE  := 15;                    -- Bits needed to store all the possible 'FREQ'
        BITS_TRIG : POSITIVE  := 8;                     -- Bits of the cosine LUT
        BITS_OUT : POSITIVE  := 10                     -- Bits for the magnitude squared in output
    );
    port(
        clk:            in STD_LOGIC;
        reset:          in STD_LOGIC;
        sample:         in STD_LOGIC_VECTOR(DATA_SIZE-1 downto 0);
        data_valid:     in STD_LOGIC := '0';                            -- '1' if the sample is valid
        magnitude:      out NATURAL RANGE 0 TO 2**BITS_OUT-1;           
        ready:          out STD_LOGIC;                                  -- '1' when there is a magnitude ready
        
        db_tmp_cos:     out UNSIGNED(7 downto 0);                       -- for debugging, they will be optimized out if not used
        db_tmp_sin:     out UNSIGNED(7 downto 0);
        db_index1:       out UNSIGNED(63 downto 0);
        db_index2:       out UNSIGNED(63 downto 0);
        db_tot_cos:     out SIGNED(63 downto 0);
        db_tot_sin:     out SIGNED(63 downto 0);
        db_F_RMTE_FS:     out UNSIGNED(31 downto 0);
        db_REAL_MTE:     out UNSIGNED(31 downto 0);
        db_cnt_sample:     out UNSIGNED(15 downto 0)   
    );
end freq_finder;

architecture Behavioral of freq_finder is

    CONSTANT BITS_SAMPL     : POSITIVE := DATA_SIZE;            -- Alias of DATA_SIZE
    CONSTANT BUF_SIZE       : POSITIVE := 2**BITS_BUF;          -- Number of samples for a packet 
    CONSTANT BITS_TRIG_EFF  : POSITIVE := BITS_TRIG + 2;        -- Bits to encode the full cosine (all the 4 quadrants)
    CONSTANT MULT_TRIG      : POSITIVE := 2**BITS_TRIG;         -- Total numbers of value of the cosine in the LUT (first quadrant)
    CONSTANT REAL_MTE       : POSITIVE := 2**BITS_TRIG_EFF - 4; -- The maximum index for the full cosine (all 4 quadrants)
    CONSTANT REAL_MT        : POSITIVE := MULT_TRIG - 1;        -- The maximum index for the cosine (first quadrant)
    CONSTANT BITS_FS        : POSITIVE := 16;                   -- Bits to encode the sampling frequency, in our case is 44100 so 16 bits
    
    -- Bits to encode a constant useful in calculating the index for the cosine LUT
    CONSTANT BITS_FREQ_MTE  : POSITIVE := BITS_TRIG_EFF + BITS_FREQ + BITS_BUF  -BITS_FS;
    CONSTANT BITS_INDEX     : POSITIVE := BITS_TRIG_EFF;        -- Bits to encode the index for the cosine LUT
    -- Bits to encode the magnitude calculations
    CONSTANT BITS_MAGN      : POSITIVE := BITS_TRIG + BITS_BUF + BITS_SAMPL;
    
    CONSTANT RMT2           : POSITIVE := REAL_MT * 2;          -- Constant corresponding to pi for the cosine LUT
    CONSTANT RMT3           : POSITIVE := REAL_MT * 3;          -- Constant corresponding to 3/2 pi for the cosine LUT
    
    -- The cosine LUT, the input is a number between 0-255 and the output is cosine(input/255 * pi/2)*255
    type data_lut is array (0 to MULT_TRIG-1) of UNSIGNED(BITS_TRIG-1 downto 0);
    CONSTANT cos_lut        : data_lut := ("11111111", "11111111", "11111111", "11111111", "11111111", "11111111", "11111111", "11111111", "11111111", "11111111", "11111111", "11111110", "11111110", "11111110", "11111110", "11111110", "11111110", "11111110", "11111101", "11111101", "11111101", "11111101", "11111101", "11111100", "11111100", "11111100", "11111100", "11111011", "11111011", "11111011", "11111011", "11111010", "11111010", "11111010", "11111001", "11111001", "11111001", "11111000", "11111000", "11111000", "11110111", "11110111", "11110111", "11110110", "11110110", "11110101", "11110101", "11110100", "11110100", "11110011", "11110011", "11110011", "11110010", "11110010", "11110001", "11110001", "11110000", "11101111", "11101111", "11101110", "11101110", "11101101", "11101101", "11101100", "11101011", "11101011", "11101010", "11101010", "11101001", "11101000", "11101000", "11100111", "11100110", "11100110", "11100101", "11100100", "11100100", "11100011", "11100010", "11100001", "11100001", "11100000", "11011111", "11011110", "11011110", "11011101", "11011100", "11011011", "11011010", "11011010", "11011001", "11011000", "11010111", "11010110", "11010101", "11010101", "11010100", "11010011", "11010010", "11010001", "11010000", "11001111", "11001110", "11001101", "11001100", "11001011", "11001011", "11001010", "11001001", "11001000", "11000111", "11000110", "11000101", "11000100", "11000011", "11000010", "11000001", "11000000", "10111111", "10111110", "10111100", "10111011", "10111010", "10111001", "10111000", "10110111", "10110110", "10110101", "10110100", "10110011", "10110010", "10110000", "10101111", "10101110", "10101101", "10101100", "10101011", "10101001", "10101000", "10100111", "10100110", "10100101", "10100100", "10100010", "10100001", "10100000", "10011111", "10011101", "10011100", "10011011", "10011010", "10011000", "10010111", "10010110", "10010101", "10010011", "10010010", "10010001", "10001111", "10001110", "10001101", "10001100", "10001010", "10001001", "10001000", "10000110", "10000101", "10000100", "10000010", "10000001", "10000000", "01111110", "01111101", "01111011", "01111010", "01111001", "01110111", "01110110", "01110100", "01110011", "01110010", "01110000", "01101111", "01101101", "01101100", "01101011", "01101001", "01101000", "01100110", "01100101", "01100011", "01100010", "01100000", "01011111", "01011110", "01011100", "01011011", "01011001", "01011000", "01010110", "01010101", "01010011", "01010010", "01010000", "01001111", "01001101", "01001100", "01001010", "01001001", "01000111", "01000110", "01000100", "01000011", "01000001", "01000000", "00111110", "00111101", "00111011", "00111010", "00111000", "00110111", "00110101", "00110011", "00110010", "00110000", "00101111", "00101101", "00101100", "00101010", "00101001", "00100111", "00100110", "00100100", "00100010", "00100001", "00011111", "00011110", "00011100", "00011011", "00011001", "00011000", "00010110", "00010100", "00010011", "00010001", "00010000", "00001110", "00001101", "00001011", "00001001", "00001000", "00000110", "00000101", "00000011", "00000010", "00000000");
    
    -- We want to calculate freq * REAL_MTE * C / FS where C is a constant added to avoid the precision loss of the integer division (in this case 2**BITS_BUF)
    -- First we calculate REAL_MTE * C
    CONSTANT TMP1 : UNSIGNED(BITS_TRIG_EFF+BITS_BUF-1 downto 0) := shift_left(TO_UNSIGNED(REAL_MTE, BITS_TRIG_EFF+BITS_BUF), BITS_BUF);
    -- Then we multiply by the frequency 
    CONSTANT TMP2 : UNSIGNED(BITS_TRIG_EFF+BITS_BUF+BITS_FREQ-1 downto 0) := TO_UNSIGNED(FREQ, BITS_FREQ) * TMP1;
    -- Lastly we divide by FS to reduce the precision loss of the division
    CONSTANT TMP3 : UNSIGNED(BITS_TRIG_EFF+BITS_BUF+BITS_FREQ-1 downto 0) := TMP2 / TO_UNSIGNED(FS, BITS_FS);
    -- Then we put the result (trimmed) in the constant that we will use later
    CONSTANT F_RMTE_FS : UNSIGNED(BITS_FREQ_MTE-1 downto 0) := TMP3(BITS_FREQ_MTE-1 downto 0);
    
    SIGNAL tmp_sig          : UNSIGNED(63 downto 0)     := (others => '0'); -- temp signal for temp operations
    
    SIGNAL step             : NATURAL RANGE 0 TO 127    := 0;               -- keep track of the state 
    SIGNAL index            : UNSIGNED(BITS_INDEX-1 downto 0);              -- index for the cosine LUT
    SIGNAL cnt_sample       : UNSIGNED(BITS_BUF downto 0) := (others => '0'); -- counter for the number of samples received
    
    SIGNAL neg_cos          : STD_LOGIC := '0';         -- to change the sign of the cosine
    SIGNAL neg_sin          : STD_LOGIC := '0';         -- to change the sign of the sine
    SIGNAL tot_cos          : SIGNED(BITS_MAGN downto 0) := (others => '0');    -- store the total sum of sample*cos(x)
    SIGNAL tot_sin          : SIGNED(BITS_MAGN downto 0) := (others => '0');    -- store the total sum of sample*sin(x)
    SIGNAL tmp_cos          : NATURAL := 0;             -- tmp var for cosine
    SIGNAL tmp_sin          : NATURAL := 0;             -- tmp var for sine
    
    SIGNAL stored_sample    : STD_LOGIC_VECTOR(DATA_SIZE-1 downto 0);   -- Store the sample received by the uart

begin

add_sample: process(clk, reset)
begin
    if reset = '1' then
        cnt_sample <= (others => '0');
        ready <= '0';
        step <= 0;
        tot_cos <= (others => '0');
        tot_sin <= (others => '0');
        index <= (others => '0');
        tmp_cos <= 0;
        tmp_sin <= 0;
        magnitude <= 0;
        neg_sin <= '0';
        neg_cos <= '0';
        tmp_sig <= (others => '0');
        stored_sample <= (others => '0');
        
         
    elsif rising_edge(clk)  then
        ready <= '0';
        
        db_F_RMTE_FS(BITS_FREQ_MTE-1 downto 0) <= F_RMTE_FS;        -- debugging
        db_REAL_MTE <= TO_UNSIGNED(REAL_MTE, 32);                   -- debugging
        
        if data_valid = '1' then                                    -- If there is a valid sample
            if step = 0 then                                        -- And step is 0, as it always should be if there is a valid sample
                stored_sample <= sample;                            -- Store the sample
                cnt_sample <= cnt_sample + 1;                       -- Increase the sample counter for the next clock
                
                -- Multiply (Freq * MTE * C / FS) * cnt_sample, then shift away C (C = 2**BITS_BUF)
                tmp_sig(BITS_FREQ_MTE+BITS_BUF downto 0) <= shift_right(F_RMTE_FS * cnt_sample, BITS_BUF);
                
                neg_cos <= '0';                                     -- Reset the negative sign signals
                neg_sin <= '0';
                step <= 10;                                         -- advance the component's state
                
                db_cnt_sample(BITS_BUF downto 0) <= cnt_sample;     -- debugging
            end if;
            
        elsif step = 10 then                                        
            tmp_sig(BITS_FREQ_MTE downto 0) <= tmp_sig(BITS_FREQ_MTE downto 0) MOD REAL_MTE;        -- Mod the result of the previous multiplication
            step <= 15;                                             -- advance the component's state
            
        elsif step = 15 then
            index <= tmp_sig(BITS_INDEX-1 downto 0);                -- put the value from the temp signal to the index signal (trimmed correctly)
            step <= 20;
            
            db_index1(BITS_INDEX-1 downto 0) <= tmp_sig(BITS_TRIG_EFF-1 downto 0);  -- debugging
            
        elsif step = 20 then                                        
            -- Here we have 'index' that represent the angle in the unit circle, we want the cosine of that angle
            
            -- If 'index' is in the third quadrant, then we can map the index as if it was in the first quadrant
            if index > RMT3 then                                    
                index <= REAL_MTE - index;      -- analogous to cos(x) = cos(2pi - x) if x in [1.5pi, 2pi]
                neg_sin <= '1';                 -- keep track that the sine is negative after this transformation
            elsif index > RMT2 then
                index <= index - RMT2;          -- analogous to cos(x) = cos(x - pi) if x in [pi, 1.5pi]
                neg_sin <= '1';                 -- both sine and cosine are negative
                neg_cos <= '1';
            elsif index > REAL_MT then
                index <= RMT2 - index;          -- analogous to cos(x) = cos(pi - x) if x in [0.5pi, pi]
                neg_cos <= '1';
            end if;
            
            step <= 30;
        elsif step = 30 then
            -- Now we have to retrieve the cosine and the sine from the cosine LUT
        
            tmp_cos <= TO_INTEGER(cos_lut(TO_INTEGER(index)));              -- we just use index to access the value of the cosine in the LUT
            tmp_sin <= TO_INTEGER(cos_lut(REAL_MT - TO_INTEGER(index)));    -- here we use the property that sin(x) = cosine(pi/2 - x)
            
            step <= 40;
            
            db_tmp_cos <= cos_lut(TO_INTEGER(index));                       -- debugging
            db_tmp_sin <= cos_lut(REAL_MT - TO_INTEGER(index));             -- debugging
            db_index2(BITS_INDEX-1 downto 0) <= index;                      -- debugging
            
        elsif step = 40 then
            -- Now add the term cos(x)*sample to the previous sum (same for the sine)
            
            if neg_cos = '0' then        -- maybe this condition could be avoided with a better handing of the bits
                tot_cos <= tot_cos + SIGNED(stored_sample) * TO_SIGNED(tmp_cos, BITS_TRIG+1);
            else
                tot_cos <= tot_cos - SIGNED(stored_sample) * TO_SIGNED(tmp_cos, BITS_TRIG+1);
            end if;
            
            if neg_sin = '0' then       -- maybe this condition could be avoided with a better handing of the bits
                tot_sin <= tot_sin + SIGNED(stored_sample) * TO_SIGNED(tmp_sin, BITS_TRIG+1);
            else
                tot_sin <= tot_sin - SIGNED(stored_sample) * TO_SIGNED(tmp_sin, BITS_TRIG+1);
            end if;      
             
            step <= 50;
            
        elsif step = 50 then
            -- Now we check if we have reached the correct amount of samples to output the magnitude
            if cnt_sample = BUF_SIZE then           -- We have the correct amount of samples
                if tot_cos < 0 then                 -- Here we do tot_cos = abs(tot_cos)
                    tot_cos <= -tot_cos; 
                end if;
                if tot_sin < 0 then                 -- Here we do tot_sin = abs(tot_sin)
                    tot_sin <= -tot_sin; 
                end if;
            
                step <= 60;         
                cnt_sample <= (others => '0');      -- Reset the counter for the next sample
            else
                step <= 0;                          -- If we need more samples, go back to step 0 and repeat the process
            end if;
            
            db_tot_cos(BITS_MAGN downto 0) <= tot_cos;      -- debugging
            db_tot_sin(BITS_MAGN downto 0) <= tot_sin;      -- debugging
            
        elsif step = 60 then
            -- Now we have our big sum, we shift it down to make it more manageable
            -- From the theory, if the sampled wave is the same wave as the frequency we are checking, then we are just 
            -- integrating D*cos(2pi*j*f / FS)*B*cos(2pi*j*f / FS)dj = BD*cos(2pi*j*f / FS)dj with j going from 0 to N-1
            -- In our case B = 2**(BITS_SAMPL - 1), D = 2**BITS_TRIG (without -1, because it's not signed like for B)
            -- and N is 2**BITS_BUF. The maximum value of the integral should be D*B*(N-1)/2
            -- We want to keep 'BITS_OUT' significant bits, knowing that BITS_MAGN = BITS_TRIG + BITS_BUF + BITS_SAMPL, and 
            -- from the integral we know that we'll use at maximum BITS_SAMPL-1 + BITS_TRIG + BITS_BUF - 1 = BITS_MAGN - 2
            -- then we shift of  BITS_MAGN - 2 - BITS_OUT in order to keep 'BITS_OUT' significant bits in each of the sum
        
            tot_cos <= shift_right(tot_cos, BITS_MAGN - 2 - BITS_OUT);      
            tot_sin <= shift_right(tot_sin, BITS_MAGN - 2 - BITS_OUT);
            
            step <= 70;
        elsif step = 70 then
            -- Here we calculate the magnitude squared, simply with tot_cos**2 + tot_sin**2
            -- We know that tot_cos is at most BITS_OUT (same for tot_sin) so then we trim the bits in the multiplication
            -- but we take a bit more (in fact should be BITS_OUT-1 downto 0, but there is no -1)
            -- We do that because if there is a big cosine and small sine (but not so small) the result of the mult. will overflow
            -- Ex: BITS_OUT = 10, tot_cos = 1023, tot_sin = 380, the magnitude squared would be more than BITS_OUT*2
            -- By the theory, if we have a perfect cosine, the sine should be zero, but here the things are discrete and not so perfect
            -- We right shift the result of BITS_OUT, the result could be at maximum of BITS_OUT+1 bits (***) 
            
            tmp_sig(BITS_OUT*2+2-1 downto 0) <= UNSIGNED(STD_LOGIC_VECTOR(shift_right(tot_cos(BITS_OUT downto 0)*tot_cos(BITS_OUT downto 0) + tot_sin(BITS_OUT downto 0)*tot_sin(BITS_OUT downto 0), BITS_OUT)));
            step <= 71;
            -- (***) Obviously if they are both 1023, we would need more bits, but if we suppose for example that cosine is close to the max,
            -- then the sine should not be so big, if they are both big for some weird reasons, then the result will be wrong because of overflowing
            
        elsif step = 71 then          
            -- Here we output the magnitude squared
            if tmp_sig(BITS_OUT) = '1' then     -- If magnitude squared is one bit more than BITS_OUT then, set it at maximum
                magnitude <= 2**BITS_OUT - 1;
            else                                -- Otherwise we just cast it
                magnitude <= TO_INTEGER(tmp_sig(BITS_OUT-1 downto 0));
            end if;
            ready <= '1';                       -- Bit telling that there is a magnitude available (it lasts one clock only)
            step <= 0;                          -- Go back to step 0, and wait for the next sample
            
            tot_cos <= (others => '0');         -- Reset the signal that are not overwritten by default
            tot_sin <= (others => '0');
        end if;               
    end if;
end process;

end Behavioral;
