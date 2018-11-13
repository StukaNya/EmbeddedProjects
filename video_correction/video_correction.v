
module video_correction #(
	parameter video_width 	= 640,
	parameter video_height 	= 512,
	parameter accum_size 	= 4,
	parameter factor_k_addr = 32'h1fff,
	parameter factor_b_addr = 32'h3fff
	)
	(
	input avs_clk,
	input avs_reset,
	// Avalon-Stream input raw frame
	input 		   avs_sink_sof,
	input 		   avs_sink_valid,
	input [15:0]   avs_sink_data,
	input 		   avs_sink_eof,
	// Avalon Stream output calib frame
	output 			avs_source_sof,
	output 		   avs_source_valid,
	output [15:0]  avs_source_data,
	output 		   avs_source_eof,
	// Avalon-MM Slave (from Nios)
	input 			avmm_slv_rst,
	input 			avmm_slv_clk,
	input 			avmm_slv_wr,
	input 			avmm_slv_rd,
	input  [3:0] 	avmm_slv_address,
	input  [31:0] 	avmm_slv_wrdata,
	output [31:0] 	avmm_slv_rddata,
	// Avalon-MM Master (to LPDDR)
	input				avmm_m_rst,				
	input				avmm_m_clk,				
	output [31:0]	avmm_m_address,		
	input				avmm_m_waitrequest,	
	output [6:0]	avmm_m_burstcount,	
	output			avmm_m_write,			
	output [31:0]	avmm_m_writedata,		
	output			avmm_m_read,			
	input  [31:0]	avmm_m_readdata,		
	input				avmm_m_readdatavalid
	);

	
localparam burst_size = 64;
localparam pixel_number = video_width * video_height;

`define CALIB_YES			1
`define CALIB_NO			0

`define FSM_IDLE			0
`define FSM_SOF			1
`define FSM_WAIT			2
`define FSM_TEMP			3
`define FSM_GETL			4
`define FSM_EOF			5
`define FSM_ENABLE		6

`define DRV_IDLE			0	
`define DRV_ENABLE		1
`define DRV_READ_B		2
`define DRV_READ_K		3
`define DRV_GET_SUM		4
`define DRV_WRITE_SUM	5
`define DRV_DONE			6

	
//frame fifo, size 1024x16bit (for line < 1024 pixels)
wire [15:0] frame_rx_fifo_din, frame_rx_fifo_dout;	
wire frame_rx_fifo_aclr, frame_rx_fifo_wrreq, frame_rx_fifo_rdreq;
wire [9:0] frame_rx_fifo_usedw;

wire [15:0] frame_tx_fifo_din, frame_tx_fifo_dout;	
wire frame_tx_fifo_aclr, frame_tx_fifo_wrreq, frame_tx_fifo_rdreq;
wire [9:0] frame_tx_fifo_usedw;

//factor fifo, size 64x16bit (for Avalon-MM burst write/read size - 64 cycles)
wire [31:0] factor_k_fifo_din;
wire [15:0] factor_k_fifo_dout;	
wire factor_k_fifo_aclr, factor_k_fifo_wrreq, factor_k_fifo_rdreq;
wire [5:0] factor_k_fifo_usedw;

wire [31:0] factor_b_fifo_din;
wire [15:0] factor_b_fifo_dout;	
wire factor_b_fifo_aclr, factor_b_fifo_wrreq, factor_b_fifo_rdreq;
wire [5:0] factor_b_fifo_usedw;

wire [15:0] avg_sum_fifo_din, avg_sum_fifo_dout;	
wire avg_sum_fifo_aclr, avg_sum_fifo_wrreq, avg_sum_fifo_rdreq;
wire [5:0] avg_sum_fifo_usedw;

//calibration state regs
reg pt1_state = `CALIB_NO;
reg pt2_state = `CALIB_NO;

