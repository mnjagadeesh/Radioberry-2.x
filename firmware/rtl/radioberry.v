// Project			: Radioberry
//
// Module			: Top level design radioberry.v
//
// Target Devices	: Cyclone 10LP
//
// Tool 		 		: Quartus Prime Lite Edition v17
//
//------------------------------------------------------------------------------------------------------------------------------------------------------------
// Description: 
//
//				Radioberry v2.0 SDR firmware code.
//
// Johan Maas PA3GSB 
//
// Date:    3 December 2017
//	
//------------------------------------------------------------------------------------------------------------------------------------------------------------

`include "timescale.v"

module radioberry(
clk_10mhz, 
ad9866_clk, ad9866_adio,ad9866_rxen,ad9866_rxclk,ad9866_txen,ad9866_txclk,ad9866_sclk,ad9866_sdio,ad9866_sdo,ad9866_sen_n,ad9866_rst_n,ad9866_mode,	
spi_sck, spi_mosi, spi_miso, spi_ce,   
rb_info_1,rb_info_2,
rx1_FIFOEmpty, rx2_FIFOEmpty,
txFIFOFull,
ptt_in,
ptt_out,
filter);

input wire clk_10mhz;			
input wire ad9866_clk;
inout [11:0] ad9866_adio;
output wire ad9866_rxen;
output wire ad9866_rxclk;
output wire ad9866_txen;
output wire ad9866_txclk;
output wire ad9866_sclk;
output wire ad9866_sdio;
input  wire ad9866_sdo;
output wire ad9866_sen_n;
output wire ad9866_rst_n;
output ad9866_mode;


// SPI connect to Raspberry PI SPI-0.
input wire spi_sck;
input wire spi_mosi; 
output wire spi_miso; 
input [1:0] spi_ce; 
output wire rx1_FIFOEmpty;
output wire rx2_FIFOEmpty;
output wire txFIFOFull;

output  wire  rb_info_1;  // radioberry info-1;  checks 10 Mhz clock 
output  wire  rb_info_2;  // radioberry info-2;  checks ad9866 clock (in tx flashes 2 times faster)
 

input wire ptt_in;
output wire ptt_out;
output [6:0] filter; 

//------------------------------------------------------------------------------------------------------------------------------------------------------------
//                         AD9866 Control
//------------------------------------------------------------------------------------------------------------------------------------------------------------

assign ad9866_mode = 1'b0;				//HALFDUPLEX
assign ad9866_rst_n = ~reset;
assign ad9866_adio = ptt_in ? DAC[13:2] : 12'bZ;
assign ad9866_rxclk = ad9866_clk;	 
assign ad9866_txclk = ad9866_clk;	 

assign ad9866_rxen = (~ptt_in) ? 1'b1: 1'b0;
assign ad9866_txen = (ptt_in) ? 1'b1: 1'b0;

assign ptt_out = ptt_in;


wire ad9866_rx_rqst;
wire ad9866_tx_rqst;
reg [5:0] rx_gain;
reg [5:0] tx_gain;

reg [5:0] prev_rx_gain;
reg [5:0] prev_tx_gain;
always @ (posedge clk_10mhz)
begin
	prev_rx_gain <= rx_gain;
	prev_tx_gain <= tx_gain;
end

assign ad9866_rx_rqst = rx_gain != prev_rx_gain;
assign ad9866_tx_rqst = tx_gain != prev_tx_gain;

ad9866 ad9866_inst(.reset(reset),.clk(clk_10mhz),.sclk(ad9866_sclk),.sdio(ad9866_sdio),.sdo(ad9866_sdo),.sen_n(ad9866_sen_n),.dataout(),.ext_tx_rqst(ad9866_tx_rqst),.tx_gain(tx_gain),.ext_rx_rqst(ad9866_rx_rqst),.rx_gain(rx_gain));

//------------------------------------------------------------------------------------------------------------------------------------------------------------
//                         SPI Control
//------------------------------------------------------------------------------------------------------------------------------------------------------------

wire [47:0] spi_recv;
wire spi_done;

always @ (posedge spi_done)
begin	
	if (!ptt_in) begin
		rx1_freq <= spi_recv[31:0];
		rx1_speed <= spi_recv[41:40];
		rx_gain <= ~spi_recv[37:32];
	end else begin
		tx_gain <= ~spi_recv[37:32];
	end
end 

spi_slave spi_slave_rx_inst(.rstb(!reset),.ten(1'b1),.tdata(rxDataFromFIFO),.mlb(1'b1),.ss(spi_ce[0]),.sck(spi_sck),.sdin(spi_mosi), .sdout(spi_miso),.done(spi_done),.rdata(spi_recv));


//------------------------------------------------------------------------------------------------------------------------------------------------------------
//                         SPI Control rx2
//------------------------------------------------------------------------------------------------------------------------------------------------------------

wire [47:0] spi_rx2_recv;
wire spi_rx2_done;

always @ (posedge spi_rx2_done)
begin	
	if (!ptt_in) begin
		rx2_freq <= spi_rx2_recv[31:0];
		rx2_speed <= spi_rx2_recv[41:40];
	end else begin
		tx_freq <= spi_rx2_recv[31:0];
	end	
end 

spi_slave spi_slave_rx2_inst(.rstb(!reset),.ten(1'b1),.tdata(rx2_DataFromFIFO),.mlb(1'b1),.ss(spi_ce[1]),.sck(spi_sck),.sdin(spi_mosi), .sdout(spi_miso),.done(spi_rx2_done),.rdata(spi_rx2_recv));

//------------------------------------------------------------------------------------------------------------------------------------------------------------
//                         Decimation Rate Control common
//------------------------------------------------------------------------------------------------------------------------------------------------------------
// Decimation rates
localparam RATE48 = 6'd40;
localparam RATE96  =  RATE48  >> 1;
localparam RATE192 =  RATE96  >> 1;
localparam RATE384 =  RATE192 >> 1;

//------------------------------------------------------------------------------------------------------------------------------------------------------------
//                         Decimation Rate Control rx1
//------------------------------------------------------------------------------------------------------------------------------------------------------------
// Decimation rates

reg [1:0] rx1_speed;	// selected decimation rate in external program,
reg [5:0] rx1_rate;

always @ (rx1_speed)
 begin 
	  case (rx1_speed)
	  0: rx1_rate <= RATE48;     
	  1: rx1_rate <= RATE96;     
	  2: rx1_rate <= RATE192;     
	  3: rx1_rate <= RATE384;           
	  default: rx1_rate <= RATE48;        
	  endcase
 end 

//------------------------------------------------------------------------------------------------------------------------------------------------------------
//                         Decimation Rate Control rx2
//------------------------------------------------------------------------------------------------------------------------------------------------------------
// Decimation rates

reg [1:0] rx2_speed;	// selected decimation rate in external program,
reg [5:0] rx2_rate;

always @ (rx2_speed)
 begin 
	  case (rx2_speed)
	  0: rx2_rate <= RATE48;     
	  1: rx2_rate <= RATE96;     
	  2: rx2_rate <= RATE192;     
	  3: rx2_rate <= RATE384;           
	  default: rx2_rate <= RATE48;        
	  endcase
 end 
 

//------------------------------------------------------------------------------------------------------------------------------------------------------------
//                         FILTER Control
//------------------------------------------------------------------------------------------------------------------------------------------------------------

filter filter_inst(.clock(clk_10mhz), .frequency(rx1_freq), .selected_filter(filter));

//------------------------------------------------------------------------------------------------------------------------------------------------------------
//                         Convert frequency to phase word 
//
//		Calculates  ratio = fo/fs = frequency/76.8Mhz where frequency is in MHz
//
//------------------------------------------------------------------------------------------------------------------------------------------------------------
wire   [31:0] sync_phase_word;
wire  [63:0] ratio;

reg[31:0] rx1_freq;
					    
localparam M2 = 32'd1876499845; 	// B57 = 2^57.   M2 = B57/CLK_FREQ = 76800000
localparam M3 = 32'd16777216;   	// M3 = 2^24, used to round the result
assign ratio = rx1_freq * M2 + M3; 
assign sync_phase_word = ratio[56:25]; 

//------------------------------------------------------------------------------------------------------------------------------------------------------------
//                         Convert frequency to phase word rx2
//
//		Calculates  ratio = fo/fs = frequency/73.728Mhz where frequency is in MHz
//
//------------------------------------------------------------------------------------------------------------------------------------------------------------
wire   [31:0] sync_phase_word_rx2;
wire  [63:0] ratio_rx2;

reg[31:0] rx2_freq;

localparam M4 = 32'd1876499845; 	// B57 = 2^57.   M2 = B57/CLK_FREQ = 76800000
localparam M5 = 32'd16777216;   	// M3 = 2^24, used to round the result

assign ratio_rx2 = rx2_freq * M4 + M5; 
assign sync_phase_word_rx2 = ratio_rx2[56:25]; 

//------------------------------------------------------------------------------------------------------------------------------------------------------------
//                         Convert frequency to phase word tx
//
//		Calculates  ratio = fo/fs = frequency/73.728Mhz where frequency is in MHz
//
//------------------------------------------------------------------------------------------------------------------------------------------------------------
wire   [31:0] sync_phase_word_tx;
wire  [63:0] ratio_tx;

reg[31:0] tx_freq;

localparam M6 = 32'd1876499845; 	// B57 = 2^57.   M2 = B57/CLK_FREQ = 76800000
localparam M7 = 32'd16777216;   	// M3 = 2^24, used to round the result

assign ratio_tx = tx_freq * M6 + M7; 
assign sync_phase_word_tx = ratio_tx[56:25]; 

//------------------------------------------------------------------------------
//                           Software Reset Handler
//------------------------------------------------------------------------------
wire reset;
reset_handler reset_handler_inst(.clock(clk_10mhz), .reset(reset));

//------------------------------------------------------------------------------
//                           Pipeline for adc fanout
//------------------------------------------------------------------------------

reg [11:0]	adc;

reg [3:0] incnt;
always @ (posedge ad9866_clk)
  begin
			// Test sine wave
        case (incnt)
            4'h0 : adc <= 12'h000;
            4'h1 : adc <= 12'hfcb;
            4'h2 : adc <= 12'hf9f;
            4'h3 : adc <= 12'hf81;
            4'h4 : adc <= 12'hf76;
            4'h5 : adc <= 12'hf81;
            4'h6 : adc <= 12'hf9f;
            4'h7 : adc <= 12'hfcb;
            4'h8 : adc <= 12'h000;
            4'h9 : adc <= 12'h035;
            4'ha : adc <= 12'h061;
            4'hb : adc <= 12'h07f;
            4'hc : adc <= 12'h08a;
            4'hd : adc <= 12'h07f;
            4'he : adc <= 12'h061;
            4'hf : adc <= 12'h035;
        endcase
		  incnt <= incnt + 4'h1; 
	end

reg [11:0] adcpipe [0:1];
always @ (posedge ad9866_clk) begin
    adcpipe[0] <= ad9866_adio;
    adcpipe[1] <= ad9866_adio;
	 //adcpipe[0] <= adc;
    //adcpipe[1] <= adc;
end

//------------------------------------------------------------------------------------------------------------------------------------------------------------
//                        Receiver module rx1 
//------------------------------------------------------------------------------------------------------------------------------------------------------------
wire	[23:0] rx_I;
wire	[23:0] rx_Q;
wire	rx_strobe;

localparam CICRATE = 6'd05;

receiver #(.CICRATE(CICRATE)) 
		receiver_inst(	.clock(ad9866_clk),
						.rate(rx1_rate), 
						.frequency(sync_phase_word),
						.out_strobe(rx_strobe),
						.in_data(adcpipe[0]),
						.out_data_I(rx_I),
						.out_data_Q(rx_Q));
						
//------------------------------------------------------------------------------------------------------------------------------------------------------------
//                        Receiver module rx2
//------------------------------------------------------------------------------------------------------------------------------------------------------------
wire	[23:0] rx2_I;
wire	[23:0] rx2_Q;
wire	rx2_strobe;

localparam CICRATE_RX2 = 6'd05;

receiver #(.CICRATE(CICRATE_RX2)) 
		receiver_rx2_inst(	
						.clock(ad9866_clk),
						.rate(rx2_rate), 
						.frequency(sync_phase_word_rx2),
						.out_strobe(rx2_strobe),
						.in_data(adcpipe[1]),
						.out_data_I(rx2_I),
						.out_data_Q(rx2_Q));			

//------------------------------------------------------------------------------------------------------------------------------------------------------------
//                          rxFIFO Handler (IQ Samples) rx1
//------------------------------------------------------------------------------------------------------------------------------------------------------------
reg [47:0] rxDataFromFIFO;

wire rx1req = ptt_in ? 1'b0 : 1'b1;

rxFIFO rxFIFO_inst(	.aclr(reset),
							.wrclk(ad9866_clk),.data({rx_I, rx_Q}),.wrreq(rx_strobe), .wrempty(rx1_FIFOEmpty), 
							.rdclk(~spi_ce[0]),.q(rxDataFromFIFO),.rdreq(rx1req));

//------------------------------------------------------------------------------------------------------------------------------------------------------------
//                          rxFIFO Handler (IQ Samples) rx2
//------------------------------------------------------------------------------------------------------------------------------------------------------------
reg [47:0] rx2_DataFromFIFO;

wire rx2req = ptt_in ? 1'b0 : 1'b1;

rxFIFO rx2_FIFO_inst(.aclr(reset),
							.wrclk(ad9866_clk),.data({rx2_I, rx2_Q}),.wrreq(rx2_strobe), .wrempty(rx2_FIFOEmpty), 
							.rdclk(~spi_ce[1]),.q(rx2_DataFromFIFO),.rdreq(rx2req));						
				
//------------------------------------------------------------------------------------------------------------------------------------------------------------
//                          txFIFO Handler ( IQ-Transmit)
//------------------------------------------------------------------------------------------------------------------------------------------------------------
wire wtxreq = ptt_in ? 1'b1 : 1'b0;

txFIFO txFIFO_inst(	.aclr(reset), 
							.wrclk(~spi_ce[0]), .data(spi_recv[31:0]), .wrreq(wtxreq),
							.rdclk(ad9866_clk), .q(txDataFromFIFO), .rdreq(txFIFOReadStrobe),  .rdempty(txFIFOEmpty), .rdfull(txFIFOFull));
	

//------------------------------------------------------------------------------------------------------------------------------------------------------------
//                        Transmitter module
//------------------------------------------------------------------------------------------------------------------------------------------------------------							
wire [31:0] txDataFromFIFO;
wire txFIFOEmpty;
wire txFIFOReadStrobe;

transmitter transmitter_inst(.reset(reset), .clk(ad9866_clk), .frequency(sync_phase_word_tx), 
							 .afTxFIFO(txDataFromFIFO), .afTxFIFOEmpty(txFIFOEmpty), .afTxFIFOReadStrobe(txFIFOReadStrobe),
							.out_data(DAC), .PTT(ptt_in), .LED(rb_info_2));	

wire [13:0] DAC;
	
//------------------------------------------------------------------------------
//                          Running...
//------------------------------------------------------------------------------
reg [26:0]counter;

always @(posedge clk_10mhz) 
begin
  if (reset)
    counter <= 26'b0;
  else
    counter <= counter + 1'b1;
end

assign rb_info_1 = counter[23];

endmodule