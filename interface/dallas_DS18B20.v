module dallas_ds18b20 
	#(
	//6,25 ticks in 1us (6,25 MHz)
	parameter OW_TICKS_MS = 6250,
	parameter OW_SEC_DELAY = 1
	)
	(
	input 	ow_clk,
	input 	ow_reset,
	inout		ow_bidirec,
	output 	temp_en,
	output 	[15:0] temp_data
	);

localparam comm_size = 4;
localparam read_bytes_size = 8;

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


`define DS18B20_SEARCH_ROM			8'hF0
`define DS18B20_READ_ROM			8'h33
`define DS18B20_MATCH_ROM			8'h55
`define DS18B20_SKIP_ROM			8'hCC
`define DS18B20_ALARM_SEARCH		8'hEC

`define DS18B20_CONVERT_T			8'h44
`define DS18B20_READ_SCRATCHPAD	8'hBE
`define DS18B20_WRITE_SCRATCHPAD	8'h4E
`define DS18B20_COPY_SCRATCHPAD	8'h48
`define DS18B20_RECALL_EE			8'hB8
`define DS18B20_READ_PWR_SUPPLY	8'hB4

//1-wire bus
reg ow_reg;
//wire	ow_en_in, ow_en_out, ow_data_in, ow_data_out;
//io fsm regs	
wire wr_bit_done, rd_bit_done, reset_done, write_done, read_done;
reg usleep_done, msleep_done;
reg [4:0] byte_cnt;
reg [4:0] fsm_state = `FSM_IDLE;
reg [8:0] wrdata_reg;
reg [8:0] rddata_reg;
//command regs
reg [4:0] com_state = `COM_IDLE;
//ordered commands (8 bit)
reg [7:0] command_arr [0:comm_size-1];
//ordered data (9 bit )
reg [7:0] read_arr [0:read_bytes_size-1];
reg [comm_size-1:0] command_reg;
reg [comm_size-1:0] type_reg;
reg [3:0] cnt_com;
reg [3:0] read_bytes_cnt = 16'h0;
//temperature regs
reg [15:0] temp_read, count_per_c, count_remain;
reg [15:0] temp_round, temp_fraction, temp_out;
reg [15:0] temp_celsium;
integer i;

initial
begin
	//init io regs
	ow_reg = 1'b1;
	//init fsm_regs
	byte_cnt = 5'h0;
	wrdata_reg = 8'h0;//command_arr[0];
	rddata_reg = 8'h0;
	//init comm regs
	cnt_com = 4'h1;
	command_arr[0] = `DS18B20_SKIP_ROM;//`DS18B20_READ_ROM;
	command_arr[1] = `DS18B20_CONVERT_T;
	command_arr[2] = `DS18B20_SKIP_ROM;
	command_arr[3] = `DS18B20_READ_SCRATCHPAD;
	//Wr/Rd operations, Wr: 1, Rd: 0
	command_reg = 5'b0111;
	//ROM/Function commands, ROM: 1, Func: 0
	type_reg = 5'b0101;
	//read temp arr
	temp_read		= 16'd0;
	count_per_c		= 16'd0;
	count_remain	= 16'd0;
	temp_round		= 16'd0;
	temp_fraction	= 16'd0;
	temp_out			= 16'd0;
	temp_celsium 	= 16'h0;
	for (i = 0; i < read_bytes_size; i = i + 1)
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
				if (msleep_done) begin
					com_state <= `COM_WRITE_DO;
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
				read_bytes_cnt <= 0;
				msleep(1, msleep_done);
				if (msleep_done) begin
					if (type_reg[cnt_com] == 1'b1) begin
						com_state <= `COM_WRITE_DO;
						cnt_com <= cnt_com + 1;
					end
					else begin
						com_state <= (command_reg[cnt_com] == 1'b1) ? `COM_FINISH : `COM_READ_DO;
						read_bytes_cnt <= 4'h0;
					end
				end
			end
			`COM_READ_DO: begin
				com_state <= `COM_READ_WAIT;
			end
			`COM_READ_WAIT: begin
				if (read_done) begin
					com_state <= `COM_READ_DONE;
					read_arr[read_bytes_cnt] <= rddata_reg;
				end
			end
			`COM_READ_DONE: begin
				msleep(1, msleep_done);
				if (msleep_done) begin
					read_bytes_cnt <= read_bytes_cnt + 1;
					if (read_bytes_cnt == read_bytes_size - 1)
						com_state <= `COM_FINISH;
					else
						com_state <= `COM_READ_DO;
				end
			end
			`COM_FINISH: begin
				if (cnt_com == comm_size - 1) begin
					com_state <= `COM_IDLE;
					cnt_com <= 4'h0;
				end
				else begin
					cnt_com <= cnt_com + 1;
					com_state <= `COM_RESET_DO;
				end			
			end
		endcase


assign wr_bit_done = (byte_cnt == 5'h7) ? 1'b1 : 1'b0;
assign rd_bit_done = (byte_cnt == 5'h7) ? 1'b1 : 1'b0;//(cnt_com < 3'd2) ? (byte_cnt == 5'h7) : (byte_cnt == 5'h8);
assign reset_done = (fsm_state == `FSM_RESET_DONE) ? 1'b1 : 1'b0;
assign write_done = (fsm_state == `FSM_WRITE_DONE) ? 1'b1 : 1'b0;
assign read_done 	= (fsm_state == `FSM_READ_DONE) ? 1'b1 : 1'b0;

