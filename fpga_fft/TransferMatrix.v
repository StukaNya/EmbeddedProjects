
module TransferMatrix(
		input Reset,
		input CLK,
		input CLKdiv2,
		input LVAL,
		input CE,
		input [255:0] D1_i,
		input [255:0] D2_i,
		//output [255:0] D1_o,
		output [511:0] D_o
	);
	
//[0:7]D_arr_i->D1_i, [8:15]D_arr_i->D2_i
wire [31:0] D_arr_i [0:15];
wire [31:0] D_arr_o [0:15];
reg [31:0] D_arr_delay [0:15];

genvar k;
generate
	for (k=0; k<16; k=k+1) begin: ram_gen

		always @(posedge CLK) begin
			if (Reset || !LVAL)
				D_arr_delay[k] <= 32'h0;
			else
				D_arr_delay[k] <= D_arr_i[k];
		end
		
		FpAdd	FpAdd_inst (
			.aclr (Reset),
			.clk_en (CE || !LVAL),
			.clock (CLKdiv2),
			.dataa (D_arr_i[k]),
			.datab (D_arr_delay[k]),
			.result (D_arr_o[k])
			);

	end
endgenerate

//RAM input bus assigment
assign D_o[255:0] = 
	{D_arr_o[0], D_arr_o[1], D_arr_o[2], D_arr_o[3], D_arr_o[4], D_arr_o[5], D_arr_o[6], D_arr_o[7],
		D_arr_o[8], D_arr_o[9], D_arr_o[10], D_arr_o[11], D_arr_o[12], D_arr_o[13], D_arr_o[14], D_arr_o[15]};
//RAM output bus assigment
assign {D_arr_i[0], D_arr_i[1], D_arr_i[2], D_arr_i[3], D_arr_i[4], D_arr_i[5], D_arr_i[6], D_arr_i[7]} = D1_i[255:0];
assign {D_arr_i[8], D_arr_i[9], D_arr_i[10], D_arr_i[11], D_arr_i[12], D_arr_i[13], D_arr_i[14], D_arr_i[15]} = D2_i[255:0];
		
endmodule
