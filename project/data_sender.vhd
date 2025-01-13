library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity data_sender is
    GENERIC(
        d_width     :  INTEGER := 24
    );                    
    PORT(
        clock       :  IN  STD_LOGIC;                     --system clock (100 MHz on Basys board)
        reset_n     :  IN  STD_LOGIC;                     --active low asynchronous reset
        mclk        :  OUT STD_LOGIC_VECTOR(1 DOWNTO 0);  --master clock
        sclk        :  OUT STD_LOGIC_VECTOR(1 DOWNTO 0);  --serial clock (or bit clock)
        ws          :  OUT STD_LOGIC_VECTOR(1 DOWNTO 0);  --word select (or left-right clock)
        sd_rx       :  IN  STD_LOGIC;                     --serial data in
        sd_tx       :  OUT STD_LOGIC;
        
        decoder_on  : IN STD_LOGIC;                       -- Tells the decoder to listen for transmission
        uart_in     :  IN STD_LOGIC;
        uart_out    :  OUT STD_LOGIC;
        
        output      : OUT STD_LOGIC_VECTOR(0 downto 0)    -- Led to tell when a start of a transmission is detected
        
    );        
end data_sender;

architecture logic of data_sender is
    SIGNAL master_clk   :  STD_LOGIC;                             --internal master clock signal
    SIGNAL serial_clk   :  STD_LOGIC := '0';                      --internal serial clock signal
    SIGNAL word_select  :  STD_LOGIC := '0';                      --internal word select signal
    SIGNAL l_data_rx    :  STD_LOGIC_VECTOR(d_width-1 DOWNTO 0);  --left channel data received from I2S Transceiver component
    SIGNAL r_data_rx    :  STD_LOGIC_VECTOR(d_width-1 DOWNTO 0);  --right channel data received from I2S Transceiver component
    SIGNAL l_data_tx    :  STD_LOGIC_VECTOR(d_width-1 DOWNTO 0);  --left channel data to transmit using I2S Transceiver component
    SIGNAL r_data_tx    :  STD_LOGIC_VECTOR(d_width-1 DOWNTO 0);  --right channel data to transmit using I2S Transceiver component
 
    --declare PLL to create 11.29 MHz master clock from 100 MHz system clock
    COMPONENT clk_wiz_0
        PORT(
            clk_in1     :  IN STD_LOGIC;
            clk_out1    :  OUT STD_LOGIC);
    END COMPONENT;

    --declare I2S Transceiver component
    COMPONENT i2s_transceiver IS
        GENERIC(
            mclk_sclk_ratio :  INTEGER := 4;    --number of mclk periods per sclk period
            sclk_ws_ratio   :  INTEGER := 64;   --number of sclk periods per word select period
            d_width         :  INTEGER := 24);  --data width
        PORT(
            reset_n     :  IN   STD_LOGIC;                              --asynchronous active low reset
            mclk        :  IN   STD_LOGIC;                              --master clock
            sclk        :  OUT  STD_LOGIC;                              --serial clock (or bit clock)
            ws          :  OUT  STD_LOGIC;                              --word select (or left-right clock)
            sd_tx       :  OUT  STD_LOGIC;                              --serial data transmit
            sd_rx       :  IN   STD_LOGIC;                              --serial data receive
            l_data_tx   :  IN   STD_LOGIC_VECTOR(d_width-1 DOWNTO 0);   --left channel data to transmit
            r_data_tx   :  IN   STD_LOGIC_VECTOR(d_width-1 DOWNTO 0);   --right channel data to transmit
            l_data_rx   :  OUT  STD_LOGIC_VECTOR(d_width-1 DOWNTO 0);   --left channel data received
            r_data_rx   :  OUT  STD_LOGIC_VECTOR(d_width-1 DOWNTO 0));  --right channel data received
    END COMPONENT;
    
    COMPONENT comm_0 IS
        PORT(
            clk         :  in std_logic;
            uart_in     :  in std_logic;
            reset       :  in std_logic;        
            uart_out    :  out std_logic;
            data_in     :  in std_logic_vector(7 downto 0);
            write       :  in std_logic;
            read        :  in std_logic;
            data_out    :  out std_logic_vector(7 downto 0);
            data_available: out std_logic);
    END COMPONENT;
    
    constant BUF_SIZE : POSITIVE := 1024;
    constant FS : POSITIVE := 44100;
    constant DATA_SIZE: POSITIVE  := 24;
    constant BITS_BUF : POSITIVE  := 10;  -- it needs to be able to store BUF_SIZE
    constant BITS_FREQ : POSITIVE  := 15;
    constant BITS_TRIG : POSITIVE  := 8;
    constant BITS_OUT : POSITIVE  := 10;
    
    component decoder is
        GENERIC (
            FS          : POSITIVE  := FS;
            DATA_SIZE   : POSITIVE  := DATA_SIZE;
            BITS_BUF    : POSITIVE  := BITS_BUF;
            BITS_FREQ   : POSITIVE  := BITS_FREQ;
            BITS_TRIG   : POSITIVE  := BITS_TRIG;
            BITS_OUT    : POSITIVE  := BITS_OUT
        );
        PORT(
            clk         :   IN  STD_LOGIC;
            reset_n     :   IN  STD_LOGIC;
            sample      :   IN  STD_LOGIC_VECTOR(DATA_SIZE-1 downto 0);
            sample_valid:   IN  STD_LOGIC;
            enable      :   IN  STD_LOGIC;
            
            detected_start : OUT STD_LOGIC;
            output_valid  :  OUT STD_LOGIC;
            output_end  :  OUT STD_LOGIC;
            output_data :  OUT STD_LOGIC_VECTOR(7 downto 0)
--            debug:          out STD_LOGIC_VECTOR(3 downto 0)
        );
    end component;
    
    SIGNAL reset_wire   :  STD_LOGIC := '0';
    signal datain_wire  :  std_logic_vector(7 downto 0) := "00000000";
    signal dataout_wire :  std_logic_vector(7 downto 0) := "00000000";
    signal read_wire    :  std_logic := '0';
    signal write_wire   :  std_logic := '0';
    signal data_avl_wire : std_logic := '0';
    
    SIGNAL dvalid_ff_wire : STD_LOGIC := '0';
    
    SIGNAL dec_output_valid : STD_LOGIC := '0';
    SIGNAL dec_output_end : STD_LOGIC := '0';
    SIGNAL dec_output_data : STD_LOGIC_VECTOR(7 downto 0) := (others => '0');
    
    SIGNAL buf_sample   : STD_LOGIC_VECTOR(23 downto 0);
    
    type sample_buf_type is array (0 to 2) of STD_LOGIC_VECTOR(7 downto 0);
    SIGNAL buffer_sample : sample_buf_type;
    SIGNAL buf_cnt : INTEGER := 0;

