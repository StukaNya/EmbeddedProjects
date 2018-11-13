`timescale 1ns / 1ps
// 20MHz - 50 ns
// 40MHz - 25 ns
module CLinkConvert #(
	parameter OUT_CLK_MHZ 		= 40,
	parameter LINE_WIDTH 		= 640,
	parameter LINE_DELAY_US 	= 25
	)
	(
	input 				en,
	input					rst,
	// CameraLink input interface (20 MHz)
	input 				clink_in_clk,
	input 				clink_in_fval,
	input 				clink_in_lval,
	input [15:0] 		clink_in_data,
	// CameraLink output interface (40 MHz)	
	input 				clink_out_clk,
	output 				clink_out_fval,
	output 				clink_out_lval,
	output [15:0] 		clink_out_data
	);

`define FSM_IDLE			0
`define FSM_FWAIT			1
`define FSM_LINE			2
`define FSM_LWAIT			3
`define FSM_EOF			4

localparam ldelay_ticks = LINE_DELAY_US * OUT_CLK_MHZ;  

wire [15:0] fifo_rx_din, fifo_rx_dout;	
wire fifo_rx_aclr, fifo_rx_wrreq, fifo_rx_rdreq;
wire [16:0] fifo_rx_usedw;

reg [3:0] fsm_state = `FSM_IDLE;
reg [15:0] pix_cnt = 16'h0;	
reg [15:0] lwait_cnt = 16'h0;

wire almost_full;

assign almost_full = (fifo_rx_usedw > 64) ? 1'b1 : 1'b0;
//-----Input FIFO---------//
assign fifo_rx_aclr = (!en || rst || (fsm_state == `FSM_EOF)) ? 1'b1 : 1'b0;
assign fifo_rx_wrreq = clink_in_lval;
assign fifo_rx_rdreq = (fsm_state == `FSM_LINE) ? 1'b1 : 1'b0;
assign fifo_rx_din = clink_in_data;

fifo_128kx16	fifo_rx_128kx16_inst (
	.aclr (fifo_rx_aclr),
	.data (clink_in_data),
	.rdclk (clink_out_clk),
	.rdreq (fifo_rx_rdreq),
	.wrclk (clink_in_clk),
	.wrreq (fifo_rx_wrreq),
	.q (fifo_rx_dout),
	.rdusedw (fifo_rx_usedw)
	);


//----- FSM for stream data-------//	
always @(posedge clink_out_clk) begin
	if (rst) begin
		fsm_state <= `FSM_IDLE;
		pix_cnt 		= 16'h0;
		lwait_cnt 	= 16'h0;
	end
	else
		case (fsm_state)
			`FSM_IDLE: begin
				if (en && clink_in_fval) begin
					fsm_state <= `FSM_FWAIT;
				end
			end
			`FSM_FWAIT: begin
				if (fifo_rx_usedw >= LINE_WIDTH) begin 
					fsm_state <= `FSM_LINE;
					lwait_cnt <= 16'h0;
					pix_cnt <= 16'h0;
				end
			end
			`FSM_LINE: begin 
				if (pix_cnt == LINE_WIDTH - 1) begin
					lwait_cnt <= 16'h0;
					if (almost_full)
						fsm_state <= `FSM_LWAIT;
					else
						fsm_state <= `FSM_EOF;
				end
					else
						pix_cnt <= pix_cnt + 1;
			end
			`FSM_LWAIT: begin
				if (lwait_cnt == ldelay_ticks - 1) begin 
					fsm_state <= `FSM_LINE;
					pix_cnt <= 16'h0;
				end
				else
					lwait_cnt <= lwait_cnt + 1;			
			end
			`FSM_EOF: begin
				if (!clink_in_fval)
					fsm_state <= `FSM_IDLE;
			end
		endcase
end

assign clink_out_fval		= !(fsm_state == `FSM_IDLE) ? 1'b1 : 1'b0;
assign clink_out_lval		= fifo_rx_rdreq;
assign clink_out_data		= (clink_out_lval) ?  fifo_rx_dout : 16'h0;
	
endmodule
