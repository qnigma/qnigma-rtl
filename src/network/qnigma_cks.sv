module qnigma_cks (
  input logic         clk,
  input logic         rst,
  input logic [7:0]   dat,
  input logic [31:0]  ini,
  input logic         val,
  input logic         nxt,
  output logic        zer,
  output logic [15:0] cks
);

  logic [31:0] cks_odd;  
  logic [31:0] cks_eve;  
  
  logic [16:0] cks_sum;
  logic [15:0] cks_cur;
  logic [7:0] dat_r;
  logic val_neg;
  logic odd;
  
  assign cks_cur = nxt ? {8'h00, dat_r} : {dat_r, dat};

  always_ff @ (posedge clk) dat_r <= (nxt) ? 0 : dat;

  always_ff @ (posedge clk) zer <= cks == 0;

  always_ff @ (posedge clk) cks <= ~(cks_sum[15:0] + cks_sum[16]);

  always_ff @ (posedge clk) begin
    if (rst) begin
      cks_odd <= ini;
      odd <= 0;
    end
    else if (val) begin
      odd <= ~odd;
      if (odd) cks_odd <= cks_odd + cks_cur;
      else     cks_eve <= cks_odd + {dat, 8'h00};
    end
  end

  always_ff @ (posedge clk) cks_sum <= (odd) ? cks_eve[15:0] + cks_eve[31:16] : cks_odd[15:0] + cks_odd[31:16];

endmodule : qnigma_cks
