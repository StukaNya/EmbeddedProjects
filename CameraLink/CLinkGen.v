`timescale 1ns / 1ps
module CLinkGenerator #(
	parameter DATA_WIDTH 		= 16,
	parameter CLK_MHZ 			= 20,
	parameter FRAME_WIDTH 		= 512,
	parameter LINE_WIDTH 		= 640,
	parameter FRAME_DELAY_US 	= 2000,
	parameter FRAME_PERIOD_US	= 38000,
	parameter LINE_DELAY_NS 	= 100
	)
	(
	input 						en,
	input 						rst,
	input 						clk,
	// CameraLink interface
	output 						clink_clk,
	output 						clink_fval,
	output 						clink_lval,
	output [DATA_WIDTH-1:0] clink_data
	);

`define FSM_IDLE			0
`define FSM_FWAIT			2
`define FSM_LINE			3
`define FSM_LWAIT			4
`define FSM_EOF			5

localparam fdelay_ticks = FRAME_DELAY_US * CLK_MHZ;
localparam fperiod_ticks = FRAME_PERIOD_US * CLK_MHZ;
localparam ldelay_ticks = LINE_DELAY_NS * CLK_MHZ / 1000;  

reg [3:0] fsm_state = `FSM_IDLE;
reg [15:0] pix_cnt = 16'h0;	
reg [15:0] line_cnt = 16'h0;
reg [15:0] lwait_cnt = 16'h0;
reg [15:0] fwait_cnt = 16'h0;
reg [23:0] fperiod_cnt = 24'h0;

// fsm for stream data	
always @(posedge clk) begin
	if (rst) begin
		fsm_state <= `FSM_IDLE;
		pix_cnt 		= 16'h0;
		line_cnt 	= 16'h0;
		lwait_cnt 	= 16'h0;
		fwait_cnt	= 16'h0;
	end
	else
		case (fsm_state)
			`FSM_IDLE: begin
				if (en) begin
					fsm_state <= `FSM_FWAIT;
					fwait_cnt <= 16'h0;
					fperiod_cnt <= 24'h0;
				end
			end
			`FSM_FWAIT: begin
				if (!en)
					fsm_state <= `FSM_IDLE;
				else
					if (fwait_cnt == fdelay_ticks - 1) begin 
						fsm_state <= `FSM_LWAIT;
						lwait_cnt <= 16'h0;
						line_cnt <= 16'h0;
						fperiod_cnt <= 24'h0;
					end
					else
						fwait_cnt <= fwait_cnt + 1;					
			end
			`FSM_LWAIT: begin
				fperiod_cnt <= fperiod_cnt + 1;
				if (lwait_cnt == ldelay_ticks - 1) begin 
					fsm_state <= `FSM_LINE;
					line_cnt <= line_cnt + 1;
					pix_cnt <= 16'h0;
				end
				else
					lwait_cnt <= lwait_cnt + 1;			
			end
			`FSM_LINE: begin
				fperiod_cnt <= fperiod_cnt + 1;				
				if (pix_cnt == LINE_WIDTH - 1) begin
					lwait_cnt <= 16'h0;
					fwait_cnt <= 16'h0;
					if (line_cnt == FRAME_WIDTH)
						fsm_state <= `FSM_EOF;
					else
						fsm_state <= `FSM_LWAIT;
				end
					else
						pix_cnt <= pix_cnt + 1;
			end
			`FSM_EOF: begin
				if (fperiod_cnt == fperiod_ticks)
					fsm_state <= `FSM_FWAIT;
				else
					fperiod_cnt <= fperiod_cnt + 1;
			end
		endcase
end

assign clink_clk		= clk;
assign clink_fval		= !((fsm_state == `FSM_IDLE) || (fsm_state == `FSM_FWAIT)) ? 1'b1 : 1'b0;
assign clink_lval		= (fsm_state == `FSM_LINE) ? 1'b1 : 1'b0;
assign clink_data		= (clink_lval) ? pix_cnt + 1000 * line_cnt : 16'h0;

endmodule
