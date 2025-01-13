library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity decoder is
    GENERIC (
        -- The explanantion for these can be found in the freqfinder component
        FS          : POSITIVE  := 44100;   
        DATA_SIZE   : POSITIVE  := 24;
        BITS_BUF    : POSITIVE  := 10;
        BITS_FREQ   : POSITIVE  := 15;
        BITS_TRIG   : POSITIVE  := 8;        
        BITS_OUT    : POSITIVE  := 10
    );
    PORT(
        clk         :   IN  STD_LOGIC;
        reset_n     :   IN  STD_LOGIC;
        sample      :   IN  STD_LOGIC_VECTOR(DATA_SIZE-1 downto 0);
        sample_valid:   IN  STD_LOGIC;              -- true if the sample is valid
        enable      :   IN  STD_LOGIC;
            
        detected_start : OUT STD_LOGIC;             -- True when we detected the start of a transmission
        output_valid  :  OUT STD_LOGIC;             -- True when we received and decoded a full byte (2 packets)
        output_end  :  OUT STD_LOGIC;               -- True when the transmission ended
        output_data :  OUT STD_LOGIC_VECTOR(7 downto 0);    -- The actual byte received
        
        -- For debugging
        db_shift : OUT STD_LOGIC_VECTOR(15 downto 0);
        db_flags : OUT STD_LOGIC_VECTOR(15 downto 0);
        db_steps_flag : OUT STD_LOGIC_VECTOR(7 downto 0);
        db_start_magn : OUT STD_LOGIC_VECTOR(15 downto 0);
        db_start_cnt : OUT STD_LOGIC_VECTOR(7 downto 0);
        db_data_cnt : OUT STD_LOGIC_VECTOR(7 downto 0);
        db_div_num : OUT STD_LOGIC_VECTOR(31 downto 0);
        db_div_den : OUT STD_LOGIC_VECTOR(31 downto 0)
        
    );
end decoder;

architecture Behavioral of decoder is

    CONSTANT BITS_SQRT_LUT : POSITIVE := BITS_OUT/2;                        -- Bits for the square root LUT
    CONSTANT BITS_DIV   :   POSITIVE := BITS_BUF + BITS_SQRT_LUT - 2;       -- Bits used in the division
    CONSTANT PSIZE      :   NATURAL := 2 ** BITS_BUF;                       -- size of a packet 
    CONSTANT SSIZE      :   NATURAL := PSIZE / 4;                           -- size of a subpacket
    CONSTANT FREQ_START :   POSITIVE := 21500;                              -- The start-frequency


COMPONENT freq_finder is
    GENERIC(
        FREQ     : POSITIVE  := 21500;
        FS       : POSITIVE  := FS;
        DATA_SIZE: POSITIVE  := DATA_SIZE;
        BITS_BUF : POSITIVE  := BITS_BUF;
        BITS_FREQ : POSITIVE  := BITS_FREQ;
        BITS_TRIG : POSITIVE  := BITS_TRIG;
        BITS_OUT : POSITIVE  := BITS_OUT
    );
    port(
        clk:            in STD_LOGIC;
        reset:          in STD_LOGIC;
        sample:         in STD_LOGIC_VECTOR(DATA_SIZE-1 downto 0);
        data_valid:     in STD_LOGIC := '0';
        magnitude:      out NATURAL RANGE 0 TO 2**BITS_OUT-1;
        ready:          out STD_LOGIC
    );
END COMPONENT;

COMPONENT uint_divider is
    GENERIC(
        NUM_BITS    : POSITIVE  := BITS_DIV
    );
    PORT(
        clk         :   IN  STD_LOGIC;
        enable      :   IN  STD_LOGIC;
        num         :   IN  INTEGER RANGE 0 TO 2**NUM_BITS-1;
        den         :   IN  INTEGER RANGE 1 TO 2**NUM_BITS-1;
        ready       :   OUT STD_LOGIC := '0';
        res         :   OUT INTEGER RANGE 0 TO 2**NUM_BITS-1 := 0
    );
