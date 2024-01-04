module qnigma_alu_ram
  import
    qnigma_math_pkg::*;
#( 
  parameter AW = 16,
  parameter DW = 16
)
(
    input  logic          clk,
    
    input  logic [DW-1:0] d_a,
    input  logic [AW-1:0] a_a,
    input  logic          w_a,
    output logic [DW-1:0] q_a,

    input  logic [DW-1:0] d_b,
    input  logic [AW-1:0] a_b,
    input  logic          w_b,
    output logic [DW-1:0] q_b
);

  logic [31:0] proto_ram [0:2**AW-1];

  /* verilator lint_off MULTIDRIVEN */
  reg [DW-1:0] ram [2**AW-1:0];
  /* verilator lint_on MULTIDRIVEN */

  initial begin
    for (int i = 0; i < 2**AW; i = i + 1)          proto_ram[i] = 0;
    for (int j = 0; j < WORDS_PER_OPER; j = j + 1) proto_ram[ADDR_ZERO      + j] = (ZERO      >> ALU_RAM_WIDTH*j) & {ALU_RAM_WIDTH{1'b1}};
    for (int j = 0; j < WORDS_PER_OPER; j = j + 1) proto_ram[ADDR_ONE       + j] = (ONE       >> ALU_RAM_WIDTH*j) & {ALU_RAM_WIDTH{1'b1}};
    for (int j = 0; j < WORDS_PER_OPER; j = j + 1) proto_ram[ADDR_CURVE_GX  + j] = (CURVE_GX  >> ALU_RAM_WIDTH*j) & {ALU_RAM_WIDTH{1'b1}};
    for (int j = 0; j < WORDS_PER_OPER; j = j + 1) proto_ram[ADDR_CURVE_A24 + j] = (CURVE_A24 >> ALU_RAM_WIDTH*j) & {ALU_RAM_WIDTH{1'b1}};
    for (int j = 0; j < WORDS_PER_OPER; j = j + 1) proto_ram[ADDR_P25519    + j] = (P25519    >> ALU_RAM_WIDTH*j) & {ALU_RAM_WIDTH{1'b1}};
    for (int j = 0; j < WORDS_PER_OPER; j = j + 1) proto_ram[ADDR_P25519_1  + j] = (P25519_1  >> ALU_RAM_WIDTH*j) & {ALU_RAM_WIDTH{1'b1}};
    for (int j = 0; j < WORDS_PER_OPER; j = j + 1) proto_ram[ADDR_P25519_2  + j] = (P25519_2  >> ALU_RAM_WIDTH*j) & {ALU_RAM_WIDTH{1'b1}};
    for (int j = 0; j < WORDS_PER_OPER; j = j + 1) proto_ram[ADDR_P25519_3  + j] = (P25519_3  >> ALU_RAM_WIDTH*j) & {ALU_RAM_WIDTH{1'b1}};
    for (int j = 0; j < WORDS_PER_OPER; j = j + 1) proto_ram[ADDR_P25519_4  + j] = (P25519_4  >> ALU_RAM_WIDTH*j) & {ALU_RAM_WIDTH{1'b1}};
    for (int j = 0; j < WORDS_PER_OPER; j = j + 1) proto_ram[ADDR_P25519_B  + j] = (P25519_B  >> ALU_RAM_WIDTH*j) & {ALU_RAM_WIDTH{1'b1}};
    for (int j = 0; j < WORDS_PER_OPER; j = j + 1) proto_ram[ADDR_P1305     + j] = (P1305     >> ALU_RAM_WIDTH*j) & {ALU_RAM_WIDTH{1'b1}};
    for (int j = 0; j < WORDS_PER_OPER; j = j + 1) proto_ram[ADDR_P1305_1   + j] = (P1305_1   >> ALU_RAM_WIDTH*j) & {ALU_RAM_WIDTH{1'b1}};
    for (int j = 0; j < WORDS_PER_OPER; j = j + 1) proto_ram[ADDR_P1305_2   + j] = (P1305_2   >> ALU_RAM_WIDTH*j) & {ALU_RAM_WIDTH{1'b1}};
    for (int j = 0; j < WORDS_PER_OPER; j = j + 1) proto_ram[ADDR_P1305_B   + j] = (P1305_B   >> ALU_RAM_WIDTH*j) & {ALU_RAM_WIDTH{1'b1}};
    $writememh("ecp_ram_ini.txt", proto_ram);
    $readmemh("ecp_ram_ini.txt", ram);
  end

  // Port A
  always_ff @ (posedge clk) begin
    if (w_a) begin ram[a_a] <= d_a; q_a <= d_a; end
    else q_a <= ram[a_a];
  end
  
  // Port B
  always_ff @ (posedge clk) begin
    if (w_b) begin ram[a_b] <= d_b; q_b <= d_b; end
    else q_b <= ram[a_b];
  end

endmodule : qnigma_alu_ram
