module scorpio_cmd_uart(
// avalon slave interface	
	input slave_clk,
	input slave_reset,
	input slave_cs,
	input slave_wr,
	input slave_rd,
	input [31:0] slave_wrdata,
	input [15:0] slave_address,
	output [31:0] slave_rddata,
	//serial 
	output Tx,
	input Rx
	);

localparam [2:0]
	idle = 3'b000,
	command = 3'b001,
	address = 3'b010,
	message = 3'b011,
	message2 = 3'b101,
	wait_end = 3'b100;

`define FSM_IDLE			0
`define FSM_SOF			1
`define FSM_ADDRESS		2
`define FSM_DATA			3
`define FSM_CRC			4
`define FSM_WAIT			5

`define WORD_SOF			8'h40	//@
`define WORD_WRITE		8'h57	//W
`define WORD_READ			8'h52	//R
`define WORD_YES			8'h59	//Y			
`define WORD_NO			8'h4E	//N
`define WORD_ERR			8'h45	//E
`define WORD_R2F			8'h3E	//> 
`define WORD_F2R			8'h3C	//<

localparam StartByte=8'hAA; //h24 - izrail version
localparam LengthData_1=16'h0000;

parameter DBIT = 8;     //data bits
parameter SB_TICK = 25; //ticks for stop bits, 16/24/32 for 1/1.5/2 stop bits

reg [31:0] rddata_reg = 32'h0;
reg tx_start = 1'b0, Busy = 1'b0, Rd_reg = 1'b0, Wr_reg = 1'b0;
reg [2:0] state_reg = idle, state_next = idle;	 			
reg [7:0] data_wr = 0, message_out = 0, message_in = 0, MessageAddr = 0;
wire tx_done_tick, rx_done_tick, flag, SetWr, SetRd;

wire tx_done, rx_done, flag_tx, flag_rx;
reg [8:0] Cnt = 0;

wire [7:0] data_rd;

reg test_wr = 0;
reg test_rd = 0;

uart_rx_h #(.DBIT(DBIT), .SB_TICK(SB_TICK)) uart_rx (
	.clk(slave_clk), 
	.reset(slave_reset), 
	.rx(Rx), 
   .rx_done_tick(rx_done), 
	.dout(data_rd[7:0]));

uart_tx_h #(.DBIT(DBIT), .SB_TICK(SB_TICK)) uart_tx (
	.clk(slave_clk), 
	.reset(slave_reset), 
	.tx_start(tx_start),
	.din(data_wr[7:0]),
   .tx_done_tick(tx_done), 
	.tx(Tx));

		
	always @(posedge slave_clk)
	begin
		if (slave_reset)
			begin
				state_reg <= `FSM_IDLE;
				state_next <= idle;
				Busy <= 1'b0;
				Wr_reg <= 1'b0;
				Rd_reg <= 1'b0;
			end
		else
			begin
				if (tx_start) 
					tx_start <= 0;
				state_reg <= state_next;
			end
			
		case (state_reg)
			`FSM_IDLE: begin
				if (SetRd || SetWr)
					begin
						state_next <= `FSM_SOF;
						Busy <= 1'b1;
						if (SetWr) 
						begin
							{Wr_reg, Rd_reg} <= 2'b10;
							test_wr <= 1'b1;
						end
						else
						if (SetRd)
						begin	
							{Wr_reg, Rd_reg} <= 2'b01;
							test_rd <= 1'b1;
						end
					end
			end
			`FSM_SOF: begin
				data_wr <= `WORD_SOF;
				tx_start <= 1;
			end
			`FSM_SOF: begin
				if (tx_done) begin
					if (Wr_reg) 
						data_wr <= `WORD_WRITE;
					else
					if (Rd_reg)
						data_wr <= `WORD_READ;
					tx_start <= 1;
					state_next <= msg_addr;
				end
			end
			`FSM_ADDRESS:
				begin
					if (tx_done)
						begin
							data_wr[7:0] <= 8'h22;//MessageAddr[7:0];//addr_reg[7:0];
							tx_start <= 1;
							state_next <= message;
						end
				end
			message:
				begin
					if (tx_done)
						begin
							if (Wr_reg)
								data_wr[7:0] <= 8'hEE;//message_out[7:0];
							else
							if (Rd_reg)
								//data_wr[7:0] <= 8'h00;
								data_wr[7:0] <= message_out[7:0];
							tx_start <= 1;
							state_next <= wait_end;
						end
				end
			wait_end:
				begin
					if (tx_done)
						begin
							if (Rd_reg)
								message_in[7:0] <= data_rd[7:0];
							state_next <= idle;
							Busy <= 1'b0; 	
							Wr_reg <= 1'b0;
							Rd_reg <= 1'b0;
						end
				end
		endcase
	
	end



// Avalon slave interface
assign do_wr = slave_cs && slave_wr && (slave_address[3:0] == 4'h0);
assign do_rd = slave_cs && slave_wr && (slave_address[3:0] == 4'h1);

always @(posedge slave_clk)
	if (slave_reset) begin
		{crc_out[15:0], msg_out[7:0]} <= 24'h0;
		msg_addr <= 12'h0;
	end
	else 
		if (slave_wr) begin
			{crc_out[15:0], msg_out[7:0]} <= slave_wrdata[23:0];
			msg_addr <= slave_addr[15:4];
		end
	

always @(posedge slave_clk)
	if (slave_reset)
		rddata_reg <= 32'b0;
	else
		case (slave_address[3:0])
			4'h0: rddata_reg <= {crc_in[15:0], msg_out[7:0]};
			4'h1: rddata_reg <= {crc_in[15:0], mg_in[7:0]};
			4'h2: rddata_reg <= {crc_in[15:0], 8'h0};
			4'h3: rddata_reg <= {crc_in[15:0], 8'h0};		
		endcase

assign slave_rddata = (slave_cs && slave_rd) ? rddata_reg : 32'h0;
		
endmodule  