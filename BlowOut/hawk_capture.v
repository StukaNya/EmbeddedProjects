
`timescale 1ns / 1ps
module hawk_capture (
// avalon slave interface	
	input slave_clk,
	input slave_rst_n,
	input slave_cs,
	input slave_wr_n,
	input [31:0] slave_wrdata,
	input [1:0] slave_address,
	output reg [31:0] slave_rddata,
// hawk sensor signals
	input hawk_clk,
	input hawk_FVAL,
	input hawk_LVAL,
	input [13:0] hawk_data, 
// avalon stream interface
	input stream_enable,
	input stream_clk,
	output stream_sop,
	output stream_valid,
	output [15:0] stream_data,
	output [15:0] stream_data1,
	output stream_eop
	);
	
parameter SIZEX_HAWK 		= 319;  //так как читаем по два пикселя 639
parameter SIZEY_HAWK 		= 15;  //512
parameter SIZEY_FPGA  		= 10;  //480
parameter START_FIFO_READ  = 115;  //480	

reg [9:0] cntLine = 0;
reg [9:0] cntPix = 0;
reg enReadFifo = 0;
reg readValidFifo = 0;
reg [9:0] cntReadFifo = 0;

reg enStreamH_sop = 0;
wire writeValidFifo;
wire [31:0] streamH_data;
reg rStreamH_valid = 0;
reg rStreamH_sop = 0;
reg rStreamH_eop = 0;

//начало стрима
always @(posedge hawk_clk)
if(cntLine <= 1)
begin
	if (cntPix == 1 || cntPix == 2)
		enStreamH_sop <= 1;
	else
		enStreamH_sop <= 0;		
end

always @(posedge stream_clk)	
	if (enStreamH_sop)
		rStreamH_sop <= 1;
	else
		rStreamH_sop <= 0;

//конец стрима
always @(posedge stream_clk)	
	if (cntReadFifo == SIZEX_HAWK)
		rStreamH_eop <= 1;
	else
		rStreamH_eop <= 0;
		
//счетчик строк с хока
always @(posedge hawk_LVAL)
	if (hawk_FVAL)
		cntLine <= cntLine + 1;
	//else
	//	cntLine <= 0;
		
//счетчик пикселей с хока
always @(posedge hawk_clk)
	//if (hawk_FVAL)
	begin
		if (!hawk_FVAL)
			cntLine <= 0;
		if (hawk_LVAL)
			cntPix <= cntPix + 1;
		else
			cntPix <= 0;
	end
	
//вырабатываем строб на чтение с фифо
always @(posedge hawk_clk)
	if (cntPix == START_FIFO_READ || cntPix == (START_FIFO_READ + 1))
		enReadFifo <= 1;
	else 
		enReadFifo <= 0;

always @(posedge stream_clk)
if(cntLine <= SIZEY_FPGA)
begin
	if (enReadFifo)
		readValidFifo <= 1;
	else
	if (cntReadFifo == SIZEX_HAWK)
		readValidFifo <= 0;
end
		
always @(posedge stream_clk)
	if (readValidFifo)
		cntReadFifo <= cntReadFifo + 1;
	else
		cntReadFifo <= 0;

//вырабатываем строб stream valid
always @(posedge stream_clk)
	rStreamH_valid <= readValidFifo;
	
assign writeValidFifo = (cntLine <= SIZEY_FPGA) ? hawk_LVAL : 1'b0;

fifoH_capture	fifoH_capture_inst (
	.data ( {2'b00, hawk_data} ), //data_sig
	.wrclk ( hawk_clk ), //wrclk_sig
	.wrreq ( writeValidFifo ),
	.rdclk ( stream_clk ),
	.rdreq ( readValidFifo ), //rdreq_sig	
	.q ( streamH_data ), //q_sig
	.rdempty (  ), //rdempty_sig
	.wrfull (  ) //wrfull_sig
	);	
	
//////////////////////////////////////////////////		
// output stream interface signals


assign stream_sop   = rStreamH_sop;//streamH_sop_ff;
assign stream_valid = rStreamH_valid;//streamH_valid_ff;
assign stream_data  = streamH_data[15:0];		//odd data		streamH_data_rg;
assign stream_data1  = streamH_data[31:16];	//even data
assign stream_eop   = (cntLine == SIZEY_FPGA) ? rStreamH_eop : 1'b0;//streamH_eop_ff;

//////////////////////////////////////////////////	

endmodule 