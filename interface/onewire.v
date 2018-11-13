module onewire_rw 
	#(
	//6,25 ticks in 1us (6,25 MHz)
	parameter OW_TICKS_MS = 6250,
	parameter OW_SEC_DELAY = 3
	)
	(
	input 	ow_clk,
	input 	ow_reset,
	output 	ow_en_in,
	output	ow_en_out,
	input 	ow_data_in,
	output 	ow_data_out,
	output 	temp_en,
	output 	[15:0] temp_data
	);

localparam comm_size = 5;
	
//io command states
`define COM_IDLE			0
`define COM_RESET_DO		1
`define COM_RESET_WAIT	2
`define COM_RESET_DONE	3
`define COM_WRITE_DO		4
`define COM_WRITE_WAIT	5
`define COM_WRITE_DONE	6
`define COM_READ_DO		7
`define COM_READ_WAIT	8
`define COM_READ_DONE	9
`define COM_FINISH		10
	
//io fsm states
`define FSM_IDLE				0	
`define FSM_RESET_START		1
`define FSM_RESET_DO			2
`define FSM_RESET_DONE		3
`define FSM_WRITE_START		4
`define FSM_WRITE_BIT		5
`define FSM_WRITE_RELEASE	6
`define FSM_WRITE_DONE		7
`define FSM_READ_START		8
`define FSM_READ_RELEASE	9
`define FSM_READ_BIT			10
`define FSM_READ_WAIT		11
`define FSM_READ_RECOVERY	12
`define FSM_READ_DONE		13

`define DS1821_READ_TEMP			8'hAA
`define DS1821_START_CONVERT		8'hEE
`define DS1821_STOP_CONVERT		8'h22
`define DS1821_WRITE_STATUS		8'h0C
`define DS1821_READ_STATUS			8'hAC
`define DS1821_READ_COUNTER		8'hA0
`define DS1821_LOAD_COUNTER		8'h41
`define DS1821_WRITE_TH				8'h01
`define DS1821_WRITE_TL				8'h02
`define DS1821_READ_TH				8'hA1
`define DS1821_READ_TL				8'hA2

//1-wire bus
reg ow_reg;
//io fsm regs	
wire wr_bit_done, rd_bit_done, reset_done, write_done, read_done;
reg usleep_done, msleep_done;
reg [4:0] byte_cnt;
reg [4:0] fsm_state = `FSM_IDLE;
reg [8:0] wrdata_reg;
reg [8:0] rddata_reg;
//command regs
reg [4:0] com_state;
//ordered commands (8 bit)
reg [7:0] command_arr [0:comm_size-1];
//ordered data (9 bit )
reg [8:0] read_arr [0:comm_size-1];
reg [comm_size-1:0] command_reg;
reg [2:0] cnt_com;
//temperature regs
reg [15:0] temp_read, count_per_c, count_remain;
reg [31:0] temp_round, temp_fraction, temp_out;
integer i;

initial
begin
	//init io regs
	ow_reg = 1'b1;
	//init fsm_regs
	byte_cnt = 5'h0;
	wrdata_reg = command_arr[0];
	rddata_reg = 9'h0;
	//init comm regs
	cnt_com = 3'h0;
	command_arr[0] = `DS1821_START_CONVERT;
	command_arr[1] = `DS1821_READ_TEMP;
	command_arr[2] = `DS1821_READ_COUNTER;
	command_arr[3] = `DS1821_LOAD_COUNTER;
	command_arr[4] = `DS1821_READ_COUNTER;
	//Wr/Rd/Rd/Wr/Rd operations, Wr: 1, Rd: 0
	command_reg = 5'b01001;//5'b10010;
	//read temp arr
	temp_read		= 16'd0;
	count_per_c		= 16'd0;
	count_remain	= 16'd0;
	temp_round		= 31'd0;
	temp_fraction	= 31'd0;
	temp_out			= 31'd0;
	for (i = 0; i < comm_size; i = i + 1)
		read_arr[i] <= 9'h0;
end


