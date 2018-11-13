`timescale 1ns / 1ps
module FilterBlowOut #(
	parameter DATA_WIDTH = 16,
	parameter FRAME_WIDTH = 640,
	parameter FRAME_HEIGHT = 512,
	parameter THRESHOLD_LOW = 1000,
	parameter THRESHOLD_HIGH = 2000,
	parameter PIX_THRESHOLD = 1000
	)
	(
	input en_blow_out,
	input en_bad_replace,
	input en_median,
	input clk,
	// Avalon-ST Sink interface
	input sink_valid,
	input sink_eop,
	input sink_sop,
	input [DATA_WIDTH-1:0] sink_data,
	// Avalon-ST Source interface
	output source_valid,
	output source_eop,
	output source_sop,
	output [DATA_WIDTH-1:0] source_data
	);

`define FSM_IDLE			0
`define FSM_LINE_START	1
`define FSM_LINE_GET		2
`define FSM_LINE_DONE	3
`define FSM_LINE_WAIT	4

reg [3:0] fsm_state = `FSM_IDLE;
reg [15:0] pix_count = 16'b1;	
reg [15:0] line_count = 16'b1;
reg [15:0] wait_count = 16'b0;
reg [15:0] wait_size = 16'b0;
reg [15:0] sop_wait_size = 16'h0;

//wire [2*DATA_WIDTH-1:0] sink_data;
wire [DATA_WIDTH-1:0] buffer_data [0:3];

wire fifo_sclr;
wire fifo1d_wr, fifo1d_rd, fifo2d_wr, fifo2d_rd, 
		fifo2d_wr_orig, fifo2d_rd_orig, source_valid_orig,
		source_eop_orig, source_sop_orig;
reg fifo2d_wr_r, fifo2d_rd_r, source_valid_r, source_eop_r, source_sop_r;
wire [9:0] usedw_1d, usedw_2d;
wire [3:0] rdusedw_stream, wrusedw_stream;

reg buffer_valid_r;
wire buffer_valid, buffer_empty;	

wire sum_l, sum_h, do_filt_line, do_filt_pix, frame_th;
wire [DATA_WIDTH-1:0] pix_abs;
wire [DATA_WIDTH-1:0] min_ab, max_ab, min_ab_c, pix_median;
reg [DATA_WIDTH-1:0] shift_mem [0:2] [0:11];
reg [DATA_WIDTH-1:0] out_shift_mem [0:11];
reg [DATA_WIDTH-1:0] sum [0:2] [0:2];
reg [DATA_WIDTH-1:0] sum_pix;
reg [DATA_WIDTH-1:0] delta_l, delta_h;
integer i, j;

initial begin
	for (i=0; i<3; i=i+1) begin
		for (j=0; j<12; j=j+1)
			shift_mem[i][j] = 0;
		for (j=0; j<3; j=j+1)
			sum[i][j] = 0;
	end
	for (i=0; i<12; i=i+1)
		out_shift_mem[i] = 16'b0;

end


// fsm for stream data	
always @(posedge clk) begin
	case (fsm_state)
		`FSM_IDLE: begin
			if (sink_sop)
				fsm_state <= `FSM_LINE_WAIT;
		end
		`FSM_LINE_START: begin
			fsm_state <= `FSM_LINE_GET;
		end
		`FSM_LINE_GET: begin
			if (pix_count == FRAME_WIDTH - 1) begin
				fsm_state <= `FSM_LINE_DONE;
				pix_count <= 10'b1;
			end
			else
				pix_count <= pix_count + 1;
		end
		`FSM_LINE_DONE: begin
			if ((line_count == FRAME_HEIGHT + 2)) begin
				fsm_state <= `FSM_IDLE;
				line_count <= 10'b1;
			end
				else begin
				fsm_state <= `FSM_LINE_WAIT;
				line_count <= line_count + 1;
			end
		end
		`FSM_LINE_WAIT: begin
			if (((sink_valid) && (!sink_sop) && (line_count < FRAME_HEIGHT)) || ((wait_count > wait_size) && (line_count >= FRAME_HEIGHT))) begin
				fsm_state <= `FSM_LINE_START;
			if (line_count == 1)
				sop_wait_size <= wait_count;
			else
				wait_size <= wait_count;
			wait_count <= 0;
			end
			else
				wait_count <= wait_count + 1;
		end
	endcase
