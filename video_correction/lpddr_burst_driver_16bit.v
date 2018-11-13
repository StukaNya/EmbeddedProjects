`timescale 1ns / 1ps
/*
Write/Read length % 256 bytes == 0 (4 byte lpddr word * 64 words (burst size) = 256 bytes)
*/
module lpddr_burst_driver_16bit
(
	// Avalon MM Master Interface Pins (To LPDDR_CTRL Avalon MM Slave) (100 MHz)
	input		wire				avmm_m_rst,							//			m.rst
	input		wire				avmm_m_clk,							//			m.clk
	output	wire	[31:0]	avmm_m_address,					//			m.address
	input		wire				avmm_m_waitrequest,				//			 .waitrequest
	output	wire	[6:0]		avmm_m_burstcount,				//			 .burstcount
	output	wire				avmm_m_write,						//			 .write
	output	wire	[31:0]	avmm_m_writedata,					//			 .writedata
	output	wire				avmm_m_read,						//			 .read
	input		wire	[31:0]	avmm_m_readdata,					//			 .readdata
	input		wire				avmm_m_readdatavalid,			//			 .readdatavalid
	// LPDDR Read/Write Interface
	input		wire				lpddr_rst,							//	  lpddr.rst
	input		wire				lpddr_clk,							//	  lpddr.clk
	input		wire				lpddr_write,						//	  lpddr.write
	input		wire				lpddr_read,							//	  		 .read
	output	wire				lpddr_readdatavalid,				//	  		 .readdatavalid
	input		wire	[31:0]	lpddr_address,						//	  		 .address
	input		wire	[15:0]	lpddr_writedata,					//	  		 .writedata
	output	wire	[31:0]	lpddr_readdata						//	  		 .readdata
);
localparam [6:0] BURST_LEN = 7'd64; // burst size of lpddr
localparam [6:0] HALF_BURST_LEN = 7'd32; // wrused when new burst can be readed

//===========================================================================================
//======= Burst Write FIFO
//===========================================================================================
wire				burst_write_fifo_aclr;
wire	[15:0]	burst_write_fifo_data;
wire				burst_write_fifo_rdclk;
wire				burst_write_fifo_rdreq;
wire				burst_write_fifo_wrclk;
wire				burst_write_fifo_wrreq;
wire	[31:0]	burst_write_fifo_q;
wire				burst_write_fifo_rdempty;
wire	[8:0]		burst_write_fifo_rdusedw;
wire				burst_write_fifo_wrfull;
burst_fifo_1024_x16 burst_fifo_1024_x16_inst (
	.aclr			( burst_write_fifo_aclr ),
	.data			( burst_write_fifo_data ),
	.rdclk		( burst_write_fifo_rdclk ),
	.rdreq		( burst_write_fifo_rdreq ),
	.wrclk		( burst_write_fifo_wrclk ),
	.wrreq		( burst_write_fifo_wrreq ),
	.q				( burst_write_fifo_q ),
	.rdempty		( burst_write_fifo_rdempty ),
	.rdusedw		( burst_write_fifo_rdusedw ),
	.wrfull		( burst_write_fifo_wrfull )
);
assign burst_write_fifo_aclr = lpddr_rst | avmm_m_rst;
assign burst_write_fifo_data = lpddr_writedata;
assign burst_write_fifo_rdclk = ~avmm_m_clk;
assign burst_write_fifo_wrclk = ~lpddr_clk;
assign burst_write_fifo_wrreq = lpddr_write;
//===========================================================================================

//===========================================================================================
//======= LPDDR Burst Writing
//===========================================================================================
reg burst_write_ready = 1'b0;
reg [6:0] write_cnt = {7{1'b0}};
always@(posedge avmm_m_clk, posedge avmm_m_rst) begin
	if(avmm_m_rst) write_cnt <= {6{1'b0}};
	else if(!burst_write_ready) write_cnt <= {6{1'b0}};
	else if(!avmm_m_waitrequest) write_cnt <= write_cnt + 1'b1;
end
always@(posedge avmm_m_clk, posedge avmm_m_rst) begin
	if(avmm_m_rst) burst_write_ready <= 1'b0;
	else if( ( write_cnt == (BURST_LEN - 1'b1) ) && !avmm_m_waitrequest ) burst_write_ready <= 1'b0;
	else if( burst_write_fifo_rdusedw[6:0] > HALF_BURST_LEN ) burst_write_ready <= 1'b1;
end
reg [7:0] burst_write_cnt = {8{1'b0}};
always @(posedge avmm_m_clk, posedge avmm_m_rst) begin
	if(avmm_m_rst) burst_write_cnt <= {8{1'b0}};
	else if(burst_write_fifo_rdempty) burst_write_cnt <= {8{1'b0}};
	else if( ( write_cnt == (BURST_LEN - 1'b1) ) && !avmm_m_waitrequest ) burst_write_cnt <= burst_write_cnt + 1'b1;
end
assign burst_write_fifo_rdreq = burst_write_ready & ~avmm_m_waitrequest;

reg [31:0] avmm_m_write_address = {32{1'b0}};
always@(posedge avmm_m_clk, posedge avmm_m_rst) begin
	if(avmm_m_rst) avmm_m_write_address <= {32{1'b0}};
	else avmm_m_write_address <= {lpddr_address + {burst_write_cnt, {6{1'b0}}}, 2'b00}; // [avmm_m_address = start_address + burst_write_cnt * 64] == [start_address + burst_write_cnt << 6] == [start_address + {burst_write_cnt, {6{1'b0}}}]
end
//===========================================================================================

reg rw = 1'b0;
always@(posedge avmm_m_clk, posedge avmm_m_rst) begin
	if(avmm_m_rst) rw <= 1'b0;
	else if(lpddr_write) rw <= 1'b0;
	else if(lpddr_read) rw <= 1'b1;
end

//===========================================================================================
//======= LPDDR Burst Reading
//===========================================================================================
reg burst_read_ready = 1'b1;
reg [6:0] read_cnt = {7{1'b0}};
always@(posedge avmm_m_clk, posedge avmm_m_rst) begin
	if(avmm_m_rst) read_cnt <= {6{1'b0}};
	else if(burst_read_ready) read_cnt <= {6{1'b0}};
	else if(avmm_m_readdatavalid) read_cnt <= read_cnt + 1'b1;
end
always@(posedge avmm_m_clk, posedge avmm_m_rst) begin
	if(avmm_m_rst) burst_read_ready <= 1'b1;
	else if( read_cnt == (BURST_LEN - 1'b1) ) burst_read_ready <= 1'b1;
	else if(lpddr_read) burst_read_ready <= 1'b0;
end
reg [7:0] burst_read_cnt = {8{1'b0}};
always @(posedge avmm_m_clk, posedge avmm_m_rst) begin
	if(avmm_m_rst) burst_read_cnt <= {8{1'b0}};
	else if(!lpddr_read) burst_read_cnt <= {8{1'b0}};
	else if( read_cnt == BURST_LEN - 1'b1 ) burst_read_cnt <= burst_read_cnt + 1'b1;
end
reg avmm_m_read_reg = 1'b0;
always@(posedge avmm_m_clk, posedge avmm_m_rst) begin
	if(avmm_m_rst) avmm_m_read_reg <= 1'b0;
	else if(lpddr_read && burst_read_ready) avmm_m_read_reg <= 1'b1;
	else if(!avmm_m_waitrequest) avmm_m_read_reg <= 1'b0;
end
reg [31:0] avmm_m_read_address = {32{1'b0}};
always@(posedge avmm_m_clk, posedge avmm_m_rst) begin
	if(avmm_m_rst) avmm_m_read_address <= {32{1'b0}};
	else avmm_m_read_address <= {lpddr_address + {burst_read_cnt, {6{1'b0}}}, 2'b00}; // [avmm_m_address = start_address + burst_read_cnt * 64] == [start_address + burst_read_cnt << 6] == [start_address + {burst_read_cnt, {6{1'b0}}}]
end
//===========================================================================================

assign avmm_m_address = rw ? avmm_m_read_address : avmm_m_write_address;
assign avmm_m_burstcount = BURST_LEN;
assign avmm_m_write = burst_write_ready;
assign avmm_m_writedata = burst_write_fifo_q;
assign avmm_m_read = avmm_m_read_reg;

assign lpddr_readdata = avmm_m_readdata;
assign lpddr_readdatavalid = avmm_m_readdatavalid;

endmodule
