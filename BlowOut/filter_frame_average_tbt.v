`timescale 1ns / 1ps
module FrameAverage_tb #(
	parameter DATA_WIDTH = 16,
	parameter FRAME_WIDTH = 640,
	parameter FRAME_HEIGHT = 10
	)
	(
	input en,
	input clk,
	input reset,
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

wire [DATA_WIDTH-1:0] fifo_data_i, fifo_data_o, av_data;
wire fifo_valid, av_valid;

reg [3:0] fsm_state = `FSM_IDLE;
reg [3:0] frame_count = 4'b0;
reg [9:0] pix_count = 10'b1;	
reg [9:0] line_count = 10'b1;
reg [9:0] wait_count = 10'b0;
reg [9:0] wait_size = 10'b0;
wire [12:0] fifo_usedw;

// fsm for stream data	
always @(posedge clk) begin
	case (fsm_state)
		`FSM_IDLE: begin
			if (sink_sop) begin
				fsm_state <= `FSM_LINE_WAIT;
				frame_count <= frame_count + 1;
			end
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
			if (((sink_valid) && (line_count < FRAME_HEIGHT)) || ((wait_count > wait_size) && (line_count >= FRAME_HEIGHT))) begin
				fsm_state <= `FSM_LINE_START;
			wait_size <= wait_count;
			wait_count <= 0;
			end
			else
				wait_count <= wait_count + 1;
		end
	endcase
end

assign fifo_valid = (frame_count > 1) ? sink_valid : 1'b0;
assign fifo_data_i = (frame_count == 1) ? sink_data : av_data;

fifo_640x10	fifo_frame_delay (
	.clock (clk),
	.data (fifo_data_i),
	.rdreq (fifo_valid),
	.sclr (reset),
	.wrreq (sink_valid),
	.q (fifo_data_o),
	.usedw (fifo_usedw)
	);

FrameAverage #(
	.DATA_WIDTH(DATA_WIDTH),
	.PRECISION(8)
	)
	average_filter
	(
	.clk(clk),
	.reset(reset),
	.en(1'b1),
	.new_valid(fifo_valid),
	.new_pix(sink_data),
	.old_pix(fifo_data_o),
	.cor_pix(av_data),
	.cor_valid(av_valid)
	);

assign source_sop = sink_sop;
assign source_eop = sink_eop;
assign source_data = av_data;
assign source_valid = av_valid || source_eop || source_sop;

endmodule
