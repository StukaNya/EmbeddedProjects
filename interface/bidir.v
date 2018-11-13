module bidirec (
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
