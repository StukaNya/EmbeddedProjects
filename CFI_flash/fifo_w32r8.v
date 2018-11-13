//SRAM->(w32)->FIFO->(r8)->NAND
module fifo_w32r8(
	input Reset,
	input WCK,
	input [10:0] RdA,		
	output [7:0] Q,
	input RCK,
	input RE,
	input [31:0] D,
	input DV,
	output DO_PROG,			//генерирует сингал начала записи во флэш
	input TestFlag				//заменяет внешние данные тестовым сигналом
);

localparam RdSz = 1280, //320x32bit
				WrSz = 320;

wire [8:0] WrA;
reg [8:0] WrPnt = 0;
wire [7:0] Qout;
wire WSET;
wire RSET;
reg WrFull = 0;
reg WrEn = 0;

CatchSyncPulse U1W(.C(WCK),.D(DV),.Q(WSET));

always @(posedge WCK)
begin
	if (Reset||WSET) begin
		WrPnt <= 0;
		WrFull <= 0;
		WrEn <= 1'b1;
	end
	else
		if (WrPnt == WrSz) begin
			WrFull <= 1'b1;
			WrEn <= 0;
		end
		else
			if (DV)
				WrPnt<=WrPnt+1;
end

assign WrA = WrPnt;

CatchSyncPulse U2W(.C(RCK),.D(WrFull),.Q(DO_PROG)); 

RAMB16_S9_S36 UBRAM0(
	.CLKA(RCK),.ADDRA(RdA),.DIA(8'h0),.DOA(Qout[7:0]),.DIPA(4'b0),.DOPA(),.WEA(1'b0),.ENA(1'b1),
	.CLKB(WCK),.ADDRB(WrA),.DIB(D[31:0]),.DIPB(2'b0),.WEB(WrEn),.ENB(1'b1)
	);

assign Q[7:0] = (TestFlag) ? (RdA[7:0]+1) : Qout[7:0];

endmodule