END COMPONENT;

    -- Type to store the frequency used for encode each packet of 4 bits
    type buf_freqs      is array (0 to 15) of NATURAL RANGE 0 TO 2**BITS_FREQ-1;
    -- Type to store 5 magnitudes
    type buf_magns      is array (0 to 4) of NATURAL RANGE 0 TO 2**BITS_OUT-1;
    -- Type to store 3 packet to do the redundacy check
    type buf_data       is array (0 to 2) of UNSIGNED(3 downto 0);
    -- Type to store all the magnitudes from the Freq_Finder components
    type buf_magns_ff   is array (0 to 15) of NATURAL RANGE 0 TO 2**BITS_OUT-1;
    -- Type to store the square root LUT
    type sqrt_lut_type  is array (0 to PSIZE-1) of NATURAL RANGE 0 TO 2**(BITS_OUT/2);
    
    -- The square root LUT, x -> sqrt(x) where x is a integer in [0, 2**PSIZE-1]
    CONSTANT sqrt_lut   :   sqrt_lut_type := (0, 1, 1, 2, 2, 2, 2, 3, 3, 3, 3, 3, 3, 4, 4, 4, 4, 4, 4, 4, 4, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 8, 8, 8, 8, 8, 8, 8, 8, 8, 8, 8, 8, 8, 8, 8, 8, 9, 9, 9, 9, 9, 9, 9, 9, 9, 9, 9, 9, 9, 9, 9, 9, 9, 9, 10, 10, 10, 10, 10, 10, 10, 10, 10, 10, 10, 10, 10, 10, 10, 10, 10, 10, 10, 10, 11, 11, 11, 11, 11, 11, 11, 11, 11, 11, 11, 11, 11, 11, 11, 11, 11, 11, 11, 11, 11, 11, 12, 12, 12, 12, 12, 12, 12, 12, 12, 12, 12, 12, 12, 12, 12, 12, 12, 12, 12, 12, 12, 12, 12, 12, 13, 13, 13, 13, 13, 13, 13, 13, 13, 13, 13, 13, 13, 13, 13, 13, 13, 13, 13, 13, 13, 13, 13, 13, 13, 13, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 15, 15, 15, 15, 15, 15, 15, 15, 15, 15, 15, 15, 15, 15, 15, 15, 15, 15, 15, 15, 15, 15, 15, 15, 15, 15, 15, 15, 15, 15, 16, 16, 16, 16, 16, 16, 16, 16, 16, 16, 16, 16, 16, 16, 16, 16, 16, 16, 16, 16, 16, 16, 16, 16, 16, 16, 16, 16, 16, 16, 16, 16, 17, 17, 17, 17, 17, 17, 17, 17, 17, 17, 17, 17, 17, 17, 17, 17, 17, 17, 17, 17, 17, 17, 17, 17, 17, 17, 17, 17, 17, 17, 17, 17, 17, 17, 18, 18, 18, 18, 18, 18, 18, 18, 18, 18, 18, 18, 18, 18, 18, 18, 18, 18, 18, 18, 18, 18, 18, 18, 18, 18, 18, 18, 18, 18, 18, 18, 18, 18, 18, 18, 19, 19, 19, 19, 19, 19, 19, 19, 19, 19, 19, 19, 19, 19, 19, 19, 19, 19, 19, 19, 19, 19, 19, 19, 19, 19, 19, 19, 19, 19, 19, 19, 19, 19, 19, 19, 19, 19, 20, 20, 20, 20, 20, 20, 20, 20, 20, 20, 20, 20, 20, 20, 20, 20, 20, 20, 20, 20, 20, 20, 20, 20, 20, 20, 20, 20, 20, 20, 20, 20, 20, 20, 20, 20, 20, 20, 20, 20, 21, 21, 21, 21, 21, 21, 21, 21, 21, 21, 21, 21, 21, 21, 21, 21, 21, 21, 21, 21, 21, 21, 21, 21, 21, 21, 21, 21, 21, 21, 21, 21, 21, 21, 21, 21, 21, 21, 21, 21, 21, 21, 22, 22, 22, 22, 22, 22, 22, 22, 22, 22, 22, 22, 22, 22, 22, 22, 22, 22, 22, 22, 22, 22, 22, 22, 22, 22, 22, 22, 22, 22, 22, 22, 22, 22, 22, 22, 22, 22, 22, 22, 22, 22, 22, 22, 23, 23, 23, 23, 23, 23, 23, 23, 23, 23, 23, 23, 23, 23, 23, 23, 23, 23, 23, 23, 23, 23, 23, 23, 23, 23, 23, 23, 23, 23, 23, 23, 23, 23, 23, 23, 23, 23, 23, 23, 23, 23, 23, 23, 23, 23, 24, 24, 24, 24, 24, 24, 24, 24, 24, 24, 24, 24, 24, 24, 24, 24, 24, 24, 24, 24, 24, 24, 24, 24, 24, 24, 24, 24, 24, 24, 24, 24, 24, 24, 24, 24, 24, 24, 24, 24, 24, 24, 24, 24, 24, 24, 24, 24, 25, 25, 25, 25, 25, 25, 25, 25, 25, 25, 25, 25, 25, 25, 25, 25, 25, 25, 25, 25, 25, 25, 25, 25, 25, 25, 25, 25, 25, 25, 25, 25, 25, 25, 25, 25, 25, 25, 25, 25, 25, 25, 25, 25, 25, 25, 25, 25, 25, 25, 26, 26, 26, 26, 26, 26, 26, 26, 26, 26, 26, 26, 26, 26, 26, 26, 26, 26, 26, 26, 26, 26, 26, 26, 26, 26, 26, 26, 26, 26, 26, 26, 26, 26, 26, 26, 26, 26, 26, 26, 26, 26, 26, 26, 26, 26, 26, 26, 26, 26, 26, 26, 27, 27, 27, 27, 27, 27, 27, 27, 27, 27, 27, 27, 27, 27, 27, 27, 27, 27, 27, 27, 27, 27, 27, 27, 27, 27, 27, 27, 27, 27, 27, 27, 27, 27, 27, 27, 27, 27, 27, 27, 27, 27, 27, 27, 27, 27, 27, 27, 27, 27, 27, 27, 27, 27, 28, 28, 28, 28, 28, 28, 28, 28, 28, 28, 28, 28, 28, 28, 28, 28, 28, 28, 28, 28, 28, 28, 28, 28, 28, 28, 28, 28, 28, 28, 28, 28, 28, 28, 28, 28, 28, 28, 28, 28, 28, 28, 28, 28, 28, 28, 28, 28, 28, 28, 28, 28, 28, 28, 28, 28, 29, 29, 29, 29, 29, 29, 29, 29, 29, 29, 29, 29, 29, 29, 29, 29, 29, 29, 29, 29, 29, 29, 29, 29, 29, 29, 29, 29, 29, 29, 29, 29, 29, 29, 29, 29, 29, 29, 29, 29, 29, 29, 29, 29, 29, 29, 29, 29, 29, 29, 29, 29, 29, 29, 29, 29, 29, 29, 30, 30, 30, 30, 30, 30, 30, 30, 30, 30, 30, 30, 30, 30, 30, 30, 30, 30, 30, 30, 30, 30, 30, 30, 30, 30, 30, 30, 30, 30, 30, 30, 30, 30, 30, 30, 30, 30, 30, 30, 30, 30, 30, 30, 30, 30, 30, 30, 30, 30, 30, 30, 30, 30, 30, 30, 30, 30, 30, 30, 31, 31, 31, 31, 31, 31, 31, 31, 31, 31, 31, 31, 31, 31, 31, 31, 31, 31, 31, 31, 31, 31, 31, 31, 31, 31, 31, 31, 31, 31, 31, 31, 31, 31, 31, 31, 31, 31, 31, 31, 31, 31, 31, 31, 31, 31, 31, 31, 31, 31, 31, 31, 31, 31, 31, 31, 31, 31, 31, 31, 31, 31, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32);
    -- The array of the frequency for each Freq_Finder component
    CONSTANT FREQS      :   buf_freqs := (17000, 17266, 17533, 17800, 18066, 18333, 18600, 18866, 19133, 19400, 19666, 19933, 20200, 20466, 20733, 21000);

    
    SIGNAL start_reset      : STD_LOGIC     := '0'; -- This control the reset of the freq_finder needed for detecting the start of the transmission
    SIGNAL dec_reset        : STD_LOGIC     := '0'; -- This control the reset of the other freq_finder (16)
    
    SIGNAL start_cnt        : NATURAL RANGE 0 TO 7 := 0;  -- Counts the subpacket that could be part of the starting packet
    SIGNAL start_detected   : STD_LOGIC   := '0';         -- '1' if the start of the transmission is correctly detected
    
    SIGNAL data_cnt         : NATURAL RANGE 0 TO 3 := 0;   -- Keeps track of many packet we have for the redundancy chek
    
    SIGNAL start_magn       : NATURAL RANGE 0 TO 2**BITS_OUT-1 := 0; -- Output of the start-FreqFinder (the one that detect the starting of the transmission) 
    SIGNAL start_magn_rdy   : STD_LOGIC := '0';             -- '1' when it recognizes the start frequency
    SIGNAL bf_start         : buf_magns;                    
    SIGNAL bf_magns_ff      : buf_magns_ff;
    SIGNAL bf_magns_ff_copy  : buf_magns_ff;                -- Copy of the 16-freqfinder mangnitude
    SIGNAL bf_data          : buf_data;
    SIGNAL bf_magn_rdy      : STD_LOGIC_VECTOR(15 downto 0)  := (others => '0');    -- Where we keep the readiness for each freq_finder
    
    SIGNAL data_set     : STD_LOGIC := '0';                 -- to keep track of when we decoded a packet
    
    SIGNAL shift        : NATURAL RANGE 0 TO PSIZE-1:= 0;   -- Keeps track of how many samples we have to drop (used for syncronization)
    SIGNAL packet_total : NATURAL RANGE 0 TO 16 := 0;       -- to keep track of how many packets should arrive
    SIGNAL packet_data  : UNSIGNED(3 downto 0) := (others => '0');  -- to temporary store the received packet
    SIGNAL packet_cnt   : NATURAL RANGE 0 TO 16 := 0;       -- to count how may packet we received
    
    SIGNAL div_enable   : STD_LOGIC := '0';                 -- To perform a slow (multi-clock) division, to relax the timing
    SIGNAL div_ready    : STD_LOGIC := '0';
    SIGNAL div_num      : INTEGER := 0;
    SIGNAL div_den      : INTEGER := 0;
    SIGNAL div_res      : INTEGER := 0;        
    
    SIGNAL searching    : STD_LOGIC := '0';                 -- to keep track if we are searching the biggest magnitude between the 16s
    SIGNAL isearch       : NATURAL RANGE 0 TO 16 := 0;      -- to keep track of the searching index
    SIGNAL imax          : NATURAL RANGE 0 TO 16 := 0;      -- to keep track of the index of the biggest value
    SIGNAL vmax          : NATURAL RANGE 0 TO 2**BITS_OUT-1 := 0;   -- to keep track of the biggest value
    

