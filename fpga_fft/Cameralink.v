module Cameralink (
input CLK,
input Reset,
output [15:0] AB_DATA,
output LVAL,
output FVAL,
output [31:0] x_cnt,
output [31:0] y_cnt
);

parameter SIZEX=640-1;
parameter SIZEY=512-1;
parameter DELAY_LVAL=10;
parameter DELAY_FVAL=50;

reg LV=0;
reg FV=0;
reg EOL=0;
reg EOF=0;
reg new_frame=1;
reg new_line=0;
reg [31:0] Q=1;
reg [31:0] Y=1;

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
				if (((Q==DELAY_LVAL)&(Y!=1)|(Q==DELAY_FVAL)&(Y==1))&FV&~LV)
					new_line<=1;
		end
end

always @(posedge CLK)	
begin
	if (Reset) 
	begin
		FV<=0;
		EOF<=0;
		new_frame<=1;
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
					new_frame<=~new_frame;
					FV<=1;
				end
				else
					if ((Q==DELAY_FVAL)&~FV)
						new_frame<=~new_frame;
		end
end	

assign LVAL=LV;
assign FVAL=FV;

assign x_cnt = Y - 1;
assign y_cnt = Q - 1;

assign AB_DATA = Q + Y - 1;

endmodule