//fsm regs
reg [3:0] inline_state = `FSM_IDLE;
reg [3:0] outline_state = `FSM_IDLE;
reg [3:0] driver_state = `DRV_IDLE;

//ddr driver wires
wire				lpddr_read;
wire				lpddr_write;
wire				lpddr_readdatavalid;
wire	[31:0]	lpddr_address;
wire	[15:0]	lpddr_writedata;
wire	[31:0]	lpddr_readdata;

//counts
reg [15:0] frame_cnt = 16'h0;
reg [15:0] line_cnt 	= 16'h0;
reg [15:0] pix_cnt	= 16'h0;
reg [15:0] wait_size = 16'h0;
reg [15:0] inwait_cnt = 16'h0;
reg [15:0] outwait_cnt = 16'h0;
reg [15:0] drv_cnt = 16'h0;
//address regs
reg [31:0] burst_count = 32'h0;

//state regs
wire rx_fifo_empty;
reg avg_sum_sof, avg_sum_valid, avg_sum_eof;
reg [15:0] avg_sum_data;
reg [15:0] sum_reg, frame_reg;
reg [15:0] current_temp;

//--------- input frame fifo (from Avalon-ST) ------------//
assign frame_rx_fifo_aclr = avs_reset | avs_sink_sof;
assign frame_rx_fifo_wrreq = (inline_state == `FSM_GETL) ? 1'b1 : 1'b0;
assign frame_rx_fifo_rdreq = (driver_state == `DRV_GET_SUM) ? 1'b1 : 1'b0;
assign frame_rx_fifo_din = avs_sink_data;
assign rx_fifo_empty = !((frame_rx_fifo_usedw > burst_size) && (inline_state == `FSM_GETL)) ? 1'b1 : 1'b0;

frame_fifo_1kx16	frame_rx_fifo (
	.aclr (frame_rx_fifo_aclr),
	.clock (avs_clk),
	.data (frame_rx_fifo_din),
	.rdreq (frame_rx_fifo_rdreq), 
	.wrreq (frame_rx_fifo_wrreq),
	.q (frame_rx_fifo_dout),
	.usedw (frame_rx_fifo_usedw)
	);
	
//--------- input factor-k fifo (from Avalon-MM) ------------//
assign factor_k_fifo_aclr = avs_reset | avs_sink_sof;
assign factor_k_fifo_wrreq = (driver_state == `DRV_READ_K) ? lpddr_readdatavalid : 1'b0;
assign factor_k_fifo_rdreq = (driver_state == `DRV_GET_SUM) ? 1'b1 : 1'b0;
assign factor_k_fifo_din = lpddr_readdata;
	
factor_fifo_64w32r16	factor_k_fifo (
	.aclr (factor_k_fifo_aclr),
	.data (factor_k_fifo_din),
	.rdclk (avs_clk),
	.rdreq (factor_k_fifo_rdreq),
	.wrclk (avmm_m_clk),
	.wrreq (factor_k_fifo_wrreq),
	.q (factor_k_fifo_dout),
	.wrusedw (factor_k_fifo_usedw)
	);
	
//--------- input factor-b fifo (from Avalon-MM) ------------//
assign factor_b_fifo_aclr = avs_reset | avs_sink_sof;
assign factor_b_fifo_wrreq = (driver_state == `DRV_READ_B) ? lpddr_readdatavalid : 1'b0;
assign factor_b_fifo_rdreq = (driver_state == `DRV_GET_SUM) ? 1'b1 : 1'b0;
assign factor_b_fifo_din = lpddr_readdata;
	
factor_fifo_64w32r16	factor_b_fifo (
	.aclr (factor_b_fifo_aclr),
	.data (factor_b_fifo_din),
	.rdclk (avs_clk),
	.rdreq (factor_b_fifo_rdreq),
	.wrclk (avmm_m_clk),
	.wrreq (factor_b_fifo_wrreq),
	.q (factor_b_fifo_dout),
	.wrusedw (factor_b_fifo_usedw)
	);

//--------- output avg_sum fifo (to Avalon-MM) ------------//
assign avg_sum_fifo_aclr = avs_reset | avs_sink_sof;
assign avg_sum_fifo_wrreq = (driver_state == `DRV_GET_SUM) ? 1'b1 : 1'b0;
assign avg_sum_fifo_rdreq = (driver_state == `DRV_WRITE_SUM) ? 1'b1 : 1'b0;
assign avg_sum_fifo_din = sum_reg;
	
factor_fifo_64x16	avg_sum_fifo (
	.aclr (avg_sum_fifo_aclr),
	.data (avg_sum_fifo_din),
	.rdclk (avmm_m_clk), 
	.rdreq (avg_sum_fifo_rdreq),
	.wrclk (avs_clk),
	.wrreq (avg_sum_fifo_wrreq),
	.q (avg_sum_fifo_dout),
	.wrusedw (avg_sum_fifo_usedw)
	);
	
//------ output frame fifo (to Avalon-ST) -----------//
assign frame_tx_fifo_aclr = avs_reset | avs_sink_sof;
assign frame_tx_fifo_wrreq = (driver_state == `DRV_GET_SUM) ? 1'b1 : 1'b0;
assign frame_tx_fifo_rdreq = (outline_state == `FSM_GETL) ? 1'b1 : 1'b0;
//Overflow for >4 iterations! (max pixel value - 0x3fff, 14bit)
assign frame_tx_fifo_din = frame_reg;