end


// calculation of control sums
genvar k;
generate 
	for (k=0; k<3; k=k+1)
	begin: replace_line
		always @(posedge clk)
			if (source_valid_orig) begin
				for (i=11; i>0; i=i-1)
					shift_mem[k][i] <= shift_mem[k][i-1];
				shift_mem[k][0] <= buffer_data[k];
				
				sum[k][0] <= (shift_mem[k][0] + shift_mem[k][1] + shift_mem[k][2] + shift_mem[k][3]) >> 2;
				sum[k][1] <= (shift_mem[k][4] + shift_mem[k][5] + shift_mem[k][6] + shift_mem[k][7]) >> 2;		
				sum[k][2] <= (shift_mem[k][8] + shift_mem[k][9] + shift_mem[k][10] + shift_mem[k][11]) >> 2;
			end
	end
endgenerate

//median filter (1x3 column)
//a b c -> A B C (min, med, max)
assign min_ab = (shift_mem[0][10] > shift_mem[1][10]) ? shift_mem[1][10] : shift_mem[0][10];
assign max_ab = (shift_mem[0][10] > shift_mem[1][10]) ? shift_mem[0][10] : shift_mem[1][10];
assign min_ab_c = (shift_mem[2][10] > max_ab) ? max_ab : shift_mem[2][10];
assign pix_median = (min_ab > min_ab_c) ? min_ab : min_ab_c;
//filtering single bad pixels
assign pix_abs = (shift_mem[1][4] > sum_pix) ? shift_mem[1][4] - sum_pix :  sum_pix - shift_mem[1][4];
assign do_filt_pix = (frame_th && (pix_count > 1) && (pix_count < FRAME_WIDTH - 1) && (pix_abs > PIX_THRESHOLD));
//filter conditions
assign frame_th = ((line_count > 1) && (line_count < FRAME_HEIGHT)) ? 1'b1 :  1'b0;
assign do_filt_line = (frame_th && (pix_count > 12) && (pix_count < FRAME_WIDTH-12) && (delta_l >= THRESHOLD_LOW) && (delta_h < THRESHOLD_HIGH));
//++++---*++++
assign sum_l = (sum[1][1]<sum[1][0])&&(sum[1][1]<sum[1][2])&&(sum[1][1]<sum[0][0])&&(sum[1][1]<sum[0][1])&&(sum[1][1]<sum[0][2])&&(sum[1][1]<sum[2][0])&&(sum[1][1]<sum[2][1])&&(sum[1][1]<sum[2][2]);
//----+++*----
assign sum_h = (sum[1][1]>sum[1][0])&&(sum[1][1]>sum[1][2])&&(sum[1][1]>sum[0][0])&&(sum[1][1]>sum[0][1])&&(sum[1][1]>sum[0][2])&&(sum[1][1]>sum[2][0])&&(sum[1][1]>sum[2][1])&&(sum[1][1]>sum[2][2]);	

