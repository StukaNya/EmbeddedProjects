
module TestHawk (
input CLK,
input CLKE,
input Reset,
output [13:0] AB_DATA,
output [13:0] AB_DATA2,
output LVAL,
output FVAL,
input ResM
);

parameter SIZEX=640-1;
parameter SIZEY=15; //512 480
parameter DELAY_LVAL=100;//483 484;
parameter DELAY_FVAL=20'h003;

reg LV=0;
reg FV=0;
reg EOL=0;
reg EOF=0;
//reg new_frame=1;
reg new_line=0;
reg [31:0] Q=1;
reg [31:0] Y=1;
wire [13:0] noise_data [0:5];

wire new_frame;
assign new_frame=ResM;

always @(posedge CLK)
begin
	if (Reset|EOL|EOF|new_frame|new_line)	
		Q<=1;
	else
		Q<=Q+1;
end		
	
always @(posedge CLK)
begin
	if (Reset|EOF)
		Y<=1;
	else
		if (EOL)
			Y<=Y+1;
end

always @(posedge CLK)
begin	
	if (Reset) 
	begin
		LV<=0;
		EOL<=0;
		new_line<=0;
	end
	else
		begin
			if (EOL)
				begin
					EOL<=0;
					LV<=0;
				end
			else
				if ((Q==SIZEX)&LV&FV)
					EOL<=1;
			if (new_line&FV)
				begin
					LV<=1;
					new_line<=0;
				end
			else
				//if (CLKE)
				if (((Q>=DELAY_LVAL)&(Y!=1)|(Q>=DELAY_FVAL)&(Y==1))&FV&~LV)
					new_line<=1;
		end
end

always @(posedge CLK)	
begin
	if (Reset) 
	begin
		FV<=0;
		EOF<=0;
//		new_frame<=1;
	end
	else
		begin
			if (EOF)
				begin
					EOF<=0;
					FV<=0;
				end
			else
				if ((Y==SIZEY+1)&FV)
					EOF<=1;
			if (new_frame)
				begin
				//	new_frame<=~new_frame;
					FV<=1;
				end
			//	else
			//		if ((Q==DELAY_FVAL)&~FV)
			//			new_frame<=~new_frame;
		end
end	

wire LV1;
//DFFE #(1) UDVMCLK2(.C(CLK),.CE(!CLKE),.D(LV),.Q(LV1)); //FDCE
//DFFE UDVMCLK2 (.d(LV),.clk(CLK),.ena(!CLKE),.q(LV1));//.clrn(<input_wire>), .prn(<input_wire>), 
reg rLV1 = 0 ;

always @(posedge CLK)	
begin
//	if (!CLKE)
		rLV1 <= LV;
end

assign LVAL=rLV1;//LV1 1;
assign FVAL=FV;

assign noise_data[0] = 10*Q + 14'd1300;
assign noise_data[1] = ((Q > 100) && (Q % (110 + Y*8) < 8) && (Y % 2 == 0)) ? (((Q > 100) && (Q % (110 + Y*8) < 4)) ? noise_data[0] + 14'd2400 : noise_data[0]) - 14'd1200 : noise_data[0];
assign noise_data[2] = ((Q > 100) && (Q % (140 + Y*8) < 8) && (Y % 2 == 0)) ? (((Q > 100) && (Q % (140 + Y*8) < 4)) ? noise_data[1] - 14'd2400 : noise_data[1]) + 14'd1200 : noise_data[1];
assign noise_data[3] = ((Q > 100) && (Q % (170 + Y*8) < 4) && (Y % 2 == 0)) ? noise_data[2] + 14'd1200 : noise_data[2];
assign noise_data[4] = ((Q > 100) && (Q % (200 + Y*8) < 4) && (Y % 2 == 0)) ? noise_data[3] - 14'd1200 : noise_data[3];
assign noise_data[5] = (Q % (37 + Y*5) == 0) && (Y % 2 == 0) ? noise_data[4] - 14'd1200 : noise_data[4];
//assign AB_DATA=24*Q;
assign AB_DATA = LVAL ? noise_data[4] : 14'b0;
//assign AB_DATA2=14'hFFFF-48*Q;
//assign StartFrame=new_frame;

endmodule