frame_fifo_1kx16	frame_tx_fifo (
	.aclr (frame_tx_fifo_aclr),
	.clock (avs_clk),
	.data (frame_tx_fifo_din),
	.rdreq (frame_tx_fifo_rdreq),
	.wrreq (frame_tx_fifo_wrreq),
	.q (frame_tx_fifo_dout),
	.usedw (frame_tx_fifo_usedw)
	);

//-------- Correction procedure ---------------//
always @(posedge avs_clk)
begin
	if (avs_reset) begin
		sum_reg <= 16'h0;
		frame_reg = 16'h0;
	end
	else 
		if (driver_state == `DRV_GET_SUM) begin
			// x_i - input frame; y - output frame; k, b - 2point factors
			// 1PT calibration; sum_reg -> avg_sum_fifo
			if (pt1_state == `CALIB_YES) begin
				// b_sum = x_0
				if (frame_cnt == 1)
					sum_reg <= frame_rx_fifo_dout;
				// b_sum = b_sum + x_i; i < 4
				if ((frame_cnt > 1) && (frame_cnt < accum_size + 1))
					sum_reg <= frame_rx_fifo_dout + factor_b_fifo_dout;
				// b_avg = b_sum / 4
				if (frame_cnt == accum_size + 1)
					sum_reg <= factor_b_fifo_dout >> 2;
				// b = b_avg - (k * x) >> 16;
				if (frame_cnt == accum_size + 2)
					sum_reg <= factor_b_fifo_dout - (factor_k_fifo_dout * frame_rx_fifo_dout) >> 16;
			end
			// 2PT calibration; frame_reg -> frame_tx_fifo
			// y = k * x + b 
			if (pt2_state == `CALIB_YES)
				frame_reg <= (factor_k_fifo_dout * frame_rx_fifo_dout) >> 16 + factor_b_fifo_dout;
			else
				frame_reg <= frame_rx_fifo_dout;
		end

end

//----- Input fsm -------//
always @(posedge avs_clk)
begin
	if (avs_reset) begin
		inline_state <= `FSM_IDLE;
	end
	else
		case (inline_state)
			`FSM_IDLE: begin
				if (avs_sink_sof && avs_sink_valid) begin
					inline_state <= `FSM_SOF;
				end
			end
			`FSM_SOF: begin
				inline_state <= `FSM_WAIT;
				inwait_cnt <= 16'h0;
			end
			`FSM_WAIT: begin
				if (avs_sink_valid) begin
					inline_state <= `FSM_TEMP;
					wait_size <= inwait_cnt;
				end
				else
					inwait_cnt <= inwait_cnt + 1;
			end
			`FSM_TEMP: begin
				inline_state <= `FSM_GETL;
				current_temp <= avs_sink_data;
			end
			`FSM_GETL: begin
			if (avs_sink_eof)
				inline_state <= `FSM_EOF;
			else
				if (!avs_sink_valid) begin
					inline_state <= `FSM_WAIT;
					inwait_cnt <= 16'h0;
				end
			end
			`FSM_EOF: begin
				inline_state <= `FSM_IDLE;
			end
		endcase
end

//------- LPDDR Driver -------//

assign lpddr_read = ((driver_state == `DRV_READ_K) || (driver_state == `DRV_READ_B)) ? 1'b1 : 1'b0;
assign lpddr_write = (driver_state == `DRV_WRITE_SUM) ? 1'b1 : 1'b0;
assign lpddr_address = factor_k_addr;
assign lpddr_writedata = (driver_state == `DRV_WRITE_SUM) ? factor_k_fifo_dout : (driver_state == `DRV_WRITE_SUM);


