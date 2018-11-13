
 module cfi_ctrl_engine
	#(
	parameter fifo_dq_width = 32,				//ширина шины SRAM
   parameter flash_dq_width = 8,				//ширина шины NAND
	parameter fifo_size = 2112					//количество записанных байт за 1 команду записи do_program
	)
  (
   input clk, 			//внутренний clk для общения с флэш и работы автоматов
	input rst,			//reset для модуля (не для флэшки!)
	input clk_ext, 	//внешний clk, используется для передачи данных на SRAM

	output [fifo_dq_width-1:0] bus_dat_o,		//данные NAND->SRAM 32бит
	output bus_strobe_o,								//строб данных
	input [fifo_dq_width-1:0] bus_dat_i,		//SRAM->NAND 32бит
	input bus_strobe_i,
	output bus_ack_done_o,							//сигнал завершения операции
	input bus_do_write_i,							//запрос на запись во флэш 320 строк по 32бит
	input bus_do_read_i,								//запрос на чтение 320х32бит
	
	//NAND
   inout [flash_dq_width-1:0] flash_dq_io, 
   output flash_ale_o,
   output flash_ce_n_o,
   output flash_cle_o,
	output flash_re_n_o,
   output flash_we_n_o,
   output flash_wp_n_o,
	input flash_rb_n_i,
	
	//командный интерфейс
	input CS,
	input Wr,
	input Rd,
	inout [15:0] CtrlData,
	input [7:0] CtrlAddr
   );
	
	
localparam [2:0]
	st_idle = 3'b000,
	st_req_id = 3'b001,
	st_read_adr = 3'b010,
	st_read_dat = 3'b011,
	st_req_status = 3'b100,
	st_program_adr = 3'b101,
	st_program_dat = 3'b110,
	st_erase = 3'b111;  

	 
`define CFI_PHY_FSM_IDLE        0
`define CFI_PHY_FSM_WRITE_GO    1
`define CFI_PHY_FSM_WRITE_WAIT  2
`define CFI_PHY_FSM_WRITE_DONE  3
`define CFI_PHY_FSM_READ_GO     4
`define CFI_PHY_FSM_READ_WAIT   5
`define CFI_PHY_FSM_READ_DONE   6
`define CFI_PHY_FSM_RESET_GO    7
`define CFI_PHY_FSM_RESET_WAIT  8
`define CFI_PHY_FSM_RESET_DONE  9
 
   /* Defines according to CFI spec */
	//1C/2C = First/Second cycle
