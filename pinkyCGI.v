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

module stage0(PCfollow,ir,halt,R15,Z,clk,reset);
			  
output `WORD PCfollow;
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
	$readmemh("inst.txt", instmem);
end

always@(posedge clk) begin
	PC <= PC + 1;
end

assign irInitial = instmem[PC];
assign CC = irInitial `CC;
assign insertNOP = ((CC == `NE)&&(Z == 1))||((CC == `EQ)&&(Z == 0));
assign ir = (insertNOP == 1)? {`OPNOP,11'h000} : instmem[PC];
assign PCfollow = PC;
assign halt = (ir `OPCODE == `OPSYS);

endmodule


module processor(halt, reset, clk);
output reg halt;
input reset, clk;

wire `WORD PCfollowP;
wire `WORD irP;
wire haltedP;

always @(posedge clk) begin
halt <= haltedP;
end

stage0 s0(PCfollowP,irP,haltedP,1'b0,1'b0,clk,reset);

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
