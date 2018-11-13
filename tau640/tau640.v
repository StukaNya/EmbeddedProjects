 //Cb = U, Cr = V
//input - bt.656 	(U Y V Y), 27MHz
//output - YUV422 	(Y V Y U), 24MHz
module tau640 (
	//X1 (Bt.656 from Tau640)
	input 			raw_in_vclk,
	input 			raw_in_scl,
	input 			raw_in_sda,
	input [7:0] 	raw_in_data,
	//XS1 (Bt.656 to display)
	output 			raw_out_vclk,
	output 			raw_out_scl,
	output 			raw_out_sda,
	output [7:0] 	raw_out_data,
	//XS2 (YVYU to Banana-pi)
	output 			yuv_out_vclk,
	output			yuv_out_pclk,
	output			yuv_out_cam_pwdn,
	output 			yuv_out_scl,
	output 			yuv_out_sda,
	output 			yuv_out_vsync,
	output 			yuv_out_href,	
	output [9:0] 	yuv_out_data
	);

wire [7:0] bt_data;
wire bt_h_sync, bt_v_sync, field, reset, ce;

assign reset = 1'b0;
assign ce = 1'b1;
	
colorbars bt656 (
    .clk(raw_in_vclk),
    .rst(reset),
    .ce(ce),
    .q(bt_data),
    .h_sync(bt_h_sync),
    .v_sync(bt_v_sync),
    .field(field)
);

bt640_capture capture_inst (
	.raw_in_vclk(raw_in_vclk),
	.raw_in_scl(1'b0),
	.raw_in_sda(1'b0),
	.raw_in_data(bt_data),
	.yuv_out_vclk(yuv_out_vclk),
	.yuv_out_pclk(yuv_out_pclk),
	.yuv_out_cam_pwdn(yuv_out_cam_pwdn),
	.yuv_out_scl(yuv_out_scl),
	.yuv_out_sda(yuv_out_sda),
	.yuv_out_vsync(yuv_v_sync),
	.yuv_out_href(yuv_h_ref),	
	.yuv_out_data(yuv_data)
);

//output bus
assign raw_out_vclk 	= raw_in_vclk;
assign raw_out_scl 	= raw_in_scl;
assign raw_out_sda 	= raw_in_sda;
assign raw_out_data	= raw_in_data;

endmodule