`define READ_STATUS_REG      	8'h70
`define READ_ID_REG	      	8'h90
`define RESET			      	8'hFF
`define BLOCK_ERASE_1C       	8'h60
`define BLOCK_ERASE_2C       	8'hD0
`define READ_ARRAY_1C        	8'h00
`define READ_ARRAY_2C        	8'h30
`define PAGE_PROGRAM_1C       8'h80
`define PAGE_PROGRAM_2C       8'h10
//copy
`define READ_COPY_BACK_1C    	8'h00
`define READ_COPY_BACK_2C    	8'h35
`define COPY_BACK_PROGRAM_1C  8'h85
`define COPY_BACK_PROGRAM_2C  8'h10

   /* Main bus-controlled FSM states */
`define FSM_IDLE                   0
`define FSM_DO_WRITE               1
`define FSM_DO_WRITE_WAIT          2
`define FSM_DO_READ                3
`define FSM_DO_READ_WAIT           4
`define FSM_DO_RESET               6
`define FSM_DO_RESET_WAIT          7
`define FSM_DO_BUS_ACK				  8
 
 reg [9:0] read_test_addr = 10'h0;		//читает 2 байта из тестового столбца (row)
 wire [15:0] read_test_data;		//
 
 wire [7:0] fifo_dat_i;			//data: fifo->nand
 reg	[7:0]	fifo_dat_o;			//data: nand->fifo
 
 reg [16:0] prog_test_addr = 17'h0;		//записывает тестовый столбец (row) по этому адрессу

 wire [39:0] fifo_addr_cnt;		//счетчик адресса, записывающий подряд 640 строк по 320х32 бит

 wire [10:0] WrA;						//счетчик для записи данных в FIFO
 wire [10:0] RdA;						//счетчик для чтения данных из FIFO
 
 wire [39:0] bus_addr_i;			
 wire [7:0] wr_addr [0:4];			
 reg [15:0] fsm_cnt = 16'd0;
 
 reg [7:0] reg_id [0:3];			//содержит id
 reg [7:0] status_reg;				//буффер для хранения статусного регистра
  
 //commands
 wire do_program_test,
		do_program_fifo,
		program_test_flag,
		do_read_test,
		do_read_fifo,
		read_test_flag,
		erase_test_flag;
 wire do_readstatus,
		do_eraseblock,
		do_program,
		do_erase,
		do_read,
		do_req_id,
		do_reset;
	
	//соединение двух выходящих стробов для корректной работы
	wire bus_strobe_addr, bus_strobe_fifo;			
	assign bus_strobe_o = bus_strobe_fifo | bus_strobe_addr;
	
	//сигнализирует об окончании одной итерации записи/чтения
	wire flash_bus_ack_wr, flash_bus_ack_rd;
   
	reg [7:0] 			bus_control_state = 8'h0;
		reg [flash_dq_width-1:0] flash_cmd_to_write;
	/* regs for flash bus control signals */
	reg flash_cle_r;
	reg flash_ale_r;
   reg flash_re_n_r;
   reg flash_we_n_r;
   reg flash_wp_n_r;
   reg [flash_dq_width-1:0]  flash_dq_o_r;
 
	reg [3:0]		command_state = 4'h0;
   reg [3:0] 		flash_phy_state = 4'h0;
   reg [3:0] 		flash_phy_ctr = 4'h0;
   wire 		      flash_phy_async_wait;
  

	AddressDriver #(17'h0,12'h0) ADDRDRV (
		.CLK(clk),
		.Reset(rst),
		.StatusReg(status_reg),
		.AckWr(flash_bus_ack_wr),
		.WrStart(bus_do_write_i),
		.QV(bus_strobe_addr),
		.AckRd(flash_bus_ack_rd),
		.RdStart(bus_do_read_i),
		.BusAddr(fifo_addr_cnt)
    );
	
	assign bus_addr_i = (program_test_flag || read_test_flag || erase_test_flag) ? {7'h0, prog_test_addr, 16'h0} : fifo_addr_cnt;
	
	assign wr_addr[0] = bus_addr_i[7:0];				//column 1
	assign wr_addr[1] = bus_addr_i[15:8];				//column 2
	assign wr_addr[2] = bus_addr_i[23:16];				//row 1
	assign wr_addr[3] = bus_addr_i[31:24];				//row 2
	assign wr_addr[4] = bus_addr_i[39:32];				//row 3
	
	//main fsm
 always @(posedge clk) begin
 if (rst) begin
   flash_ale_r <= 1'b0;
   flash_cle_r <= 1'b0;
 end
 else
	case (bus_control_state)
		`FSM_IDLE : begin
			if (do_readstatus) begin
				flash_cmd_to_write <= `READ_STATUS_REG;
				flash_cle_r <= 1'b1;
				bus_control_state <= `FSM_DO_WRITE;
				command_state <= st_req_status;
			end
			if (do_program) begin
				flash_cle_r <= 1'b1;
				flash_cmd_to_write <= `PAGE_PROGRAM_1C;
				bus_control_state <= `FSM_DO_WRITE;
				command_state <= st_program_adr; 				
			end
			if (do_read) begin
				flash_cle_r <= 1'b1;
				flash_cmd_to_write <= `READ_ARRAY_1C;
				bus_control_state <= `FSM_DO_WRITE;
				command_state <= st_read_adr;
			end
			if (do_erase) begin
				flash_cle_r <= 1'b1;
				flash_cmd_to_write <= `BLOCK_ERASE_1C;
				bus_control_state <= `FSM_DO_WRITE;
				command_state <= st_erase;
			end
			if (do_req_id) begin
				flash_cle_r <= 1'b1;
				flash_cmd_to_write <= `READ_ID_REG;
				bus_control_state <= `FSM_DO_WRITE;
				command_state <= st_req_id;
			end
			if (do_reset)
				bus_control_state <= `FSM_DO_RESET;
			//add copy back option!
		end
		`FSM_DO_WRITE : begin
		bus_control_state <= `FSM_DO_WRITE_WAIT;
		end
		`FSM_DO_WRITE_WAIT : begin
		//write option
			case (command_state)
				st_req_status : begin
					if (flash_bus_ack_wr) begin
						flash_cle_r <= 0;
						flash_cmd_to_write <= 8'h0;
						bus_control_state <= `FSM_DO_READ;
					end
				end
				st_program_adr : begin
					if (flash_bus_ack_wr) begin
						if (fsm_cnt < 5) begin		//запись адреса
							{flash_cle_r, flash_ale_r} <= 2'b01;
							flash_cmd_to_write <= wr_addr[fsm_cnt];
							fsm_cnt <= fsm_cnt + 1;
							bus_control_state <= `FSM_DO_WRITE;
						end 
						else begin												//переход к записи данных
							flash_ale_r <= 1'b0;
							fsm_cnt <= 0;
							bus_control_state <= `FSM_DO_WRITE;
							command_state <= st_program_dat;
							flash_cmd_to_write <= fifo_dat_i; 		
						end	
					end
				end
				//для чтения и стирания блоков выполняется аналогично
				st_program_dat : begin
					if (fsm_cnt != fifo_size + 1) begin 			//выполняется это ветвление, пока не запишется 5 циклов записи адресса и 1 цикл записи команды
						if (flash_bus_ack_wr) begin					//ждем до завершения предыдущей записи
							flash_cmd_to_write <= (fsm_cnt != fifo_size) ? fifo_dat_i : `PAGE_PROGRAM_2C;
							flash_cle_r <= (fsm_cnt != fifo_size) ? 1'b0 : 1'b1;
							fsm_cnt <= fsm_cnt + 1;
							bus_control_state <= `FSM_DO_WRITE;
						end
					end 
					else begin		//ветвление для ожидания подтверждения записи (низкий уровень сигнала ready/busy)
						//ждем, пока сигнал r/b не станет равным 0
						if (flash_cle_r && !flash_rb_n_i) begin
								flash_cle_r <= 0; 
						end
						//ждем ~200us, пока не завершится операция записи (r/b станет равным 1)
						if (!flash_cle_r && flash_rb_n_i) begin 
							fsm_cnt <= 16'h0;
							flash_cle_r <= 1'b1;
							bus_control_state <= `FSM_DO_WRITE;					//автомат переходит на запись команды реквеста статуса
							command_state <= st_req_status;						
							flash_cmd_to_write <= `READ_STATUS_REG;
						end
					end			
				end
				st_read_adr : begin
					if (fsm_cnt !=  5 + 1) begin
						if (flash_bus_ack_wr) begin		
							flash_cmd_to_write <= (fsm_cnt != 5) ? wr_addr[fsm_cnt] : `READ_ARRAY_2C;
							{flash_cle_r, flash_ale_r} <= (fsm_cnt == 5) ? 2'b10 : 2'b01;	
							fsm_cnt <= fsm_cnt + 1;
							bus_control_state <= `FSM_DO_WRITE;
						end
					end
					else begin
						if (flash_cle_r && !flash_rb_n_i) begin
							flash_cle_r <= 0;
						end 
						if (!flash_cle_r && flash_rb_n_i) begin 
							fsm_cnt <= 16'h0;
							bus_control_state <= `FSM_DO_READ;
							command_state <= st_read_dat;
							flash_cmd_to_write <= 8'h0;
						end
					end
				end
				st_erase : begin 
					if (fsm_cnt != 3 + 1) begin
						if (flash_bus_ack_wr) begin		
							flash_cmd_to_write <= (fsm_cnt != 3) ? wr_addr[2+fsm_cnt] : `BLOCK_ERASE_2C;
							{flash_cle_r, flash_ale_r} <= (fsm_cnt == 3) ? 2'b10 : 2'b01;
							fsm_cnt <= fsm_cnt + 1;
							bus_control_state <= `FSM_DO_WRITE;
						end
					end
					else begin
						if (flash_cle_r && !flash_rb_n_i) begin
							flash_cle_r <= 0;
						end 
						if (!flash_cle_r && flash_rb_n_i) begin
							fsm_cnt <= 16'h0;
							command_state <= st_req_status;
							flash_cle_r <= 1'b1;
							bus_control_state <= `FSM_DO_WRITE;
							flash_cmd_to_write <= `READ_STATUS_REG;
						end
					end
				end					
				st_req_id : begin
					if (flash_bus_ack_wr) begin
						if (!flash_ale_r & flash_cle_r) begin
							{flash_cle_r, flash_ale_r} <= 2'b01;
							flash_cmd_to_write <= 8'h00;
							bus_control_state <= `FSM_DO_WRITE;
						end 
						else begin
							flash_ale_r <= 1'b0;
							bus_control_state <= `FSM_DO_READ;
						end
					end
				end
			endcase
		end
		`FSM_DO_READ : begin
			bus_control_state <= `FSM_DO_READ_WAIT;
		end
		`FSM_DO_READ_WAIT : begin
			case (command_state)
				st_read_dat : begin
					if (flash_bus_ack_rd) begin
						if (fsm_cnt < fifo_size) begin  
							fsm_cnt <= fsm_cnt + 1;
							bus_control_state <= `FSM_DO_READ;
						end 
						else begin
							fsm_cnt <= 0;
							bus_control_state <= `FSM_DO_BUS_ACK;
						end
					end
				end					
				st_req_status : begin
					flash_cle_r <= 1'b0;
					if (flash_bus_ack_rd) begin
							status_reg <= flash_dq_io;
							bus_control_state <= `FSM_DO_BUS_ACK;//`FSM_IDLE;
						end
				end
				st_req_id : begin
					if (fsm_cnt < 4) begin    
						if (flash_bus_ack_rd) begin
							reg_id[fsm_cnt] <= flash_dq_io;
							fsm_cnt <= fsm_cnt + 1;
							bus_control_state <= `FSM_DO_READ;
						end
					end 
					else begin
						if (flash_bus_ack_rd) begin
							fsm_cnt <= 0;
							bus_control_state <= `FSM_DO_BUS_ACK;//`FSM_IDLE;
						end
					end				
				end
			endcase
		end
		`FSM_DO_BUS_ACK : begin
			bus_control_state <= (command_state == st_read_dat) ? `FSM_IDLE : `FSM_DO_RESET;
			command_state <= st_idle;
		end
		`FSM_DO_RESET :
			bus_control_state <= `FSM_DO_RESET_WAIT;
	   `FSM_DO_RESET_WAIT : begin
			if (flash_phy_state == `CFI_PHY_FSM_RESET_DONE)
				bus_control_state <= `FSM_IDLE;
		end
	   default : begin
	      bus_control_state <= `FSM_IDLE;
		end
   endcase 
 end
 
 
/* Sample flash data for the system bus interface */
always @(posedge clk)
   if (rst)
      fifo_dat_o <= 0;
   else if ((flash_phy_state == `CFI_PHY_FSM_READ_WAIT) &&
	    /* Wait for t_vlqv */
	    (!flash_phy_async_wait))
      /* Sample flash data */
      fifo_dat_o <= flash_dq_io;


