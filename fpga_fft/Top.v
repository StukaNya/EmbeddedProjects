
module Top(
input CLK,
input CLKdiv4,
input CLKdiv2,
input CE,
input Reset,
output [511:0] data_o
);
 //delay of MULT_FP = 5 clk
localparam delay_mult = 5,
//delay of ADD_FP
				delay_add = 7,
//delay of CONVERT_FP
				delay_convert = 6,
//delay of read from RAM
				delay_ram = 2;
				
// convert & cos_mult work in parallel
localparam	delay_all = 2*delay_mult + delay_add - 1;
				
localparam SIZEX = 640,
			SIZEY = 512;

//init RAM
reg is_init_ram = 1;
wire [255:0] init_data;
wire init_busy_sig, init_wr;
wire [10:0] ram_address_sig;
//RAM addr, wr_en
reg [11:0] delay_addr_r, wr_addr_r, rd_addr_r;
wire [10:0] wr_addr, rd_addr;
wire wr_en_w;
wire wr_en;
//input int16 data
wire [31:0] x_cnt, y_cnt;
wire LVAL, FVAL;
reg [1:0] nx;
reg [1:0] ny_r [0:3];
wire [15:0] adc_data_o, data_int_i;
//convert int16->float
wire [31:0] data_fp_a;
//two 256bit bus for DCT data
wire [255:0] data1_i [0:3], data1_o [0:3], data2_i [0:3], data2_o [0:3], 
	D1_i [0:3], D2_i [0:3], D1_o [0:3], D2_o [0:3];
	

//register value of genvar ny;
initial 
begin
	ny_r[0] = 2'b00;
	ny_r[1] = 2'b01;
	ny_r[2] = 2'b10;
	ny_r[3] = 2'b11;
end

//x -> y, sizex ->  sizey, ...
Cameralink i0 (
	.CLK(CLKdiv4),
	.Reset(init_busy_sig || Reset),
	.AB_DATA(adc_data_o),
	.FVAL(FVAL),
	.LVAL(LVAL), 
	.x_cnt(x_cnt),
	.y_cnt(y_cnt)
);

assign data_int_i = (is_init_ram || !LVAL) ? 16'h0 : adc_data_o;

RamInit	RamInit_inst (
	.clock (CLK),
	.init (is_init_ram || Reset),
	.dataout (init_data),
	.init_busy (init_busy_sig),
	.ram_address (ram_address_sig),
	.ram_wren (init_wr)
	);
	
Int16ToFloat	Int16ToFloat_inst (
	.aclr (Reset),
	.clk_en (CE),
	.clock (CLK),
	.dataa (data_int_i),
	.result (data_fp_a)
	);

genvar ny;
generate 
	for (ny=0; ny<4; ny=ny+1)
	begin: place_pix

		CalculateMatrix CalculateMatrix_inst(
			.Reset(Reset),
			.CLK(CLK),
			.CE(CE),
			.data_i(data_fp_a),
			.nx(nx[1:0] - delay_mult % 4),
			.ny(ny_r[ny]),
			.D1_i(D1_i[ny]),
			.D2_i(D2_i[ny]),
			.D1_o(D1_o[ny]),
			.D2_o(D2_o[ny])
			);
			
	//2 RAM by 1024x256bit, need optimize
		Ram2	Ram2_inst1 (
			.clock (CLK),  
			.data (data1_i[ny]),
			.rdaddress (rd_addr),
			.wraddress (wr_addr),
			.wren (wr_en),
			.q (data1_o[ny])
			);	
			
		Ram2	Ram2_inst2 (
			.clock (CLK),  
			.data (data2_i[ny]),
			.rdaddress (rd_addr),
			.wraddress (wr_addr),
			.wren (wr_en),
			.q (data2_o[ny])
			);	
			
		TransferMatrix TransferMatrix_inst(
			.Reset(Reset),
			.CLK(CLK),
			.CLKdiv2(CLKdiv2),
			.LVAL(LVAL),
			.CE(CE),
			.D1_i(D1_i[ny]),
			.D2_i(D2_i[ny]),
			.D_o(data_o[ny])
			);

		end
endgenerate

always @(posedge CLK) begin
	if (is_init_ram)
		is_init_ram <= 0;
		
	if (!CE || Reset || init_busy_sig) begin
		nx <= 0;
		delay_addr_r <= 12'h0;
		wr_addr_r <= 12'h0;
		rd_addr_r <= 12'h0;
	end
	else 
		if (LVAL) begin 		
			nx <= nx + 1;
			// delay/4 = y_cnt[delay]-y_cnt[0], delay%4 = nx[delay]-nx[0]
			// also wr_addr hold for 1 clk, rd_addr for 2
			// y_cnt*2 + y_cnt%2 separate odd and even sum in RAM
			delay_addr_r <= (y_cnt%2) + 2*(y_cnt - nx - (delay_all / 4) + (delay_all % 4));
			wr_addr_r <= delay_addr_r;
			rd_addr_r <= wr_addr_r;
		end
		else begin
			if (rd_addr_r) begin
				rd_addr_r <= 12'h0;
			end
			else
				rd_addr_r <= rd_addr_r + 1;
		end
end


assign {data1_i[0],data1_i[1],data1_i[2],data1_i[3]} = init_busy_sig ? {4{init_data[255:0]}} : 
	{D1_o[0],D1_o[1],D1_o[2],D1_o[3]};
assign {data2_i[0],data2_i[1],data2_i[2],data2_i[3]} = init_busy_sig ? {4{init_data[255:0]}} :
	{D2_o[0],D2_o[1],D2_o[2],D2_o[3]};
assign {D1_i[0],D1_i[1],D1_i[2],D1_i[3]} = {data1_o[0],data1_o[1],data1_o[2],data1_o[3]};
assign {D2_i[0],D2_i[1],D2_i[2],D2_i[3]} = {data1_o[0],data1_o[1],data1_o[2],data1_o[3]};

//wr_addr = 0, -1, -2, -3, 1, 0, -1, -2, 2, ... rd_addr has delay
//assign wr_addr[9:0] = (init_busy_sig) ? ram_address_sig[9:0] : wr_addr_r[9:0];
//assign rd_addr[9:0] = (init_busy_sig) ? 10'h0 : rd_addr_r[9:0] - delay_ram;

assign wr_addr[10:0] = (init_busy_sig) ? ram_address_sig[10:0] : wr_addr_r[10:0];
assign rd_addr[10:0] = (init_busy_sig) ? 11'h0 : rd_addr_r[10:0];

assign wr_en_w = (wr_addr_r > 11'h7FFF ) ? 1'b0 : 1'b1;
assign wr_en = (is_init_ram || init_busy_sig) ? init_wr : wr_en_w;

endmodule
