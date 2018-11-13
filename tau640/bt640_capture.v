 //Cb = U, Cr = V
//input - bt.656 	(U Y V Y), 27MHz
//output - YUV422 	(Y V Y U), 24MHz
module bt640_capture (
	//Bt.656 from Tau640
	input 			raw_in_vclk,
	input 			raw_in_scl,
	input 			raw_in_sda,
	input [7:0] 	raw_in_data,
	//YVYU to Banana-pi
	output 			yuv_out_vclk,
	output			yuv_out_pclk,
	output			yuv_out_cam_pwdn,
	output 			yuv_out_scl,
	output 			yuv_out_sda,
	output 			yuv_out_vsync,
	output 			yuv_out_href,	
	output [9:0] 	yuv_out_data
	);
	
localparam bt_line_size = 720*2;
localparam bt_frame_size = 525;

localparam svga_line_size = 400;//800*2;
localparam svga_frame_size = 300;//600;

`define FSM_IDLE		0
`define FSM_EAV		1
`define FSM_BLANK		2
`define FSM_SAV		3
`define FSM_DATA		4

//fsm state reg
reg [2:0] fsm_state = `FSM_IDLE;
//counters
reg [15:0] line_cnt = 10'h0;
reg [15:0] pix_cnt = 10'h0;
//ordered regs
reg sync_flag;
reg [7:0] mem_in [0:3], mem_out [0:3];
reg [3:0] sync_delay;
reg [1:0] byte_order [0:3];
integer i;
//eav/sav catch wires
wire sav_code_catch, eav_code_catch;

//(U Y1 V Y2) -> (Y1 V Y2 U)
initial begin
	byte_order[0] = 2'h3;
	byte_order[1] = 2'h0;
	byte_order[2] = 2'h1;
	byte_order[3] = 2'h2;
	
	for (i = 0; i < 4; i = i + 1) begin
		mem_in[i] = 8'h0;
		mem_out[i] = 8'h0;
	end	
end

assign sav_code_catch = (!raw_in_data[4] && (mem_in[0] == 8'h00) && (mem_in[1] == 8'h00) && (mem_in[2] == 8'hFF)) ? 1'b1 : 1'b0;
assign eav_code_catch = (raw_in_data[4] && (mem_in[0] == 8'h00) && (mem_in[1] == 8'h00) && (mem_in[2] == 8'hFF)) ? 1'b1 : 1'b0;

//fsm
always @(posedge raw_in_vclk) begin
	case (fsm_state)
		`FSM_IDLE: begin
			if (sav_code_catch) begin
				fsm_state <= `FSM_SAV;
				line_cnt <= 10'h0;			
				sync_flag <= mem_in[0][5];
			end
		end
		`FSM_SAV: begin
			fsm_state <= `FSM_DATA;
			pix_cnt <= 10'h0;
			line_cnt <= line_cnt + 1;
		end
		`FSM_DATA: begin
			pix_cnt <= pix_cnt + 1;
			if (eav_code_catch || (pix_cnt == svga_line_size * 3))
				fsm_state <= `FSM_EAV;
		end
		`FSM_EAV: begin
			if (line_cnt >= svga_frame_size)
				fsm_state <= `FSM_IDLE;
			else
				fsm_state <= `FSM_BLANK;
		end
		`FSM_BLANK: begin
			if (sav_code_catch) begin
				fsm_state <= `FSM_SAV;
				sync_flag <= mem_in[0][5];
			end
		end
	endcase	
end

//input shift register
always @(posedge raw_in_vclk) begin
	mem_in[0] <= raw_in_data;
	sync_delay[0] <= ((fsm_state == `FSM_DATA) && (!sync_flag)) ? 1'b1 : 1'b0;
	for (i = 0; i < 3; i = i + 1) begin
		mem_in[i+1] <= mem_in[i];
		sync_delay[i+1] <= sync_delay[i];
	end
end


//output shift register
always @(posedge raw_in_vclk) begin
	for (i = 0; i < 3; i = i + 1)
		mem_out[i+1] <= mem_out[i];
	if (pix_cnt[1:0] == 2'b11)
		for (i = 0; i < 4; i = i + 1)
			mem_out[i] <= mem_in[byte_order[i]];
end


assign yuv_out_vclk		= raw_in_vclk;
assign yuv_out_pclk		= raw_in_vclk;
assign yuv_out_cam_pwdn = 1'b0;
assign yuv_out_scl 		= raw_in_scl;
assign yuv_out_sda 		= raw_in_sda;
assign yuv_out_vsync 	= ((fsm_state == `FSM_DATA) && (line_cnt == 1));
assign yuv_out_href 		= ((fsm_state == `FSM_DATA) || (fsm_state == `FSM_EAV)) && sync_delay[3];
assign yuv_out_data 		= (yuv_out_href && (pix_cnt < bt_line_size + 4)) ? {mem_out[3], 2'b00} : 10'h00;

endmodule
