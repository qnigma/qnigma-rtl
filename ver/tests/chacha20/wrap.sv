`define COLOR_RED "\x1b[31m"
`define COLOR_GREEN "\x1b[32m"
`define COLOR_RESET "\x1b[0m"

module wrap   
  import
    qnigma_chacha20_pkg::*;
(
  input  logic                  clk  ,
  input  logic                  rst  ,
  input  logic [255:0]          key  ,
  input  logic [95 :0]          non  ,
  input  logic [31 :0]          ini  ,
  output logic                  don  ,

  input  logic [DATA_WIDTH-1:0] dat_i,
  input  logic                  val_i,
  input  logic                  sof_i,
  input  logic                  eof_i,
  output logic                  cts_i,
  // Output data stream
  output logic [DATA_WIDTH-1:0] dat_o,
  output logic                  val_o,
  output logic                  sof_o,
  output logic                  eof_o
);

  qnigma_math_chacha20 math_chacha20_inst (
    .clk     (clk  ),
    .rst     (rst  ), // Hold reset high until start using the core
    .ena     (1'b1 ),
    .dat_i   (dat_i),
    .val_i   (val_i),
    .sof_i   (sof_i),
    .eof_i   (eof_i),
    .cts_i   (cts_i),
    // Output data stream
    .dat_o   (dat_o),
    .val_o   (val_o),
    .sof_o   (sof_o),
    .eof_o   (eof_o),
    .key     (key  ), // Keys should be valid once rst is deasserted
    .non     (non  ),
    .ini     (ini  )
  );

endmodule : wrap
