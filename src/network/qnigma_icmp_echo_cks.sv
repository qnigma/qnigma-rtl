module qnigma_icmp_echo_cks
  import
    qnigma_pkg::*;
#(
  parameter mac_t  MAC_ADDR   = 48'h0
)
(
  input  logic            clk,
  input  logic            rst, // tx_done

  input  logic            ful, // fifo_full

  input  logic            vin, // pld_val_rx
  input  logic     [7:0]  din, // pld_dat_rx

  output logic     [31:0] cks
);

  logic [31:0] cks_add;
  logic [7:0]  dat_reg;
  // Calculate Echo payload checksum
  always_ff @ (posedge clk) if (vin) dat_reg <= din;

  logic even;

  always_ff @ (posedge clk) begin
    if (rst) begin
      even <= 0;
      cks_add <= 0;
    end
    else if (vin && !ful) begin
      even <= ~even; // increment with each 
      cks_add <= (even) ? cks_add + {dat_reg, din} : cks_add;
    end
  end
  
  assign cks = even ? cks_add + {dat_reg, 8'h00} : cks_add;

endmodule : qnigma_icmp_echo_cks
