

module hawk_videoAddTemp (	
	input [15:0] temp_data, 
	// avalon stream interface
	input enable,
	input stream_clk,
	
	input stream_in_sop,
	input stream_in_valid,
	input [15:0] stream_in_data, 
	input stream_in_eop,
	
	output stream_out_sop,
	output stream_out_valid,
	output [15:0] stream_out_data,
	output stream_out_eop
	);


parameter SIZE_X = 640; //639
parameter SIZE_Y = 480; //479

reg valid = 0;
reg sof = 0;
reg eof = 0;
reg [15:0] data = 0;
wire valid_data;
reg r_valid_data = 0;

assign valid_data = stream_in_valid & !stream_in_sop;

always @(posedge stream_clk)
begin
	sof   <= stream_in_sop;
	valid <= stream_in_valid;
	r_valid_data <= valid_data;
	eof   <= stream_in_eop;
	data  <= stream_in_data;
end

wire puls;
wire [15:0] data_out;

assign puls = ((stream_in_valid & !stream_in_sop) && (~valid)) ? 1'b1 : 1'b0;
assign data_out = puls ? temp_data : (r_valid_data ? data : (16'h0));

assign stream_out_sop   = sof;
assign stream_out_valid = valid | valid_data;
assign stream_out_data  = data_out;
assign stream_out_eop   = eof;

//assign stream_sop_1   = stream_sop;
//assign stream_valid_1 = stream_valid;
//assign stream_data_1  = stream_data;
//assign stream_eop_1   = stream_eop;


//////////////////////////////////////////////////	

endmodule 