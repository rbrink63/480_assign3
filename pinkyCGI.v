//
`define INST_END_INDEX	9

//common bit lengths
`define WORD 		[15:0]
`define OPCODE 		[15:11]
`define CC			[10:9]
`define IMM			[8]
`define DEST		[7:4]
`define	OP2			[3:0]
`define REGS		[15:0]
`define PC			registers[15]
`define SIZE		[65535:0]
`define PRESIZE		[11:0]
`define BASEOPS		[3:0]

//stage 
`define	STAGE       [1:0]		
`define STAGE0		0
`define STAGE1		1
`define	STAGE2		2
`define STAGE3		3

//OPCODES
`define OPADD 	5'b00000
`define OPADDF 	5'b00001
`define OPAND	5'b00010
`define OPBIC	5'b00011
`define OPEOR	5'b00100
`define OPFTOI  5'b00101
`define OPITOF  5'b00110
`define OPLDR   5'b00111
`define OPMOV   5'b01000
`define OPMUL   5'b01001
`define OPMULF  5'b01010
`define OPNEG   5'b01011
`define OPORR   5'b01100
`define OPRECF  5'b01101
`define OPSHA   5'b01110
`define OPSTR   5'b01111
`define OPSLT   5'b10000
`define OPSUB   5'b10001
`define OPSUBF  5'b10010
`define OPSYS   5'b10011
`define OPNOP   5'b10100
//5'b10101
//5'b10110
//5'b10111
`define OPPRE   5'b11000


//CC values
`define	AL			0
`define S 			1
`define NE			2
`define EQ			3

//OP2 MACRO
`define Op2struct(IR, PRE, PREFLAG, REGFILE) \
	(IR `IMM ? { PREFLAG ? {IR `OP2, PRE} : {12{IR[3]}}, IR `OP2 } : REGFILE[IR `OP2] )

module stage0(PCfollow,ir,halt,R15,Z,clk,reset);
			  
output reg `WORD PCfollow;
output `WORD ir;
output halt;
input `WORD R15;
input Z,clk,reset;

reg `WORD instmem `SIZE;	
reg `WORD PC;				
wire `WORD irInitial;
wire checkCodes;
wire [1:0] CC;

always@(reset) begin
	PC = 0;
	$readmemh("inst.txt", instmem, 0, `INST_END_INDEX);
end

always@(posedge clk) begin
	PCfollow <= PC;
	PC <= PC + 1;
end

