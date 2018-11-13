module custom_sdi_tx (
	input clk,
	input reset,
	input [9:0] tx_datain,
	input tx_datain_valid,
	output [9:0] tx_dataout,
	output tx_dataout_valid
	);

	reg [9:0] shift_reg [0:8];
	reg [9:0] single_reg = 10'h0;
	reg [9:0] valid_reg = 10'h0;
	reg [9:0] output_reg = 10'h0;
	wire [9:0] sum_shift, sum_single, sum_input;
	integer i;
	
	initial begin
		single_reg = 10'h0;
		valid_reg = 10'h0;
		output_reg = 10'h0;
		for (i = 0; i < 9; i = i + 1)
			shift_reg[i] <= 10'h0;
	end
	
	always @(posedge clk) begin
		if (reset) begin
			single_reg = 10'h0;
			valid_reg = 10'h0;
			output_reg <= 10'h0;
			for (i = 0; i < 9; i = i + 1)
				shift_reg[i] <= 10'h0;
		end
		else begin
			single_reg <= sum_shift;
			valid_reg[0] <= tx_datain_valid;
			shift_reg[0] <= sum_input;
			if (tx_dataout_valid)
				output_reg <= single_reg;
			for (i = 1; i < 9; i = i + 1)
				shift_reg[i] <= shift_reg[i-1];
			for (i = 1; i < 10; i = i + 1)
				valid_reg[i] <= valid_reg[i-1];
		end
	end
	
	//assign sum_input = (tx_datain_valid) ? tx_datain + sum_shift : sum_shift;
	assign sum_input = tx_datain + sum_shift;
	assign sum_shift = shift_reg[4] + shift_reg[8];
	assign sum_single = shift_reg[8] + single_reg;
	
	assign tx_dataout = (tx_dataout_valid) ? single_reg : output_reg;
	assign tx_dataout_valid = valid_reg[9];
	
endmodule

module custom_sdi_rx (
	input clk,
	input reset,
	input [9:0] rx_datain,
	input rx_datain_valid,
	output [9:0] rx_dataout,
	output rx_dataout_valid
	);

	reg [9:0] shift_reg [0:8];
	reg [9:0] single_reg = 10'h0;
	reg [9:0] valid_reg = 10'h0;
	reg [9:0] output_reg = 10'h0;
	wire [9:0] sum_shift, sum_single, sum_input;
	integer i;
	
	initial begin
		single_reg = 10'h0;
		valid_reg = 10'h0;
		output_reg = 10'h0;
		for (i = 0; i < 9; i = i + 1)
			shift_reg[i] <= 10'h0;
	end
	
	always @(posedge clk) begin
		if (reset) begin
			single_reg = 10'h0;
			valid_reg = 10'h0;
			output_reg <= 10'h0;
			for (i = 0; i < 9; i = i + 1)
				shift_reg[i] <= 10'h0;
		end
		else begin
			single_reg <= sum_shift;
			valid_reg[0] <= rx_datain_valid;
			shift_reg[0] <= sum_input;
			if (rx_dataout_valid)
				output_reg <= sum_shift + shift_reg[8];
			for (i = 1; i < 9; i = i + 1)
				shift_reg[i] <= shift_reg[i-1];
			for (i = 1; i < 10; i = i + 1)
				valid_reg[i] <= valid_reg[i-1];
		end
	end
	
	//assign sum_input = (rx_datain_valid) ? rx_datain + sum_shift : sum_shift;
	assign sum_input = rx_datain + sum_single;
	assign sum_shift = shift_reg[4] + sum_input;
	assign sum_single = rx_datain;
	
	assign rx_dataout = (rx_dataout_valid) ? single_reg : output_reg;
	assign rx_dataout_valid = valid_reg[9];
	
endmodule