begin

-- This component is the one used for detecting the start of the trasmission because it has it unique frequency
-- This freqfinder has a buf_size (numbers of samples before outputting a magnitude) 4 times smaller than the others
-- So BITS_BUF is BITS_BUF-2
ff_start: freq_finder
    generic map(FREQ => FREQ_START, BITS_BUF => BITS_BUF-2)
    port map(clk => clk, reset => start_reset, sample => sample, data_valid => sample_valid,
                magnitude => start_magn, ready => start_magn_rdy);
       
-- Each of this component detect one of the 16 frequencies, the generic configuration is the default except for the FREQ         
ff_dec0: freq_finder
    generic map(FREQ => FREQS(0))
    port map(clk => clk, reset => dec_reset, sample => sample, data_valid => sample_valid, magnitude => bf_magns_ff(0), ready => bf_magn_rdy(0));
ff_dec1: freq_finder
    generic map(FREQ => FREQS(1))
    port map(clk => clk, reset => dec_reset, sample => sample, data_valid => sample_valid, magnitude => bf_magns_ff(1), ready => bf_magn_rdy(1));
ff_dec2: freq_finder
    generic map(FREQ => FREQS(2))
    port map(clk => clk, reset => dec_reset, sample => sample, data_valid => sample_valid, magnitude => bf_magns_ff(2), ready => bf_magn_rdy(2));