assign irInitial = instmem[PC];
assign CC = irInitial `CC;
assign insertNOP = ((CC == `NE)&&(Z == 1))||((CC == `EQ)&&(Z == 0));
assign ir = (insertNOP == 1)? {`OPNOP,11'h000} : instmem[PC];
assign halt = (ir `OPCODE == `OPSYS);

endmodule


module stage1(pc_follow, pc_to_reg, ir_out, Rd_out, op2_out, ir, clk, reset, pc);
output reg `WORD pc_follow;
output `WORD Rd_out, op2_out;
output reg `WORD ir_out;
input `WORD ir, pc_to_reg;
input clk, reset;
input `WORD pc;

wire [4:0] op_code;
wire [1:0] cc;
wire immFlag;

reg `WORD regfile `REGS;
reg preFlag;
reg `PRESIZE pre, pre_temp;



always@(reset)begin
    $readmemh("regs.txt", regfile, 0, 15);
    preFlag = 0;
    pre = 0;

end

//split up instruction word into the separate chunks
assign op_code = ir `OPCODE;
assign cc = ir `CC;
assign immFlag = ir `IMM;
assign Rd = ir `DEST;
assign Rd_out = regfile[Rd];

//`define Op2struct(IR, PRE, PREFLAG, REGFILE) \
//	(IR `IMM ? { PREFLAG ? {PRE, IR `OP2} : {12{IR[3]}}, IR `OP2 } : REGFILE[IR `OP2] )
assign op2_out = (ir[15] & ir[14]) ? 16'h0000 :  `Op2struct(ir, pre, preFlag, regfile);

//assign pre = pre_temp;
//assign pre = (ir[15] & ir[14]) ? ir `PRESIZE : pre_temp;
//assign preFlag = ir[15] & ir[14];
//assign Rn = ir `OP2;

always@(posedge clk)begin
    if(ir[15] & ir[14]) 
	begin
	preFlag = 1;
	pre = ir `PRESIZE;
	end
    else if(immFlag) preFlag = 0;
    
    pc_follow <= pc;
    ir_out <= ir;
    //Rd_out <= regfile[Rd];
    //op2_out <= (ir[15] & ir[14]) ? 16'h0000 :  `Op2struct(ir, pre, preFlag, regfile);
end
endmodule

module stage2(pc_follow, ir_out, value_out, ir_in, addr, data, clk, reset, pc);
output reg `WORD pc_follow;
output reg `WORD value_out;
output reg `WORD ir_out;
input `WORD addr, data, pc;
input clk, reset;
input `WORD ir_in;
reg `WORD datamem `SIZE;
reg `WORD data_latch;

wire [4:0]op;
assign op = ir_in `OPCODE;

//do the ALU thing
//when comparing to the PinKY instruction set
//Rd is addr and Op2 is data

always@(reset)begin
    //only reading in 16 data mem locations for now
    $readmemh("data.txt", datamem, 0, 15);
end


always@(posedge clk)begin
    case(op)
        `OPADD : begin  value_out = addr + data_latch; end
        `OPAND : begin  value_out = addr & data_latch; end
        `OPBIC : begin  value_out = addr & ~data_latch; end
        `OPEOR : begin  value_out = addr ^ data_latch; end
        `OPLDR : begin  value_out = datamem[data_latch]; end
        `OPMOV : begin  value_out = data_latch; end
        `OPMUL : begin  value_out = addr * data_latch; end
        `OPNEG : begin  value_out = -data_latch; end
        `OPORR : begin  value_out = addr | data_latch; end
        `OPSHA : begin  value_out = (data_latch>0) ? addr<<data_latch : addr>>-data_latch; end
        `OPSTR : begin datamem[addr] = data_latch; value_out = data_latch; end
        `OPSLT : begin  value_out = (addr<data_latch); end
        `OPSUB : begin  value_out = addr - data_latch; end
    //we'll catch these in the default case
    //    `OPSYS : begin ; end
    //    `OPNOP : begin ; end
    //    `OPPRE : begin ; end
        default : begin value_out = 16'h0000; end
    endcase
    data_latch <= data;
    pc_follow <= pc;
    ir_out <= ir_in;
end
endmodule

module stage3(pc_follow, z_reg, ir_in, result, clk, reset, pc);
input `WORD result, pc;
input `WORD ir_in;
input clk, reset;
output reg `WORD pc_follow;
output reg z_reg; //should this be a reg?

reg [1:0] cc;
wire z;


//assign z = (cc == `S) ? z : (((result == 16'h0000) & (cc == `S)) ? 1'b1 : 1'b0);

always@(reset)begin
    z_reg = 0;
end

always@(posedge clk)begin
    cc = ir_in `CC;
    if (cc == `S)begin
	if (result == 16'h0000) z_reg = 1'b1;
	else z_reg = 1'b0;
    end
end
endmodule


module processor(halt, reset, clk);
output reg halt;
input reset, clk;

//the underscore<digit><digit> notation indicates control flow
//for example _12 means it goes from stage 1 to stage 2
wire `WORD PCfollow_01, PCfollow_12, PCfollow_23, PCs4_to_reg;
wire `WORD ir_01, ir_12, ir_23;
wire haltedP;
wire `WORD Rd_12, op2_12;
wire `WORD result;
wire z;

always @(posedge clk) begin
halt <= haltedP;
end

//module stage0(PCfollow,ir,halt,R15,Z,clk,reset);
stage0 s0(PCfollow_01,ir_01,haltedP,16'h0000,z,clk,reset);

//module stage1(pc_follow, pc_to_reg, ir_out, Rd_out, op2_out, ir, clk, reset, pc);
stage1 s1(PCfollow_12, PCs4_to_reg, ir_12, Rd_12, op2_12, ir_01, clk, reset, PCfollow_01);

//module stage2(pc_follow, ir_out, value_out, ir_in, addr, data, clk, reset, pc);
stage2 s2(PCfollow_23, ir_23, result, ir_12, Rd_12, op2_12, clk, reset, PCfollow_12);

//module stage3(pc_follow, z_out, ir_in, result, clk, reset, pc);
stage3 s3(PCs4_to_reg, z, ir_23, result, clk, reset, PCfollow_23);

always @(reset) begin
	halt = 0;
end

endmodule

module testbench;
reg reset = 0;
reg clk = 0;
wire halted;
processor PE(halted, reset, clk);
initial begin
  $dumpfile("dumpfile.vcd");
  $dumpvars(0,PE);
  #10 reset = 1;
  #10 reset = 0;
  while (!halted) begin
    #10 clk = 1;
    #10 clk = 0;
  end
  $finish;
end
endmodule
