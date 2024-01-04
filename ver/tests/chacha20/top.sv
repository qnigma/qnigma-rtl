module top (
  input  logic         clk  ,
  input  logic         rst  ,
  input  logic [255:0] key  ,
  input  logic [95 :0] non  ,
  input  logic [31 :0] ini  ,
  output logic         don  ,

  input  logic [7:0]   dat_i,
  input  logic         val_i,
  input  logic         sof_i,
  input  logic         eof_i,
  output logic         cts_i,
  // Output data stream
  output logic [7:0]   dat_o,
  output logic         val_o,
  output logic         sof_o,
  output logic         eof_o
);

  wrap wrap_inst (
    .clk   (clk),
    .rst   (rst),
    .key   (key),
    .non   (non),
    .don   (don),
    .ini   (ini),
    .dat_i (dat_i),
    .val_i (val_i),
    .sof_i (sof_i),
    .eof_i (eof_i),
    .cts_i (cts_i),
    .dat_o (dat_o),
    .val_o (val_o),
    .sof_o (sof_o),
    .eof_o (eof_o)
  );

endmodule