/* Flash physical interface control state machine */
always @(posedge clk)
   if (rst)
   begin
      flash_we_n_r  <= 1'b1;
      flash_re_n_r  <= 1'b1;
      flash_dq_o_r  <= 8'd0;
		
      flash_phy_state <= `CFI_PHY_FSM_IDLE;
   end
   else
   begin
      case (flash_phy_state)
	 `CFI_PHY_FSM_IDLE : begin

	    /* Wait for a read or write command */
	    if (bus_control_state == `FSM_DO_WRITE)
	    begin
	       flash_phy_state <= `CFI_PHY_FSM_WRITE_GO;
	       /* Are we going to write a command? */
	       if (flash_cmd_to_write) //begin
				flash_dq_o_r <= flash_cmd_to_write;
 	    end
	    if (bus_control_state == `FSM_DO_READ) begin
	       flash_phy_state <= `CFI_PHY_FSM_READ_GO;
	    end
		 if (bus_control_state == `FSM_DO_RESET) begin
	       flash_phy_state <= `CFI_PHY_FSM_RESET_GO;
	    end 
	 end
	 `CFI_PHY_FSM_WRITE_GO: begin
	    /* Assert CE, WE */
	    flash_we_n_r <= 1'b0;
 
	    flash_phy_state <= `CFI_PHY_FSM_WRITE_WAIT;
	 end
	 `CFI_PHY_FSM_WRITE_WAIT: begin
	    /* Wait for t_wlwh */
	    if (!flash_phy_async_wait) begin
	       flash_phy_state <= `CFI_PHY_FSM_WRITE_DONE;
	       flash_we_n_r <= 1'b1;
	    end
	 end
	 `CFI_PHY_FSM_WRITE_DONE: begin
	    flash_phy_state <= `CFI_PHY_FSM_IDLE;
	 end
 
	 `CFI_PHY_FSM_READ_GO: begin
	    /* Assert CE, OE */
	    /*flash_adv_n_r <= 1'b1;*/
	    flash_re_n_r <= 1'b0;
	    flash_phy_state <= `CFI_PHY_FSM_READ_WAIT;
	 end
	 `CFI_PHY_FSM_READ_WAIT: begin
	    /* Wait for t_vlqv */
	    if (!flash_phy_async_wait) begin
	       flash_re_n_r    <= 1'b1;
	       flash_phy_state <= `CFI_PHY_FSM_READ_DONE;
	    end
	 end
	 `CFI_PHY_FSM_READ_DONE: begin
	    flash_phy_state <= `CFI_PHY_FSM_IDLE;
	 end
	 	`CFI_PHY_FSM_RESET_GO: begin
		flash_dq_o_r <= 8'hFF;
	   flash_phy_state <= `CFI_PHY_FSM_RESET_WAIT;
	end
	`CFI_PHY_FSM_RESET_WAIT : begin
	   if (!flash_phy_async_wait && flash_rb_n_i) 
	      flash_phy_state <= `CFI_PHY_FSM_RESET_DONE;
	end
	`CFI_PHY_FSM_RESET_DONE : begin
	   flash_phy_state <= `CFI_PHY_FSM_IDLE;
	end
	 default:
	    flash_phy_state <= `CFI_PHY_FSM_IDLE;
      endcase
   end


 
/* Defaults are for 95ns access time part, 30MHz (33.33ns) system clock */
/* wlwh: cycles for WE assert to WE de-assert: write time */
localparam cfi_part_wlwh_cycles = 4;//4; /* wlwh = 50ns, tck = 15ns, cycles = 4*/
/* elqv: cycles from adress  to data valid */
localparam cfi_part_elqv_cycles = 4;//7; /* tsop 256mbit elqv = 95ns, tck = 15ns, cycles = 6*/
 
assign flash_phy_async_wait = (|flash_phy_ctr);
 
/* Load counter with wait times in cycles, determined by parameters. */
always @(posedge clk)
   if (rst)
      flash_phy_ctr <= 0;
   else if (flash_phy_state==`CFI_PHY_FSM_WRITE_GO)
      flash_phy_ctr <= cfi_part_wlwh_cycles - 1;
   else if (flash_phy_state==`CFI_PHY_FSM_READ_GO)
     flash_phy_ctr <= cfi_part_elqv_cycles - 1;
   else if (flash_phy_state==`CFI_PHY_FSM_RESET_GO)
     flash_phy_ctr <= 10;
   else if (|flash_phy_ctr)
      flash_phy_ctr <= flash_phy_ctr - 1;
 
   /* Signal to indicate when we should drive the data bus */
   wire flash_bus_write_enable;
   wire flash_bus_reset_enable;
	assign flash_bus_write_enable = (flash_phy_state==`CFI_PHY_FSM_WRITE_GO) |
													(flash_phy_state==`CFI_PHY_FSM_WRITE_WAIT);	
	assign flash_bus_reset_enable = (flash_phy_state==`CFI_PHY_FSM_RESET_GO) |
													(flash_phy_state==`CFI_PHY_FSM_RESET_WAIT);
//	(bus_control_state == `FSM_DO_WRITE) |
//				   (bus_control_state == `FSM_DO_WRITE_WAIT);

/* Signal to indicate when write/read operation is done */
assign flash_bus_ack_wr = (flash_phy_state == `CFI_PHY_FSM_WRITE_DONE);
assign flash_bus_ack_rd = (flash_phy_state == `CFI_PHY_FSM_READ_DONE); 
 
/* Assign signals to physical bus */
assign flash_dq_io = (flash_bus_write_enable | flash_bus_reset_enable) ? flash_dq_o_r : 
		     {flash_dq_width{1'bz}};
assign flash_ale_o = flash_ale_r;
assign flash_wp_n_o = 1'b1; /* Never write protect */
assign flash_cle_o = flash_cle_r;
assign flash_ce_n_o = (bus_control_state == `FSM_IDLE) ? 1'b1 : 1'b0;
assign flash_re_n_o = flash_re_n_r;
assign flash_we_n_o = flash_we_n_r;


/* Tell the bus we're done */
assign bus_ack_done_o = (bus_control_state == `FSM_DO_BUS_ACK);
//assign bus_busy_o = !(bus_control_state == `FSM_IDLE);

//input & output fifo
assign RdA = (command_state == st_program_dat) ? fsm_cnt : 11'h0; //FIFO->(r8)->NAND
assign WrA = (command_state == st_read_dat) ? fsm_cnt : 11'h0;		//NAND->(w8)->FIFO

//NAND->(w8)->FIFO->(r32)->SRAM
fifo_w8r32 fifo_out(
	.Reset(rst), 
	.WCK(clk), 
	.WE(flash_bus_ack_rd),
	.WrA(WrA[10:0]), 
	.D(fifo_dat_o), 
	.RCK(clk_ext), 
	.Q(bus_dat_o), 
	.QV(bus_strobe_fifo),
	.TestAddr(read_test_addr),
	.TestData(read_test_data),
	.TestFlag(read_test_flag)
);

//SRAM->(w32)->FIFO->(r8)->NAND
fifo_w32r8 fifo_in(
	.Reset(rst),
	.WCK(clk_ext),
	.RdA(RdA[10:0]),
	.Q(fifo_dat_i),
	.RCK(clk),
	.RE(flash_bus_ack_wr),
	.D(bus_dat_i),
	.DV(bus_strobe_i),
	.DO_PROG(do_program_fifo),		//генерирует импульс в автомат для начала записи
	.TestFlag(program_test_flag)
);

//command interface
localparam CtrlRegCount=16;
localparam AddressBits=8;
wire [CtrlRegCount-1:0] CtrlSel;

function [CtrlRegCount-1:0] CtrlAddrDC;
input [7:0] A;
begin
	case (A[AddressBits-1:0])
		 0: CtrlAddrDC=32'h00000001;					//request status
		 1: CtrlAddrDC=32'h00000002;					//program test array
		 2: CtrlAddrDC=32'h00000004;					//read array
		 3: CtrlAddrDC=32'h00000008;					//request device id
		 4: CtrlAddrDC=32'h00000010;					//erase block
		 5: CtrlAddrDC=32'h00000020;					//command state
		 6: CtrlAddrDC=32'h00000040;					
		 7: CtrlAddrDC=32'h00000080;					
		 8: CtrlAddrDC=32'h00000100;					//reset
		default: CtrlAddrDC=0;
	endcase
end
endfunction

assign CtrlSel = CS ? CtrlAddrDC(CtrlAddr) : 0 ;

reg [15:0] test_comm_reg = 16'hABCE; 

always @(posedge Wr or posedge rst)
begin
	if (rst) begin
		read_test_addr <= 0;
		prog_test_addr <= 0;
	end 
	else begin
		if (CtrlSel[2]) begin
			prog_test_addr[16:0] <= {9'h0, CtrlData[15:8]};				//column address
			read_test_addr[9:0] <= {2'b00, CtrlData[7:0]};
		end
		if (CtrlSel[1])
			prog_test_addr[16:0] <= {1'b0, CtrlData[15:0]};		//row address
		if (CtrlSel[4])
			prog_test_addr[16:0] <= {1'b0, CtrlData[15:0]};
		if (CtrlSel[8])
			test_comm_reg[15:0] <= CtrlData[15:0];
	end		
end


assign CtrlData = CtrlSel[0]&Rd ? {8'h0,status_reg[7:0]} : 16'hZZZZ;
assign CtrlData = CtrlSel[2]&Rd ? {read_test_data[15:0]} : 16'hZZZZ;
assign CtrlData = CtrlSel[3]&Rd ? {reg_id[1],reg_id[3]} : 16'hZZZZ;
assign CtrlData = CtrlSel[5]&Rd ? {flash_rb_n_i,flash_cle_r, flash_ale_r, flash_we_n_r, flash_re_n_r, flash_ce_n_o, 2'b00, flash_cmd_to_write[7:0]} : 16'hZZZZ;
assign CtrlData = CtrlSel[6]&Rd ? {command_state[3:0],bus_control_state[7:0],4'h0} : 16'hZZZZ;
assign CtrlData = CtrlSel[7]&Rd ? fsm_cnt[15:0] : 16'hZZZZ;
assign CtrlData = CtrlSel[8]&Rd ? {test_comm_reg[15:0]} : 16'hZZZZ;

//status
CatchSyncPulseE UCtrl1(.C(clk),.CE(1'b1),.D(Wr),.En(CtrlSel[0]),.Q(do_readstatus));
//program
CatchSyncPulseE UCtrl2(.C(clk),.CE(1'b1),.D(Wr),.En(CtrlSel[1]),.Q(do_program_test));
assign do_program = do_program_test | do_program_fifo;
CatchFast UCtrlF1(.D(do_program_test),.Q(program_test_flag),.R(bus_ack_done_o));
//read
CatchSyncPulseE UCtrl3(.C(clk),.CE(1'b1),.D(Wr),.En(CtrlSel[2]),.Q(do_read_test)); 
assign do_read = do_read_test | bus_do_read_i;
CatchFast UCtrlF2(.D(do_read_test),.Q(read_test_flag),.R(bus_ack_done_o));
//id
CatchSyncPulseE UCtrl4(.C(clk),.CE(1'b1),.D(Wr),.En(CtrlSel[3]),.Q(do_req_id));
//erase
CatchSyncPulseE UCtrl5(.C(clk),.CE(1'b1),.D(Wr),.En(CtrlSel[4]),.Q(do_erase));
CatchFast UCtrlF3(.D(do_erase),.Q(erase_test_flag),.R(bus_ack_done_o));
//reset
CatchSyncPulseE UCtrl6(.C(clk),.CE(1'b1),.D(Wr),.En(CtrlSel[8]),.Q(do_reset));
endmodule // cfi_ctrl_engine