always @(posedge avmm_m_clk) begin
	if (avmm_m_rst)
		driver_state = `DRV_IDLE;
	else
		case (driver_state)
			`DRV_IDLE: begin
				if (avs_sink_sof && avs_sink_valid) begin
					driver_state = `DRV_ENABLE;
					burst_count <= 0;
				end
			end
			`DRV_ENABLE: begin
				if (!rx_fifo_empty)
					driver_state <= `DRV_READ_K;
			end
			`DRV_READ_K: begin
				if (factor_k_fifo_usedw == burst_size - 1)
					driver_state = `DRV_READ_B;		 
			end
			`DRV_READ_B: begin
				if (factor_b_fifo_usedw == burst_size - 1)
					driver_state = `DRV_GET_SUM;		
			end
			`DRV_GET_SUM: begin
				if (avg_sum_fifo_usedw == burst_size - 1)
					driver_state = `DRV_WRITE_SUM;				
			end
			`DRV_WRITE_SUM: begin
				if (avg_sum_fifo_usedw == 0)
					driver_state = `DRV_DONE;		
			end
			`DRV_DONE: begin
				burst_count <= burst_count + 1;
				if (outline_state != `FSM_WAIT)
					driver_state <= `DRV_IDLE;
			end
		endcase
end


//----- Output fsm -------//
always @(posedge avmm_m_clk)
begin
	if (avs_reset) begin
		outline_state <= `FSM_IDLE;
		frame_cnt <= 0;
	end
	else
		case (outline_state)
			`FSM_IDLE: begin
				if (pt1_state == `CALIB_NO)
					frame_cnt <= 16'h0;
				if (driver_state == `DRV_DONE)
					outline_state <= `FSM_SOF;
			end
			`FSM_SOF: begin
				outline_state <= `FSM_WAIT;
				frame_cnt <= frame_cnt + 1;
				outwait_cnt <= 16'h0;
				line_cnt <=	8'h0;
			end
			`FSM_WAIT: begin
				if ((outwait_cnt == wait_size) || (driver_state == `DRV_DONE)) begin
					outline_state <= `FSM_TEMP;
					line_cnt <= line_cnt + 1;
					pix_cnt <= 8'h0;
				end
				else
					outwait_cnt <= outwait_cnt + 1;
			end
			`FSM_TEMP: begin
				outline_state <= `FSM_GETL;
			end
			`FSM_GETL: begin
				if (pix_cnt == video_width - 1) begin
					outwait_cnt <= 16'h0;
					if (line_cnt < video_height)
						outline_state <= `FSM_WAIT;
					else
						outline_state <= `FSM_EOF;
				end
				else 
					pix_cnt <= pix_cnt + 1;
			end
			`FSM_EOF: begin
				outline_state <= `FSM_IDLE;
			end
		endcase
end


lpddr_burst_driver_16bit lpddr_burst_driver_16bit_inst
(
	.avmm_m_rst					( avmm_m_rst ),
	.avmm_m_clk					( avmm_m_clk ),
	.avmm_m_address			( avmm_m_address ),	
	.avmm_m_waitrequest		( avmm_m_waitrequest ),
	.avmm_m_burstcount		( avmm_m_burstcount ),
	.avmm_m_write				( avmm_m_write ),
	.avmm_m_writedata			( avmm_m_writedata ),	
	.avmm_m_read				( avmm_m_read ),
	.avmm_m_readdata			( avmm_m_readdata ),
	.avmm_m_readdatavalid	( avmm_m_readdatavalid ),
	.lpddr_rst					( avmm_m_rst | avmm_m_lsync ),
	.lpddr_clk					( avmm_m_clk ),
	.lpddr_write				( lpddr_write ),
	.lpddr_read					( lpddr_read ),
	.lpddr_readdatavalid		( lpddr_readdatavalid ),
	.lpddr_address				( lpddr_address ),
	.lpddr_writedata			( lpddr_writedata ),
	.lpddr_readdata			( lpddr_readdata )
);

assign avs_source_sof = (outline_state == `FSM_SOF) ? 1'b1 : 1'b0;
assign avs_source_valid = (avs_source_sof || avs_source_eof || (outline_state == `FSM_TEMP) || (outline_state == `FSM_GETL)) ? 1'b1 : 1'b0;
//добавить вывод температуры
assign avs_source_data = (outline_state == `FSM_TEMP) ? current_temp : (outline_state == `FSM_GETL) ? frame_tx_fifo_dout : 16'h0;
assign avs_source_eof = (outline_state == `FSM_EOF) ? 1'b1 : 1'b0;

//----------- Avalon slave interface-------------//

always @(posedge avmm_slv_clk)
begin
	if (avmm_slv_rst) begin
		pt1_state = `CALIB_NO;
		pt2_state = `CALIB_NO;
	end
	else
		if (avmm_slv_wr)
			case (avmm_slv_address[3:0])
				4'h0: pt1_state = (avmm_slv_wrdata == 32'h0) ? `CALIB_NO : `CALIB_YES;
				4'h1: pt2_state = (avmm_slv_wrdata == 32'h0) ? `CALIB_NO : `CALIB_YES;
			endcase
end

assign slave_rddata = (avmm_slv_rd) ? {30'h0, pt2_state, pt1_state} : 32'h0;

endmodule
