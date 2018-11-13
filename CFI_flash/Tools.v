module ToolsLib(input C);

CatchFast U1(.D(),.Q(),.R());
CatchFastE U2(.D(),.En(),.Q(),.R());
CatchSyncPulse U3(.C(),.D(),.Q());
CatchSyncPulseE U4(.C(),.CE(),.D(),.En(),.Q());
PulCO U5(.C(),.D(),.Q(),.R());
PulFFA U6(.C(),.D(),.Q(),.R());
PulFFS U7(.C(),.D(),.Q(),.R());
FD16CE U8(.C(),.CE(),.D(),.Q());
SyncD #(16) U9(.CLKD(),.D(),.DV(),.CLKQ(),.Q(),.QV());
SyncD2 #(16) U10(.CLKD(),.D(),.DV(),.CLKQ(),.Q());
FDCEx #(16) U11(.C(),.CE(),.R(),.D(),.Q(),.DV(),.QV());

endmodule


//Tools for any applications
module CatchFast(D,Q,R);
	input D;
	output Q;
	input R;
	//Захват D и удержание до сброса R
	FDC UF(.C(D),.D(1'b1),.Q(Q),.CLR(R));

endmodule

module CatchFastE(D,En,Q,R);
	input D;
	input En;
	output Q;
	input R;
	//Захват D и удержание до сброса R
	//Расширенный набор сигналов (En)
	wire wEn=En&-1;
	FDCE UF(.C(D),.CE(wEn),.D(1'b1),.Q(Q),.CLR(R));

endmodule

module CatchSyncPulse(C,D,Q);
	input C;
	input D;
	output Q;
	//Захват D и формирование синхронного импульса

	CatchFast U1(.D(D),.Q(D1),.R(Q));
	FDR UF2 (.C(C),.D(D1),.Q(Q),.R(Q));

endmodule

module CatchSyncPulseE(C,CE,D,En,Q);
	input C;
	input CE;
	input En;
	input D;
	output Q;
	//Захват D и формирование синхронного импульса
	//Расширенный набор сигналов (En)

	wire wEn=En&-1;
	wire wCE=CE&-1;
	CatchFastE U1(.D(D),.En(wEn),.Q(D1),.R(Q));
	FDRE UF2 (.C(C),.CE(wCE),.D(D1),.Q(Q),.R(Q));

endmodule

module PulCO(C,D,Q,R);
	input C;
	input D;
	output Q;
	input R;
	//Формирователь импульса, 
	//соответствующего первому такту синхронного сигнала D 
	//с комбинационным выходом

	FDR UF (.C(C),.D(~D),.Q(D1),.R(R));
	assign Q=D&D1;

endmodule

module PulFFA(C,D,Q,R);
	input C;
	input D;
	output Q;
	input R;
	//Формирователь импульса с двумя триггерами с асинхронным сбросом
	//Не тестировалась

	FDC UF1 (.C(C),.D(D),.Q(Q),.CLR(R|D1));
	FDCE UF2 (.C(C),.CE(Q),.D(1'b1),.Q(D1),.CLR(~D));

endmodule

module PulFFS(C,D,Q,R);
	input C;
	input D;
	output Q;
	input R;
	//Формирователь импульса с двумя триггерами с синхронным сбросом

	FDR UF1 (.C(C),.D(D),.Q(Q),.R(D1|R));
	FDR UF2 (.C(C),.D(D),.Q(D1),.R());

endmodule

module FD16CE(C,CE,D,Q);
	parameter DWIDTH=16;
	input C;
	input CE;
	input [DWIDTH-1:0] D;
	output reg [DWIDTH-1:0] Q;
	
	always @(posedge C)
		if (CE)
			Q<=D;

endmodule


module SyncD(R,CLKD,D,DV,CLKQ,Q,QV,DBUSY,DD,QS);
	parameter DWIDTH=16;
	input R;
	//Вход, синхронизированный от CLKD
	input CLKD;
	input [DWIDTH-1:0] D;
	input DV;
	//Выход, синхронизированный от CLKQ
	input CLKQ;
	output [DWIDTH-1:0] Q;
	output QV;
	//Выход предварительных данных для наращивания 
	output DBUSY;//Данные DD захвачены по CLKD
	output [7:0] DD;//Предварительные данные
	output QS;//Данные DD синхронизированы по CLKQ
	//Засинхронизировать D относительно CLKQ

reg [DWIDTH-1:0] DA,Q1;
reg QS0,QS1;
reg QV1;
reg S=0;

wire RS=R|QS1;
always @(posedge CLKD or posedge RS)
	if (RS) S<=0;
	else if (DV) S<=1;

always @(posedge CLKD)
	if (R) DA<=0;
	else if (~S) DA<=D;

always @(negedge CLKQ)
begin
	if (R|QS0) QS0<=0;
	else QS0<=S;
	QV1<=QS0;
end

wire RQS1=R|~S;
always @(posedge CLKQ or posedge RQS1)
	if (RQS1) QS1<=0;
	else QS1<=QS0;

always @(posedge CLKQ)
	if (R) Q1<=0;
	else if (QS0) Q1<=DA;

assign Q=Q1;
assign QV=QV1;

assign DBUSY=S;
assign DD=DA;
assign QS=QS0;

endmodule

module SyncD2(R,CLKD,D,DV,CLKQ,Q,QV);
	parameter DWIDTH=16;
	input R;
	input CLKD;
	input [DWIDTH-1:0] D;
	input DV;
	input CLKQ;
	output [DWIDTH-1:0] Q;
	output QV;
	//Засинхронизировать D относительно CLKQ
	//2 переключающихся регистра для приема D
	wire [1:0] S,QS;
	wire [DWIDTH-1:0] DA [0:1];
	reg QV1;
	reg [DWIDTH-1:0] Q1;
	
SyncD #(DWIDTH) U0(.R(R),.CLKD(CLKD),.D(D),.DV(DV),.CLKQ(CLKQ),.DBUSY(S[0]),.DD(DA[0]),.QS(QS[0]));
SyncD #(DWIDTH) U1(.R(R),.CLKD(CLKD),.D(D),.DV(DV&S[0]),.CLKQ(CLKQ),.DBUSY(S[1]),.DD(DA[1]),.QS(QS[1]));
	
always @(posedge CLKQ)
	if (R) Q1<=0;else 
		if (QS[0]) Q1<=DA[0];else
			if (QS[1]) Q1<=DA[1];

assign Q=Q1;
assign QV=QV1;


endmodule

module FDCEx(C,CE,R,D,DV,Q,QV);
	parameter DWIDTH=16;
	input C;
	input CE;
	input R;
	input [DWIDTH-1:0] D;
	output reg [DWIDTH-1:0] Q;
	input DV;
	output reg QV;

always @(posedge C)
if (R)
begin
	Q<=0;
	QV<=0;
end
else
if (CE)
	begin
		Q<=D;
		QV<=DV;
	end

endmodule