ff_dec3: freq_finder
    generic map(FREQ => FREQS(3))
    port map(clk => clk, reset => dec_reset, sample => sample, data_valid => sample_valid, magnitude => bf_magns_ff(3), ready => bf_magn_rdy(3));
ff_dec4: freq_finder
    generic map(FREQ => FREQS(4))
    port map(clk => clk, reset => dec_reset, sample => sample, data_valid => sample_valid, magnitude => bf_magns_ff(4), ready => bf_magn_rdy(4));
ff_dec5: freq_finder
    generic map(FREQ => FREQS(5))
    port map(clk => clk, reset => dec_reset, sample => sample, data_valid => sample_valid, magnitude => bf_magns_ff(5), ready => bf_magn_rdy(5));
ff_dec6: freq_finder
    generic map(FREQ => FREQS(6))
    port map(clk => clk, reset => dec_reset, sample => sample, data_valid => sample_valid, magnitude => bf_magns_ff(6), ready => bf_magn_rdy(6));
ff_dec7: freq_finder
    generic map(FREQ => FREQS(7))
    port map(clk => clk, reset => dec_reset, sample => sample, data_valid => sample_valid, magnitude => bf_magns_ff(7), ready => bf_magn_rdy(7));
ff_dec8: freq_finder
    generic map(FREQ => FREQS(8))
    port map(clk => clk, reset => dec_reset, sample => sample, data_valid => sample_valid, magnitude => bf_magns_ff(8), ready => bf_magn_rdy(8));
