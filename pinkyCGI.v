//
`define INST_END_INDEX	5

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
wire `WORD ir;	
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


module stage1(pc_follow, op_cc_out, Rd_out, op2_out, ir, clk, reset, pc);
output reg `WORD pc_follow;
output `WORD Rd_out, op2_out;
output reg [6:0] op_cc_out;
input `WORD ir;
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
    op_cc_out <= {op_code, cc};
    //Rd_out <= regfile[Rd];
    //op2_out <= (ir[15] & ir[14]) ? 16'h0000 :  `Op2struct(ir, pre, preFlag, regfile);
end
endmodule

module stage2(pc_follow, op_cc_out, value_out, op_cc_in, addr, data, clk, reset, pc);
output reg `WORD pc_follow, value_out;
output reg [6:0]  op_cc_out;
input `WORD addr, data, pc;
input clk, reset;
input [6:0] op_cc_in;

endmodule


module processor(halt, reset, clk);
output reg halt;
input reset, clk;

//the underscore<digit><digit> notation indicates control flow
//for example _12 means it goes from stage 1 to stage 2
wire `WORD PCfollow_01, PCfollow_12, PCfollow_23, PCfollow_30;
wire `WORD ir;
wire haltedP;
wire `WORD Rd_12, op2_12;
wire [6:0] op_cc_12, op_cc_23;
wire `WORD result;

always @(posedge clk) begin
halt <= haltedP;
end

//module stage0(PCfollow,ir,halt,R15,Z,clk,reset);
stage0 s0(PCfollow_01,ir,haltedP,16'h0000,1'b0,clk,reset);

//module stage1(pc_follow, op_cc_out, Rd_out, op2_out, ir, clk, reset, pc);
stage1 s1(PCfollow_12, op_cc_12, Rd_12, op2_12, ir, clk, reset, PCfollow_01);

//module stage2(pc_follow, op_cc_out, value_out, op_cc_in, addr, data, clk, reset, pc);
stage2 s2(PCfollow_23, op_cc_23, result, op_cc_12, Rd_12, op2_12, clk, reset, PCfollow_12);

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
