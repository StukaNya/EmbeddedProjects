`timescale 1ns / 1ps
// frame resolution = 640x480 
// frame frequency = 25 Hz
// pattern - color bars
// format - YCbCr
// 2000(column)*500(row)*25(frame frequency)*40ns(clk 25 MHz) = 1s

module test_video_generator_640x480_ycbcr(
	input clk_25_mhz,
	input enable,
	output video_valid,
	output [15:0] video_data,
	output video_sof,
	output video_eof
	);
	
// test pattern generator	
		
	localparam start_row = 16;
	localparam end_row = start_row + 479;
	localparam start_line = 128;
	localparam end_line = start_line + 639;
		
	wire local_reset;
	
	wire cnt_up_2000_limit, cnt_up_500_limit;
	wire frame_valid, line_valid;
	wire start_of_frame;
	
	wire tpg_valid;
	wire tpg_sop, tpg_eop;
	wire [15:0] tpg_data;	

	wire sm_fifo_aclr;
	wire sm_fifo_afull;
	wire sm_fifo_wrreq, sm_fifo_rdreq;
	wire [16:0] sm_fifo_din, sm_fifo_dout;
	
	reg [10:0] cnt_up_2000 = 11'b0;
	reg [8:0] cnt_up_500 = 9'b0;
	
	reg data_rden = 1'b0;
	reg packet_type = 1'b0;
	
	reg video_sof_ff = 1'b0;
	reg video_eof_ff = 1'b0;
	reg video_valid_ff = 1'b0;
	reg [15:0] video_data_rg = 16'b0;	

assign local_reset = enable | frame_valid;	
	
// counter: 0...1999

assign cnt_up_2000_limit = (cnt_up_2000 == 11'd1999);
	
always @(posedge clk_25_mhz)
	if (!local_reset)
		cnt_up_2000 <= 11'b0;
	else if (cnt_up_2000_limit)
		cnt_up_2000 <= 11'b0;
	else
		cnt_up_2000 <= cnt_up_2000 + 1'b1;
	
// counter: 0...499

assign cnt_up_500_limit = (cnt_up_500 == 9'd499);

always @(posedge clk_25_mhz)
	if (!local_reset)
		cnt_up_500 <= 9'b0;
	else if (cnt_up_2000_limit)
	begin
		if (cnt_up_500_limit)
			cnt_up_500 <= 9'b0;
		else
			cnt_up_500 <= cnt_up_500 + 1'b1;
	end
	
// aux signals
	
assign frame_valid = (cnt_up_500 >= start_row[8:0]) & (cnt_up_500 <= end_row[8:0]);
assign line_valid = (cnt_up_2000 >= start_line[10:0]) & (cnt_up_2000 <= end_line[10:0]);	
assign start_of_frame = (cnt_up_500 == start_row[8:0]) & (cnt_up_2000 == 11'd0);

always @(posedge clk_25_mhz)
	data_rden <= frame_valid & line_valid;

// test pattern

test_pattern_generator tpg_inst(
	.clock (clk_25_mhz),
	.reset (~local_reset),
	.dout_ready (~sm_fifo_afull),
	.dout_valid (tpg_valid),
	.dout_data (tpg_data),
	.dout_startofpacket (tpg_sop),
	.dout_endofpacket (tpg_eop));

always @(posedge clk_25_mhz)
	if (tpg_sop)
		packet_type <= ~(| tpg_data[7:0]);
	
// small fifo

assign sm_fifo_aclr = ~local_reset;
assign sm_fifo_wrreq	= ~tpg_sop & tpg_valid & packet_type;
assign sm_fifo_rdreq = data_rden;
assign sm_fifo_din = {tpg_eop, tpg_data};
	
fifo_32x17	fifo_32x17_inst (
	.aclr (sm_fifo_aclr),
	.clock (clk_25_mhz),
	.data (sm_fifo_din),
	.rdreq (sm_fifo_rdreq),
	.wrreq (sm_fifo_wrreq),
	.almost_full (sm_fifo_afull),
	.q (sm_fifo_dout));
	
// out signals
	
always @(posedge clk_25_mhz)
begin
	video_sof_ff <= start_of_frame;
	video_eof_ff <= sm_fifo_dout[16] & data_rden;
	video_valid_ff <= start_of_frame | data_rden;
end

always @(posedge clk_25_mhz)
	if (!data_rden)
		video_data_rg <= 16'b0;
	else
		video_data_rg <= sm_fifo_dout[15:0];//(cnt_up_500 * 350) 

assign video_sof = video_sof_ff;
assign video_eof = video_eof_ff;
assign video_valid = video_valid_ff;
assign video_data = video_data_rg;
	
endmodule
	