ff_dec9: freq_finder
    generic map(FREQ => FREQS(9))
    port map(clk => clk, reset => dec_reset, sample => sample, data_valid => sample_valid, magnitude => bf_magns_ff(9), ready => bf_magn_rdy(9));
ff_dec10: freq_finder
    generic map(FREQ => FREQS(10))
    port map(clk => clk, reset => dec_reset, sample => sample, data_valid => sample_valid, magnitude => bf_magns_ff(10), ready => bf_magn_rdy(10));
ff_dec11: freq_finder
    generic map(FREQ => FREQS(11))
    port map(clk => clk, reset => dec_reset, sample => sample, data_valid => sample_valid, magnitude => bf_magns_ff(11), ready => bf_magn_rdy(11));
ff_dec12: freq_finder
    generic map(FREQ => FREQS(12))
    port map(clk => clk, reset => dec_reset, sample => sample, data_valid => sample_valid, magnitude => bf_magns_ff(12), ready => bf_magn_rdy(12));
ff_dec13: freq_finder
    generic map(FREQ => FREQS(13))
    port map(clk => clk, reset => dec_reset, sample => sample, data_valid => sample_valid, magnitude => bf_magns_ff(13), ready => bf_magn_rdy(13));
ff_dec14: freq_finder
    generic map(FREQ => FREQS(14))
    port map(clk => clk, reset => dec_reset, sample => sample, data_valid => sample_valid, magnitude => bf_magns_ff(14), ready => bf_magn_rdy(14));
