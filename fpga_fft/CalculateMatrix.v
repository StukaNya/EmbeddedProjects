
module CalculateMatrix(
		input Reset,
		input CLK,
		input CE,
		input [31:0] data_i,
		input [1:0] nx,
		input [1:0] ny,
		//data from RAM
		input [255:0] D1_i,
		input [255:0] D2_i,
		//data to RAM
		output [255:0] D1_o,
		output [255:0] D2_o
	);

//float constant in hex
`define FP_COS_0					32'h3f000000		//+0.5						0	2	0	1
`define FP_COS_0N					32'hbf000000		//-0.5						0	1	0N	2N
`define FP_COS_1					32'h3e8a8bd4		//+0.27059805				0	1N	0N	2
`define FP_COS_2					32'h3f273d74		//+0.65328145				0	2N	0	1N
`define FP_COS_1N					32'hbe8a8bd4		//-0.27059805
`define FP_COS_2N					32'hbf273d74		//-0.65328145

//float data mem and bus
reg [31:0] cos_mem	[0:3] [0:3]; 	// cos[Pi/4*(n+0.5)*i]; mem[n][i]
wire [31:0] cos_fp_o [0:15];
wire [31:0] data_fp_o [0:15];
//wire [31:0] fifo_fp_o [0:15];
 
//[0:7]D_arr_i->D1_i, [8:15]D_arr_i->D2_i
wire [31:0] D_arr_i [0:15];
wire [31:0] D_arr_o [0:15];
reg [31:0] D_arr_delay [0:15];

initial 
begin
//Q(i)cos[pi/4*(n+0.5)*i]
//Q(i) = 1/2 if i=0; 1/sqrt(2) if i!=0
//1st idx - row (n), 2nd idx - column (i)
cos_mem[0][0] = `FP_COS_0;
cos_mem[1][0] = `FP_COS_0;
cos_mem[2][0] = `FP_COS_0;
cos_mem[3][0] = `FP_COS_0;

cos_mem[0][1] = `FP_COS_2;
cos_mem[1][1] = `FP_COS_1;
cos_mem[2][1] = `FP_COS_1N;
cos_mem[3][1] = `FP_COS_2N;

cos_mem[0][2] = `FP_COS_0;
cos_mem[1][2] = `FP_COS_0N;
cos_mem[2][2] = `FP_COS_0N;
cos_mem[3][2] = `FP_COS_0;

cos_mem[0][3] = `FP_COS_1;
cos_mem[1][3] = `FP_COS_2N;
cos_mem[2][3] = `FP_COS_2;
cos_mem[3][3] = `FP_COS_1N;

end

//for 1 DCT block (4x4 matrix, need 16 blocks), sum only 1 pixel (need sum of 16 pixels)
//16 convert, 16 add, 16 mult primitives
genvar k;
generate
	for (k=0; k<16; k=k+1) 
	begin: fast_dct
		
		//delay = 5 clk
		FpMult	FpMult_inst_cos (
			.aclr (Reset),
			.clk_en (CE),
			.clock (CLK),
			.dataa (cos_mem[nx][k%4]),
			.datab (cos_mem[ny][k/4]),
			.result (cos_fp_o[k][31:0])
			);
		
		//delay = 5 clk
		FpMult	FpMult_inst (
			.aclr (Reset),
			.clk_en (CE),
			.clock (CLK),
			.dataa (data_i[31:0]),
			.datab (cos_fp_o[k][31:0]), 
			.result (data_fp_o[k][31:0])
			);
/*			
		Fifo_w32r32	Fifo_w32r32_inst (
			.aclr (Reset),
			.clock (CLK),
			.data (data_fp_o[k]),
			.rdreq (1'b1),
			.wrreq (1'b1),
			.q (fifo_fp_o[k])
			);	
	*/
		
		//delay 7 clk
		FpAdd	FpAdd_inst (
			.aclr (Reset),
			.clk_en (CE),
			.clock (CLK),
			.dataa (data_fp_o[k][31:0]),
			.datab (D_arr_i[k][31:0]),
			.result (D_arr_o[k][31:0])
			);	

	end
endgenerate

//RAM input bus assigment
assign D1_o[255:0] = 
	{D_arr_o[0], D_arr_o[1], D_arr_o[2], D_arr_o[3], D_arr_o[4], D_arr_o[5], D_arr_o[6], D_arr_o[7]};
assign D2_o[255:0] = 
	{D_arr_o[8], D_arr_o[9], D_arr_o[10], D_arr_o[11], D_arr_o[12], D_arr_o[13], D_arr_o[14], D_arr_o[15]};
//RAM output bus assigment
assign {D_arr_i[0], D_arr_i[1], D_arr_i[2], D_arr_i[3], D_arr_i[4], D_arr_i[5], D_arr_i[6], D_arr_i[7]} = D1_i[255:0];
assign {D_arr_i[8], D_arr_i[9], D_arr_i[10], D_arr_i[11], D_arr_i[12], D_arr_i[13], D_arr_i[14], D_arr_i[15]} = D2_i[255:0];

endmodule
