/* 
 * Top-level wrap 
*/
module top (
  input  logic        clk,
  input  logic        rst,
  input  logic        test_add,
  input  logic        test_sub,
  input  logic        test_mul,
  
  input  logic        cal, // 1-tick strobe from TB to calculate
  
  input  logic [31:0] opa, // Operand A 
  input  logic [31:0] opb, // Operand B
  output logic [63:0] res, // Result

  output logic         done
);

  logic [31:0] core_opa;
  logic [31:0] core_opb;
  logic        core_mul;
  logic        core_add;
  logic        core_sub;
  logic        core_cal;
  logic [63:0] core_res;
  logic        core_ovf;
  logic        core_eql;
  logic        core_done;

  qnigma_alu_core #(
    .N  (4),  // Number of multipliers 16
    .K  (8), // Multiplier width 16
    .WA (40)  // Adder input width 
  ) alu_core_inst (
    .clk (clk     ),
    .rst (rst     ),
    .opa (core_opa),
    .opb (core_opb),
    
    .mul (test_add),
    .add (),
    .sub (),
    .cal (cal     ),

    .res (core_res),
    .ovf (core_ovf),
    .eql (core_eql),
    .don (core_done)
  );

  assign res = core_res;
  assign core_opa = opa;
  assign core_opb = opb;

endmodule : top