ff_dec15: freq_finder
    generic map(FREQ => FREQS(15))
    port map(clk => clk, reset => dec_reset, sample => sample, data_valid => sample_valid, magnitude => bf_magns_ff(15), ready => bf_magn_rdy(15));
    
-- Used to perform a division           
comp_divider: uint_divider
    PORT MAP(
        clk => clk,
        enable => div_enable, 
        num => div_num,
        den => div_den,
        ready => div_ready,
        res => div_res
    );        

-- We want to reset the start-freqfinder when:
--      - we found the start of the transmission OR
--      - the enable is OFF OR when we want to reset (=> reset='0')
-- We want to reset the other-freqfinder when
--      - we are looking for the start of a transmission OR
--      - the enable is OFF OR when we want to reset (=> reset='0')
--      - We are dropping samples (to syncronyze)
-- The reset actually reset the state of the freq_finder so they will lose what progress they had
start_reset <= '1' when (start_detected = '1') OR (reset_n = '0') OR (enable = '0') else '0';
dec_reset <= '1' when (start_detected = '0') OR (reset_n = '0') OR (enable = '0') OR (shift > 0) else '0';

-- set the output signal with the internal signal, probably we could use only one signal
detected_start <= start_detected;

big_process:
process (clk, enable, reset_n)
begin
    -- If enable is 0, or we want to reset
    if reset_n = '0' OR enable = '0' then
        shift <= 0;
        start_detected <= '0';
        start_cnt <= 0;
        data_cnt <= 0;
        data_set <= '0';
        packet_cnt <= 0;
        packet_total <= 0;
        searching <= '0';
    
    elsif rising_edge(clk) then
        output_valid <= '0';
        output_end <= '0';

        -- Debugging signals, thye will be optmized out if not used
        db_start_cnt <= STD_LOGIC_VECTOR(TO_UNSIGNED(start_cnt, 8));
        db_shift <= STD_LOGIC_VECTOR(TO_UNSIGNED(shift, 16));
        db_flags(0) <= start_detected;
        db_flags(1) <= div_enable;
        db_flags(2) <= start_magn_rdy;
        db_flags(3) <= searching;
        db_data_cnt <= STD_LOGIC_VECTOR(TO_UNSIGNED(data_cnt, 8));

        -- If shift is set, then just skip every valid sample and decrease the counter. 
        -- This is used for synchronization
        if shift > 0 then
            if sample_valid = '1' then
                shift <= shift - 1;
            end if;
    
        -- If we have not detected the start of the transmission yet
        elsif start_detected = '0' then
            -- How we detect the start of the transmission? The sender awlays sends a full packet with a 
            -- specific frequency. If we detect that frequency means that we detected the start of a transmission.
            -- The problem is the syncronization, we want to align our freqfinder with the sender to avoid
            -- computing the magnitude of half of the packet and the half of the next packet.
            -- If we start to listen to for samples in the right moment we can synchronize us with the sender.
            
            -- How to synchronization works? The idea is that the initial packet is followed by an empty packet.
            -- The start-freqfinder instead of waiting for N samples like the others, it waits for N/4 samples,
            -- allowing it to find 4 or 5 magnitude for the starting packet with the starting frequency.
            -- Then looking at this values we can find out how much out of phase we are with the sender and
            -- by knowing that the starting packet is followed by an empty packet we can synchronize ourself.
        
            -- So ...
            -- If the start-freqfinder has a magnitude ready (it could zero, or it could actually something)
            -- because it's ready every time it reads enough sample to produce a magnitude, not when there is
            -- actually something
            if start_magn_rdy = '1' then 
                -- If it is bigger than a threshold and we detected it less than 5 times in a row (excluding now)
                if start_magn > 40 and start_cnt < 5 then
                    bf_start(start_cnt) <= start_magn;  -- then store it with the actual index
                    start_cnt <= start_cnt + 1;
                    
                else -- Here if start_magn <= 40 or start_cnt >= 5
                    if start_cnt = 4 then  
                        -- If we have found previously only 4 starting frequency in a row, this mean that the magnitude
                        -- found now is less than the threshold. Finding 4 packets and no more means that we are
                        -- synchronized with the sender (synchronized means not too much out of phase)
                    
                        -- By knowing that after the initial packet there is an empty packet, and we read a quarter 
                        -- of it, then we discard the next 3/4 of a full packet (= 3*SSIZE)
                        shift <= 3 * SSIZE;  
                        start_detected <= '1';
                     
                    elsif start_cnt = 5 then
                        -- If we are here it's because we have found 5 magnitude bigger than the threshold (before this one).
                        -- By looking at the first and the last magnitude found and their relative values
                        -- we can extrapolate how much shifting there is between use and the sender
                        
                        -- With some calculation, it can be found that the ratio of how much out of phase we are is
                        -- R = Af / (Af + A0) where Af is the last (the 5th) magnitude and A0 the first
                        -- The problem is that we have Af^2 and A0^2, so we have to divide
                        -- We use the divisor component to do that because it performs the division in more than one
                        -- clock cycle avoiding the failed timing occured with an inline division operation
                        -- Precisely we calculate R*packet_size/4 (SSIZE = PSIZE / 4) because we are doing integer division
                        div_num <= sqrt_lut(bf_start(start_cnt - 1)) * SSIZE;
                        div_den <= sqrt_lut(bf_start(start_cnt - 1)) + sqrt_lut(bf_start(0));
                        
                        div_enable <= '1';          -- Set the bit telling the component to perform the division
                        start_detected <= '1';
                        
                        -- debugging
                        db_div_num <= STD_LOGIC_VECTOR(TO_UNSIGNED(sqrt_lut(bf_start(start_cnt - 1)) * SSIZE, 32));
                        db_div_den <= STD_LOGIC_VECTOR(TO_UNSIGNED(sqrt_lut(bf_start(start_cnt - 1)) + sqrt_lut(bf_start(0)), 32));
                        
                    end if;
                    -- If we are here we means that
                    -- 1) we found the start of the transmission, so we are good
                    -- 2) we found a magnitude of the start frequency that is below that threshold, regardless
                    --      of how many good magnitude we found before, we set the counter to zero and we keep looking
                    --      for another 4/5 good magnitudes
                    start_cnt <= 0;
                
                end if;
                
                db_start_magn <= STD_LOGIC_VECTOR(TO_UNSIGNED(start_magn, 16)); -- debugging
            end if;
            
        -- Cheap way to test if there is a division going on, that is to check if the divider is > 0
        -- Cannot use div_enable because it needs to be activated only once to start the division
        elsif div_den > 0 then          
            div_enable <= '0';          -- Disable the flag telling the division component to start operating
            if div_ready = '1' then     -- Wait until the division is completed
            
                -- If we are here it's because we found 5 magnitudes. That means we are badly out of phase with 
                -- the sender (because we would expect 4 in case of good synchro) and we needed to perform the division
                -- to actually find how much out of phase we are.
                
                -- After the start packet there is an empty packet, and we read a part of it to get the fifth 
                -- magnitude, and then we wasted 1/4 of a packet (because we recognize that we found 5 magnitudes the 
                -- time after it, when we calculated the sixth magnitude)
                -- This means that we are between the 25% and 50% of the empty packet, so the shift will be
                -- 50% of the packet + the shift found from the division
                shift <= 2 * SSIZE + div_res;   
                  
                div_den <= 0;   -- We set our cheap way to test if there is a division going on to zero. 
            end if;
            
        else -- shift = 0 and start_detected = '1' AND div_den <= 0
            -- If we are here means we found a start and we are synchronized with the sender 
        
            -- If any of the other-freqfinder is ready (in this case we look at the first only, but
            -- all are ready at the same time by design)
            if bf_magn_rdy(0) = '1' then 
                -- Copy the magnitude found
                for i in 0 to 15 loop
                    bf_magns_ff_copy(i) <= bf_magns_ff(i);
                end loop;
                
                -- Now we have to look for the biggest magnitude found, so which frequency there is
                -- and we can decode the packet (half byte)
                
                -- We set the bit to tell that we are searching for the argmax of bf_magns_ff_copy
                searching <= '1';
                imax <= 0;
                vmax <= 0;
                isearch <= 0;
            end if;
            
            -- If we are searching then
            if searching = '1' then
                -- The search is just a start to end search, storing the biggest value and index 
                if isearch < 16 then -- If isearch is less than 16, we need to search more            
                    if bf_magns_ff_copy(isearch) > vmax then
                        imax <= isearch;
                        vmax <= bf_magns_ff_copy(isearch);
                    end if;
                    isearch <= isearch + 1;
                else
                    -- If we are here means that imax contains the index of the biggest magnitude
                    bf_data(data_cnt) <= TO_UNSIGNED(imax, 4); -- 4 bits because 0 to 15
                    -- this keeps track of how many packet we received (explained in the next code)
                    data_cnt <= data_cnt + 1;
                    searching <= '0';  -- we set that we are not looking anymore
                end if;  
            end if;
            
            if data_cnt = 3 then
                -- If we found 3 packets, that is 3 frequencies this means that we can perform the redundacy check:
                -- The sender send the same packet 3 times as redundacy so we can compare the 3 and take the frequncy 
                -- that appears 2 or more times. If all 3 are different there is nothing to do than just carry on
                -- with the calculations
                
                data_cnt <= 0; -- Reset the packet counter
                data_set <= '1'; -- set that we actually received a packet (a real halfbyte after the redundacy check)
                -- The majority rule can be easily implemented with (indicating the single bits with A, B and C):
                -- O = A(B+C) + BC
                packet_data <= (bf_data(1) AND bf_data(2)) OR (bf_data(0) AND (bf_data(1) OR bf_data(2)));
                packet_cnt <= packet_cnt + 1; -- We increase the packet counter because now we have actually found a packet
            end if;
            
            if data_set = '1' then -- If we found a real packet
                if packet_cnt = 1 then 
                    -- if is the first one, by protocol, it contains the number of the total packets
                    -- so we store it
                    packet_total <= TO_INTEGER(packet_data);
                end if;
                    
                if (packet_cnt MOD 2) = 1 then
                    -- We found the least significant part of the byte 
                    output_data(3 downto 0) <= STD_LOGIC_VECTOR(packet_data);
                else
                    -- We found the most significant part of the byte 
                    output_data(7 downto 4) <= STD_LOGIC_VECTOR(packet_data);
                    -- and we compled a whole byte, so we set the flag that there is an output
                    -- By protocol there will be only full-byte sent
                    output_valid <= '1';
                end if;
                data_set <= '0';
                
                -- When we received all the packets we want to set flag telling that the transmission ended
                -- and reset all the signals
                
                -- This check does not evaluate to true with the first packet because packet_cnt is 1 
                -- and packet_total is 0, only at the end of the message this is true
                if packet_cnt = packet_total then
                    output_end <= '1';
                    shift <= 0;
                    start_detected <= '0';
                    start_cnt <= 0;
                    data_cnt <= 0;
                    data_set <= '0';
                    packet_cnt <= 0;
                    packet_total <= 0;
                end if;
            end if;  
        end if;
    end if;

end process;


end Behavioral;