begin

    --instantiate PLL to create master clock
    i2s_clock: clk_wiz_0 
    PORT MAP(clk_in1 => clock, clk_out1 => master_clk);
  
--    instantiate I2S Transceiver component
    i2s_transceiver_0: i2s_transceiver
    GENERIC MAP(mclk_sclk_ratio => 4, sclk_ws_ratio => 64, d_width => 24)
    PORT MAP(reset_n => reset_n, mclk => master_clk, sclk => serial_clk, ws => word_select, sd_tx => sd_tx, sd_rx => sd_rx,
             l_data_tx => l_data_tx, r_data_tx => r_data_tx, l_data_rx => l_data_rx, r_data_rx => r_data_rx);
             
    comm_comp: comm_0
    port map(
        clk => clock,
        uart_in => uart_in,
        reset => reset_wire,
        uart_out => uart_out,
        data_in => datain_wire,
        write => write_wire,
        read => read_wire,
        data_out => dataout_wire,
        data_available => data_avl_wire
    );
    
    decoder_comp: decoder
    generic map(FS => FS, DATA_SIZE => DATA_SIZE, BITS_BUF => BITS_BUF,
                BITS_FREQ => BITS_FREQ, BITS_TRIG => BITS_TRIG, BITS_OUT => BITS_OUT)
    port map(
        clk => clock,
        reset_n => reset_n,
        sample => buf_sample,
        sample_valid => dvalid_ff_wire,
        enable => decoder_on,
        detected_start => output(0),
        output_valid => dec_output_valid,
        output_end => dec_output_end,
        output_data => dec_output_data
    );
  
    mclk(0) <= master_clk;  --output master clock to ADC
    mclk(1) <= master_clk;  --output master clock to DAC
    sclk(0) <= serial_clk;  --output serial clock (from I2S Transceiver) to ADC
    sclk(1) <= serial_clk;  --output serial clock (from I2S Transceiver) to DAC
    ws(0) <= word_select;   --output word select (from I2S Transceiver) to ADC
    ws(1) <= word_select;   --output word select (from I2S Transceiver) to DAC

    reset_wire <= NOT reset_n;


process_both:
process(clock, reset_n)
begin
    if reset_n = '0' then
        write_wire <= '0';
        dvalid_ff_wire <= '0';
        write_wire <= '0';
        buf_cnt <= 0;
        buffer_sample(0) <= (others => '0');
        buffer_sample(1) <= (others => '0');
        buffer_sample(2) <= (others => '0');
    
    elsif rising_edge(clock) then
    
        dvalid_ff_wire <= '0';
        read_wire <= '0';
        write_wire <= '0';
        
        -- If there is a byte available in the uart
        if data_avl_wire = '1' then
            -- Store it into the bffer
            buffer_sample(buf_cnt) <= dataout_wire;
            -- Tells the uart that we read it
            read_wire <= '1';
            if buf_cnt = 2 then
                -- If the buffer is full with 3 byte, we have a sample
            
                buf_cnt <= 0;
                -- Send it to the decoder
                buf_sample(23 downto 16) <=  buffer_sample(0);
                buf_sample(15 downto 8) <=  buffer_sample(1);
                buf_sample(7 downto 0) <=  dataout_wire;
                -- And tells the decoder that there is a valid sample
                dvalid_ff_wire <= '1';
                
            else
                buf_cnt <= buf_cnt + 1;
            end if;  
        end if;
        
        -- When there is an output form the decoder, send it back to the PC by the uart
        if dec_output_valid = '1' then
            datain_wire <= dec_output_data;
            write_wire <= '1';
        end if;

    end if;
end process;

end logic;