always @(posedge ow_clk)
	if (ow_reset) begin
		fsm_state <= `FSM_IDLE;
		byte_cnt = 5'h0;
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
				usleep(6, usleep_done); //8
				if (usleep_done)
					fsm_state <= `FSM_WRITE_BIT;
			end
			`FSM_WRITE_BIT: begin
				ow_reg <= wrdata_reg[byte_cnt];
				usleep(54, usleep_done); //42
				if (usleep_done)
					fsm_state <= `FSM_WRITE_RELEASE;
			end
			`FSM_WRITE_RELEASE: begin
				ow_reg <= 1'b1;
				usleep(10, usleep_done); //2
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
				usleep(6, usleep_done);
				if (usleep_done)
					fsm_state <= `FSM_READ_RELEASE;
			end
			`FSM_READ_RELEASE: begin
				ow_reg <= 1'b1;
				usleep(9, usleep_done);
				if (usleep_done) begin
					fsm_state <= `FSM_READ_BIT;
				end
			end
			`FSM_READ_BIT: begin
				fsm_state <= `FSM_READ_WAIT;
				rddata_reg[byte_cnt] <= ow_data_in;
			end
			`FSM_READ_WAIT: begin
				usleep(50, usleep_done);
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
/*
	temp_read[7:0] 	<= read_arr[1];
	count_remain[8:0]	<= read_arr[2];
	count_per_c[8:0]	<= read_arr[4];
	
	temp_round <= temp_read << 8;
	temp_fraction <= ((count_per_c - count_remain) << 8) / count_per_c;
	temp_out <= temp_round - 128 + temp_fraction;
	*/
	temp_out[7:0] <= read_arr[0];
	temp_out[15:8] <= read_arr[1];
end
		
		
reg [63:0] utick_cnt = 64'h0;
task automatic usleep (
	input [63:0] us_delay,
	output done );
	reg [63:0] utick_delay = (us_delay * OW_TICKS_MS) >> 10;
	begin
		done = 0;
		if (utick_cnt >= utick_delay) begin
			utick_cnt = 64'h0;
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
			mtick_cnt = 64'h0;
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

assign temp_en = (com_state == `COM_IDLE) ? 1'b1 : 1'b0;	
always @(posedge temp_en) temp_celsium <= temp_out;
assign temp_data[15:0] = temp_celsium;

bidirec_ds18b20 bidirec_inst (
	.clk(ow_clk),
	.en_in(ow_en_out),
	.data_in(ow_data_out),
	.en_out(ow_en_in),
	.data_out(ow_data_in),
	.bidir(ow_bidirec)
	);

endmodule

module bidirec_ds18b20 (
	input clk,
	input en_in,
	input data_in,
	input en_out,
	output data_out,
	inout bidir
	);

reg     reg_in;
reg     reg_out;

assign bidir = (en_in) ? reg_in : 1'bZ;
assign data_out  = reg_out;

always @ (posedge clk)
begin
	if (en_out)
		reg_out <= bidir;
	else
		reg_out <= 1'b1;
	
   reg_in <= data_in;
end

endmodule
