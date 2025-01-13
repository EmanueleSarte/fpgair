There is a presentation in the main folder.

Structure of the project:
	directory fpgair: contains the actual projects
	directory uart	: contains the files for the uart

The project: FPGAir
The idea is to encode a message with sound waves (this is done in another device) and to play it like an audio file, while the PC 
uses its microphone to capture the sound and transmits the bytes to the FPGA with the UART. Initially the idea was to use the jack 
cable to connect the PC and the FPGA with a Pmod I2S2 but some complications in the end caused to use the UART instead.
The encoding is done with specific frequencies corresponding to specific bits combinations: each byte is divided in two packets of 4 bits
and each of the 16 combinations of these 4 bits is encoded in a sound wave with a specific frequency. Each wave of each packet is then
concatenated together in an audio file. Another two packets are put at the start, to detect the start of the transmission and to 
syncronize the receiver (the FPGA in this case).

Once the FPGA has the sound samples, it starts to decode the message with a specific algorithm that is basically a single component of
a Fourier transform to decode a specific frequency. This is done for all the 16 frequencies + 1 frequency for the initial packet. All
of this is done with integer numbers (usually with more than 32 bits). After the decoding the bytes are sent back to the PC with the UART.

The setup is usually this:
A phone controlled by the PC is put away from the PC. The phone connects to a web server hosted on the PC. The PC visits the web page
hosted on the same server to control the phone. On that page the user can choose which characters encode in a sound file which then will
be played remotely on the phone. The phone reproduces the sound, the microphone of the PC captures it, some conversion are done and then
the bytes are sent to the FPGA with the UART where the sound will be decoded. All of this is done in real time and without any direct
syncronization between the PC/phone and the FPGA.


To understand the source files it's better to read them in order:
	freq_finder2.vhd : it contains the logic to get a magnitude for a specific frequency given N audio samples
	decoder.vhd	 : it contains the logic to put togheter the information of the freq_finder and the decoding process
	data_sender.vhd  : this is the TOP, contains the logic to receive samples from the uart and give them to the decoder
	uint_divider.vhd : simple component performing integer divisions (done in multiple clock cycles)
	i2s_transceiver.vhd : not used (for now)
The first files (the most important) are heavily commented.


The UART:
The uart was coded to be able to transmit reliably a lot of data. The idea was to transmit whole audio data, so it's capable to
handle more than 3'000'000 baudrate per second (because we want to send 3byte*2channels*44100 samples/s = 264600 bytes/s =>
at least 2'700'000 baud rate).

There are no comments in the uart files (for now) because it's pretty similar to the one done during the course.
