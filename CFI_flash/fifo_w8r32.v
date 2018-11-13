//NAND->(w8)->FIFO->(r32)->SRAM
module fifo_w8r32(
	input Reset,
	input WCK,
	input WE,	
	input [10:0] WrA,	
	input [7:0] D,
	input RCK,
	output [31:0] Q,
	output QV,
	input TestFlag,
	input [9:0] TestAddr,
	output [15:0] TestData
);
localparam WrSz = 1280, //320x32bit
				RdSz = 320;

wire [8:0] RdA;
wire [31:0] Qwire;
wire LOCKED;		//разрешает запись строки коэффициентов 320х32 бит
wire WrEnd;
reg [8:0] RdPnt = 0;
wire WrEnPulse;			//одиночный синхронный импульс
wire RSET;
reg RdFull = 0;
//input test Addr/Data
wire [10:0] WrAddrTest;
wire [7:0] DTest;

assign LOCKED = (WrA <= WrSz) ? 1'b1 : 1'b0;
assign WrEnd = (WrA == WrSz);

assign RdA = RdPnt;

//формирует одиночный синхронный импульс WrEnPulse
CatchSyncPulseE U1W(.C(WCK),.CE(1'b1),.D(WE),.En(LOCKED),.Q(WrEnPulse));

CatchSyncPulse U1R(.C(RCK),.D(WrEnd),.Q(RSET));
CatchFast U2R(.D(RSET),.Q(QV),.R(RdFull)); 

always @(posedge RCK)
begin
	if (Reset||RSET) begin
		RdPnt <= 0;
		RdFull <= 0;
	end
	else
		if (RdPnt == RdSz + 1)
			RdFull <= 1'b1;
		else
			if (QV)
				RdPnt<=RdPnt+1;
end

RAMB16_S9_S36 UBRAM0(
	.CLKA(WCK),.ADDRA(WrA),.DIA(D[7:0]),.DIPA(2'b0),.WEA(WrEnPulse),.ENA(1'b1),
	.CLKB(RCK),.ADDRB(RdA),.DOB(Qwire[31:0]),.DIPB(4'b0),.DOPB(),.WEB(1'b0),.ENB(1'b1)
	);

assign {WrAddrTest[10:0], DTest[7:0]} = (TestFlag) ? {WrA[10:0],D[7:0]} : 19'h0;

RAMB16_S9_S18 TESTRAM0(
	.CLKA(WCK),.ADDRA(WrAddrTest),.DIA(DTest[7:0]),.DIPA(1'b0),.WEA(WrEnPulse),.ENA(1'b1),
	.CLKB(RCK),.ADDRB(TestAddr[9:0]),.DOB(TestData[15:0]),.DIPB(2'b0),.DOPB(),.WEB(1'b0),.ENB(1'b1)
	);

assign Q = (QV) ? Qwire : 32'hZZZZZZZZ;

endmodule

