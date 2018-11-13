`include "def.h"
`include "data.h"
 
`timescale 1ns/1ps
 
  /*
 ??????? ?????????? ??????:
 cfi_ctrl_engine.v ?????? 198
 ????????? ?????????:
 cfi_ctrl_engine.v ?????? 547
 ------------------
 ??????????? ??????:
 0 - ?????? ???????
 1 - ???????? ??????
 2 - ???????? ????
 3 - ????????????? ????
 4 - ?????? 2-? ????????? ?????
 5 - ?????? 2-? ????????? ?????
 6 - ?????? id ??????
 7 - cfi ?????? (cfi query) 
 */
 
module cfi_ctrl_engine_bench();
 
 
  // Signal Bus
  wire [8 - 1:0] DQ;        // Data I/0 Bus
  // Control Signal
  wire WE_N;                            // Write Enable 
  wire RE_N;                            // Read Enable
  wire CE_N;                            // Chip Enable
  wire CLE;                            // Command Latch Enable
  wire WP_N;                           // Write Protect
  wire ALE;                            // Address Latch Enable
  reg RB_N;
  
  reg reg_inout;
  // Voltage signal rappresentad by integer Vector which correspond to millivolts
  wire [`Voltage_range] VCC;  // Supply Voltage
  wire [`Voltage_range] VCCQ; // Supply Voltage for I/O Buffers
  wire [`Voltage_range] VPP; // Optional Supply Voltage for Fast Program & Erase  
 
  //wire STS;
 
  wire Info;      // Activate/Deactivate info device operation
assign Info = 1;
assign VCC = 36'd1700;
assign VCCQ = 36'd1700;
assign VPP = 36'd2000;
 
parameter sys_clk_half_period = 15;
parameter sys_clk_period = sys_clk_half_period*2;
parameter data_period = 60 * 322;
   reg sys_clk;
   reg sys_rst;
	reg clk_ext = 0;
	
initial begin
   sys_clk  = 0;
   forever 
      #sys_clk_half_period sys_clk  = ~sys_clk;
end

always #30 clk_ext <= ~clk_ext;

initial begin
   sys_rst  = 1;
   #sys_clk_period;
   #sys_clk_period;
   sys_rst  = 0;
end
 

   reg [31:0] bus_dat_i;
   wire [31:0] bus_dat_o;
	reg bus_strobe_i;
	wire bus_strobe_o;
   wire       bus_ack_o;
   reg        Wr,Rd,CS;
	wire [15:0] CtrlData;
	reg [15:0] CtrlDataReg;
	reg [7:0] CtrlAddr;
	reg bus_do_read_i;
	
assign	CtrlData = (Wr) ? CtrlDataReg : 16'h0000;
assign DQ = (!reg_inout) ? 8'hEA : 8'hZZ;
	
initial begin
   Wr = 0;
	Rd = 0;
	CS = 1;
	RB_N = 1;
	reg_inout = 1;
	bus_do_read_i = 0;


   bus_dat_i = 32'hABCDEF12;
	bus_strobe_i = 1'b1;
	#data_period;
	bus_strobe_i = 0;
	#(464505-19140-60)
	RB_N = 0;
	#500
	RB_N = 1;
	#500
	reg_inout = 0;
	#150
	reg_inout = 1;
	#30000
	//end prog
	
	CtrlAddr = 8'h02;
	CtrlDataReg = 16'hBABE;
	Wr = 1;
	#sys_clk_period;
   #sys_clk_period;
	Wr = 0;
	#(1290+380)
	reg_inout = 0;
   $display("Finishing CFI engine test");
  // $finish;
end
 
/* timeout function - sim shouldn't run much longer than this */

initial begin
   #55000;
   $display("Simulation finish due to timeout");
  // $finish;
end

 
 
cfi_ctrl_engine 
/*# (.cfi_part_elov_cycles(10))*/
dut
   (
    .clk(sys_clk), 
    .rst(sys_rst),
	 .clk_ext(clk_ext),
		
    .bus_dat_o(bus_dat_o),
    .bus_dat_i(bus_dat_i),
    .bus_strobe_i(bus_strobe_i),
	 .bus_strobe_o(bus_strobe_o),
	 .bus_ack_done_o(bus_ack_done_o),
	 .bus_do_read_i(bus_do_read_i),
	 
    .flash_dq_io(DQ),
    .flash_ce_n_o(CE_N),
    .flash_cle_o(CLE),
	 .flash_ale_o(ALE),
	 .flash_re_n_o(RE_N),
    .flash_we_n_o(WE_N),
    .flash_wp_n_o(WP_N),
	 .flash_rb_n_i(RB_N),
	 
	 .CS(CS),
	 .Wr(Wr),
	 .Rd(Rd),
	 .CtrlData(CtrlData),
	 .CtrlAddr(CtrlAddr)
    );
 

   
endmodule
