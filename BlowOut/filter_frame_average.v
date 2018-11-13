`timescale 1ns / 1ps
module FrameAverage #(
	parameter DATA_WIDTH = 16,
	parameter PRECISION = 8
	)
	(
	input clk,
	input reset,
	input en,
	input new_valid,
	input [DATA_WIDTH-1:0] new_pix,
	input [DATA_WIDTH-1:0] old_pix,
	output [DATA_WIDTH-1:0] cor_pix,
	output cor_valid
	);

// filter params
localparam bordLow = 20,												//верхняя граница
				bordHight = 50,											//нижняя граница
				kLow =  {1'b1, {PRECISION-1{1'b1}} } / 100,		//0.01, коэф. сглаживания для нижней границы
				kHight = {1'b1, {PRECISION-1{1'b1}} } * 3/4;		//0.75, коэф. сглаживания для верхней границы


reg valid_r;
wire [DATA_WIDTH-1:0] delta, upd_pix;
reg [DATA_WIDTH-1:0] cor_pix_r;
wire [PRECISION-1:0] kCorr;
reg [DATA_WIDTH+PRECISION-1:0] kTemp, kTemp2; 


assign delta = new_pix > old_pix ? new_pix - old_pix : old_pix - new_pix;

always @(delta) begin
		kTemp = (delta - bordLow) * (kHight - kLow);
		kTemp2 = kTemp / (bordHight - bordLow) + kLow;
end

assign kCorr = (delta < bordLow) ? kLow : (delta > bordHight) ? kHight : kTemp2[PRECISION-1:0];	

assign upd_pix = (new_pix > old_pix) ? old_pix + (kCorr * (new_pix - old_pix) >> PRECISION) : 
													old_pix - (kCorr * (old_pix - new_pix) >> PRECISION);

always @(posedge clk) begin
	valid_r <= new_valid;
	if (en) 
		cor_pix_r <= upd_pix;
	else
		cor_pix_r <= new_pix;
end


assign cor_valid = valid_r;
assign cor_pix = cor_valid ? cor_pix_r : {DATA_WIDTH{1'b0}};
	
endmodule
