//упрощенный вариант, записывает только полные страницы (page/row) по 2112 байт
module AddressDriver
	#(
	parameter ZeroColumnAddr = 17'h0,
	parameter ZeroRowAddr = 12'h0
	)
	(
	input CLK,
	input Reset,
	input [7:0] StatusReg,		
	input AckWr,
	input WrStart,		//запрос на запись данных во флэш
	output QV,			//перед приемом строба данных высылается точно такой же пустой строб, прием стробюа в модуле fifo_in
	input RdStart,		//запрос на чтение данных из флэша
	input AckRd,	
	output [39:0] BusAddr
    );

reg [16:0] row_cnt = 17'h0;
reg [11:0] column_cnt = 12'h0;

reg [9:0] cnt;
reg QVreg;

always @(posedge CLK)
begin
	if (Reset) begin
		QVreg <= 0;
		cnt <= 0;
	end
	else begin
		if (RdStart | AckRd) begin 
			QVreg <= 1'b1;
			cnt <= 0;
		end
		if (cnt == 320)
			QVreg <= 0;
		else
			if (QVreg)
				cnt <= cnt + 1;
	end
end		
	
always @(posedge CLK) 
begin
	if (Reset | RdStart | WrStart)	begin
		row_cnt <= ZeroColumnAddr;
		column_cnt = ZeroRowAddr;
	end 
	else begin
		if (AckWr | AckRd)
			row_cnt <= row_cnt + 1;
	end
end

assign BusAddr[39:0] = {7'h0, row_cnt[16:0], 4'h0, column_cnt[11:0]};
assign QV = QVreg;

endmodule
