// Generic true dual-port dual-clock RAM
module qnigma_ram_dp #( 
  parameter AW = 16,
  parameter DW = 16
)
(
    input  logic rst,
    input  logic clk_a,
    input  logic clk_b,
    input  logic [DW-1:0] d_a,
    input  logic [AW-1:0] a_a,
    input  logic          w_a,
    output logic [DW-1:0] q_a,

    input  logic [DW-1:0] d_b,
    input  logic [AW-1:0] a_b,
    input  logic          w_b,
    output logic [DW-1:0] q_b
);

  /* verilator lint_off MULTIDRIVEN */
  reg [DW-1:0] ram [2**AW-1:0];
  /* verilator lint_on MULTIDRIVEN */

  // Port A
  always_ff @ ( posedge clk_a ) begin
    if (w_a) begin ram[a_a] <= d_a; q_a <= d_a; end
    else q_a <= ram[a_a];
  end

  // Port B
  always_ff @ ( posedge clk_b ) begin
    if (w_b) begin ram[a_b] <= d_b; q_b <= d_b; end
    else q_b <= ram[a_b];
  end
  
endmodule : qnigma_ram_dp