// filter (with shift-mem) + 12bit delay regs
always @(posedge clk) begin
	//11 clk blow out + 3 clk single pix
	fifo2d_wr_r <= repeat(11) @(posedge clk) fifo2d_wr_orig;
	fifo2d_rd_r <= repeat(11) @(posedge clk) fifo2d_rd_orig;
	source_valid_r <= repeat(11) @(posedge clk) source_valid_orig;
	source_eop_r <= repeat(11) @(posedge clk) source_eop_orig;
	source_sop_r <= repeat(11) @(posedge clk) source_sop_orig;	

	for (i=11; i>0; i=i-1)
		out_shift_mem[i] <= out_shift_mem[i-1];
	out_shift_mem[0] <= buffer_data[1];
	
	if (source_valid_orig) begin
		delta_l <= (shift_mem[1][6] > shift_mem[1][7]) ? shift_mem[1][6] - shift_mem[1][7] : shift_mem[1][7] - shift_mem[1][6];
		delta_h <= (shift_mem[1][7] > shift_mem[1][8]) ? shift_mem[1][7] - shift_mem[1][8] : shift_mem[1][8] - shift_mem[1][7];
		sum_pix <= (shift_mem[0][3]+shift_mem[0][4]+shift_mem[0][5]+shift_mem[1][3]+shift_mem[1][5]+shift_mem[2][3]+shift_mem[2][4]+shift_mem[2][5]) >> 3;

		if (en_blow_out) 
			if (do_filt_line && (sum_l || sum_h))
				for (i=0; i<4; i=i+1)
					out_shift_mem[i+5] <= (shift_mem[0][i+4] + shift_mem[0][i+5] + shift_mem[0][i+6] + shift_mem[2][i+4] + shift_mem[2][i+5] + shift_mem[2][i+6]) / 6;
		if (en_bad_replace)
			if (do_filt_pix)
				out_shift_mem[4] <= sum_pix;
		if (en_median && frame_th)
			out_shift_mem[10] <= pix_median;
	end
end

assign buffer_data[0] = sink_data;
// fifo for 1-line delay
assign fifo_sclr = sink_sop;//(fsm_state == `FSM_LINE_START) ? 1'b1 : 1'b0;
assign fifo1d_wr = (fsm_state == `FSM_LINE_GET) && (line_count < FRAME_HEIGHT + 1) ? 1'b1 : 1'b0;
assign fifo1d_rd = (fsm_state == `FSM_LINE_GET) && (line_count > 1) && (line_count < FRAME_HEIGHT + 2) ? 1'b1 : 1'b0;

fifo_640x16	fifo_line_1d (
	.clock (clk),
	.data (sink_data),
	.rdreq (fifo1d_rd),
	.sclr (1'b0),
	.wrreq (fifo1d_wr),
	.q (buffer_data[1]),
	.usedw (usedw_1d)
	);

// fifo for 2-line delay + 12bit (shift memory)
assign fifo2d_wr_orig = fifo1d_rd;
assign fifo2d_rd_orig = (line_count > 2) && (fsm_state == `FSM_LINE_GET) ? 1'b1 : 1'b0;

assign fifo2d_wr = fifo2d_wr_r;
assign fifo2d_rd = fifo2d_rd_r;

fifo_640x16	fifo_line_2d (
	.clock (clk),
	.data (shift_mem[1][11]),
	.rdreq (fifo2d_rd),
	.sclr (1'b0),
	.wrreq (fifo2d_wr),
	.q (buffer_data[2]),
	.usedw (usedw_2d)
	);
	
	
fifo_640x16	fifo_line_out (
	.clock (clk),
	.data (out_shift_mem[11]),
	.rdreq (fifo2d_rd),
	.sclr (1'b0),
	.wrreq (fifo2d_wr),
	.q (buffer_data[3]),
	.usedw (usedw_2d)
	);

// source data delayed with 2-line (fifo) + 12bit (shift memory)
assign source_valid_orig = fifo2d_rd_orig || source_sop_orig || source_eop_orig ? 1'b1 : 1'b0;
//assign source_sop_orig = ((fsm_state == `FSM_LINE_START) && (line_count == 3)) ? 1'b1 : 1'b0;
assign source_sop_orig = ((fsm_state == `FSM_LINE_WAIT) && (wait_count == wait_size - sop_wait_size) && (line_count == 3)) ? 1'b1 : 1'b0;
assign source_eop_orig = (fsm_state == `FSM_LINE_DONE) && (line_count == FRAME_HEIGHT + 2) ? 1'b1 : 1'b0;

assign source_data = buffer_data[3];
assign source_valid = source_valid_r;
assign source_sop = source_sop_r;
assign source_eop = source_eop_r;
	
endmodule
