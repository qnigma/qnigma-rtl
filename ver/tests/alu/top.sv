module top (
  input  logic         clk,
  input  logic         rst,
  input  logic         test_add,
  input  logic         test_sub,
  input  logic         test_mul,
  input  logic         test_inv,
  input  logic         run,
  input  logic [255:0] opa, 
  input  logic [255:0] opb,
  input  logic         fld_25519,
  output logic         pass, 
  output logic         done, 
  output logic         bad_op
);

  wrap wrap_inst (
    .clk       (clk),
    .rst       (rst),
    .test_add  (test_add),
    .test_sub  (test_sub),
    .test_mul  (test_mul),
    .test_inv  (test_inv),
    .run       (run),
    .opa       (opa),
    .opb       (opb),
    .fld_25519 (fld_25519),
    .pass      (pass),
    .done      (done),
    .bad_op    (bad_op)
  );

endmodule