always @(posedge ow_clk)
	if (ow_reset) begin
		com_state <= `COM_IDLE;
	end
	else
		case (com_state)
			`COM_IDLE: begin
				msleep(OW_SEC_DELAY * 1000, msleep_done);
				if (msleep_done) begin
					com_state <= `COM_RESET_DO;
				end
			end
			`COM_RESET_DO: begin
				com_state <= `COM_RESET_WAIT;
			end
			`COM_RESET_WAIT: begin
				if (reset_done) begin
					com_state <= `COM_RESET_DONE;
				end
			end
			`COM_RESET_DONE : begin
				msleep(1, msleep_done);
				if (msleep_done)
					com_state <= `COM_WRITE_DO;
			end
			`COM_READ_DO: begin
				com_state <= `COM_READ_WAIT;
			end
			`COM_READ_WAIT: begin
				if (read_done) begin
					com_state <= `COM_READ_DONE;
					read_arr[cnt_com] <= rddata_reg;
				end
			end
			`COM_READ_DONE: begin
				msleep(1, msleep_done);
				if (msleep_done) begin
					com_state <= `COM_FINISH;
				end
			end
			`COM_WRITE_DO: begin
				wrdata_reg <= command_arr[cnt_com];
				com_state <= `COM_WRITE_WAIT;
			end
			`COM_WRITE_WAIT: begin
				if (write_done) begin
					com_state <= `COM_WRITE_DONE;
				end
			end
			`COM_WRITE_DONE: begin
				msleep(1, msleep_done);
				if (msleep_done) begin
					com_state <= (command_reg[cnt_com] == 1'b1) ? `COM_FINISH : `COM_READ_DO;
				end
			end
			`COM_FINISH: begin
				if (cnt_com == 4'd4) begin
					com_state <= `COM_IDLE;
					cnt_com <= 4'd0;
				end
				else 
					if (cnt_com == 4'd0) begin
						com_state <= `COM_IDLE;
						cnt_com <= 4'd1;
					end
					else begin
						cnt_com <= cnt_com + 1;
						com_state <= `COM_RESET_DO;
					end			
			end
		endcase


assign wr_bit_done = (byte_cnt == 5'h7) ? 1'b1 : 1'b0;
assign rd_bit_done = (cnt_com < 3'd2) ? (byte_cnt == 5'h7) : (byte_cnt == 5'h8);
assign reset_done = (fsm_state == `FSM_RESET_DONE) ? 1'b1 : 1'b0;
assign write_done = (fsm_state == `FSM_WRITE_DONE) ? 1'b1 : 1'b0;
assign read_done 	= (fsm_state == `FSM_READ_DONE) ? 1'b1 : 1'b0;

always @(posedge ow_clk)
	if (ow_reset) begin
		fsm_state <= `FSM_IDLE;
		byte_cnt = 4'h7;
	end
	else
		case (fsm_state)
			`FSM_IDLE: begin
				case (com_state)
					`COM_RESET_DO: fsm_state <= `FSM_RESET_START;
					`COM_READ_DO: 	fsm_state <= `FSM_READ_START;
					`COM_WRITE_DO:	fsm_state <= `FSM_WRITE_START;
					default: fsm_state <= `FSM_IDLE;
				endcase
			end
			//Reset procedure
			`FSM_RESET_START: begin
				ow_reg <= 1'b0;
				usleep(480, usleep_done);
				if (usleep_done)
					fsm_state <= `FSM_RESET_DO;
			end
			`FSM_RESET_DO: begin
				ow_reg <= 1'b1;
				usleep(300, usleep_done);
				if (usleep_done)
					fsm_state <= `FSM_RESET_DONE;
			end
			`FSM_RESET_DONE: begin
				fsm_state <= `FSM_IDLE;
			end
			//Write procedure
			`FSM_WRITE_START: begin
				ow_reg <= 1'b0;
				usleep(15, usleep_done); //8
				if (usleep_done)
					fsm_state <= `FSM_WRITE_BIT;
			end
			`FSM_WRITE_BIT: begin
				ow_reg <= wrdata_reg[byte_cnt];
				usleep(45, usleep_done); //42
				if (usleep_done)
					fsm_state <= `FSM_WRITE_RELEASE;
			end
			`FSM_WRITE_RELEASE: begin
				ow_reg <= 1'b1;
				usleep(5, usleep_done); //2
				if (usleep_done) begin
					if (wr_bit_done) begin
						fsm_state <= `FSM_WRITE_DONE;
						byte_cnt <= 5'h0;
					end
					else begin
						byte_cnt <= byte_cnt + 1;
						fsm_state <= `FSM_WRITE_START;
					end
				end
			end
			`FSM_WRITE_DONE: begin
					fsm_state <= `FSM_IDLE;
			end
			//Read procedure
			`FSM_READ_START: begin
				ow_reg <= 1'b0;
				usleep(2, usleep_done); //2
				if (usleep_done)
					fsm_state <= `FSM_READ_RELEASE;
			end
			`FSM_READ_RELEASE: begin
				ow_reg <= 1'b1;
				usleep(5, usleep_done); //5
				if (usleep_done) begin
					fsm_state <= `FSM_READ_BIT;
				end
			end
			`FSM_READ_BIT: begin
				fsm_state <= `FSM_READ_WAIT;
				rddata_reg[byte_cnt] <= ow_data_in;
			end
			`FSM_READ_WAIT: begin
				//ow_reg <= 1'b1;
				usleep(53, usleep_done); //53
				if (usleep_done)
					fsm_state <= `FSM_READ_RECOVERY;
			end
			`FSM_READ_RECOVERY: begin
				ow_reg <= 1'b1;
				usleep(5, usleep_done); //5
				if (usleep_done) begin
					if (rd_bit_done) begin
						byte_cnt = 5'h0;
						fsm_state <= `FSM_READ_DONE;
					end
					else begin
						byte_cnt <= byte_cnt + 1;
						fsm_state <= `FSM_READ_START;
					end
				end
			end
			`FSM_READ_DONE: begin
				fsm_state <= `FSM_IDLE;
			end
		endcase


always @(posedge ow_clk) 
begin
	temp_read[7:0] 	<= read_arr[1];
	count_remain[8:0]	<= read_arr[2];
	count_per_c[8:0]	<= read_arr[4];
	
	//temp_round <= temp_read << 9; //512 * 
	//temp_fraction <= ((count_per_c - count_remain) << 9) / count_per_c; //512 * 
	//temp_out <= (temp_round - 256 + temp_fraction) >> 2; /// 14 bit format
  
	temp_round <= temp_read << 8; //512 * 
   temp_fraction <= ((count_per_c - count_remain) << 8) / count_per_c;
	temp_out <= (temp_round - 128 + temp_fraction);
end
		
		
reg [63:0] utick_cnt = 64'h0;
task automatic usleep (
	input [63:0] us_delay,
	output done );
	reg [63:0] utick_delay = (us_delay * OW_TICKS_MS) >>  10; /// 1000
	begin
		done = 0;
		if (utick_cnt >= utick_delay) begin
			utick_cnt = 63'h0;
			done = 1'b1;			
		end
		else begin
			utick_cnt = utick_cnt + 1;		
			done = 0;
		end
	end
endtask


reg [63:0] mtick_cnt = 64'h0;
task automatic msleep (
	input [63:0] ms_delay,
	output done );
	reg [63:0] mtick_delay = ms_delay * OW_TICKS_MS;
	begin
		done = 0;
		if (mtick_cnt >= mtick_delay) begin
			mtick_cnt = 63'h0;
			done = 1'b1;			
		end
		else begin
			mtick_cnt = mtick_cnt + 1;		
			done = 0;
		end
	end
endtask

assign ow_data_out = ow_reg;
assign ow_en_out = ((fsm_state != `FSM_READ_BIT) && (fsm_state != `FSM_READ_RELEASE) && (fsm_state != `FSM_READ_WAIT)) ? 1'b1 : 1'b0;
assign ow_en_in  = ((fsm_state == `FSM_READ_BIT) || (fsm_state == `FSM_READ_RELEASE) || (fsm_state == `FSM_READ_WAIT)) ? 1'b1 : 1'b0;

reg [15:0] tepm_celsium = 16'h0;

always @(posedge temp_en)
begin
	//tepm_celsium[13:0] <= (temp_out[13:0] * 100) >> 7; //2234 => 22.34 C!!!
	//tepm_celsium[15] <= temp_out[13]; //sign
	tepm_celsium[15:0] <= temp_out[15:0];
end

assign temp_en = (com_state == `COM_IDLE);// ? 1'b1 : 1'b0;	
assign temp_data[15:0] = tepm_celsium;//(com_state == `COM_IDLE) ? temp_out[15:0] : 16'hFFFF;


endmodule

