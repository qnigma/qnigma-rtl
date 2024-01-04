// Clock-domain crossing using trye DP RAM FIFO
module qnigma_cdc   
  import
    qnigma_pkg::*;
#(
  parameter bit OUT_REG = 1
)
(
  input  logic       clk_in,
  input  logic       rst_in,
  input  logic [7:0] data_in,
  input  logic       valid_in,
  input  logic       error_in,

  input  logic       clk_out,
  input  logic       rst_out,
  output logic [7:0] data_out,
  output logic       valid_out,
  output logic       error_out
);

  // Introduce a readout MAC_RX_CDC_DELAY to make sure valid_out will have no interruptions 
  // because rx_clk and clk are asynchronous 
  
  logic [MAC_RX_CDC_DELAY-1:0] empty; // No data in RAM
  
  logic fifo_clk_w;
  logic fifo_rst_w;
  logic fifo_clk_r;
  logic fifo_rst_r;

  logic       fifo_write;
  logic [7:0] fifo_data_in;
  logic       fifo_read;
  logic [7:0] fifo_data_out;
  
  logic fifo_valid_out;
  logic fifo_full;
  logic fifo_empty;

  //
  qnigma_fifo_dc #(MAC_RX_CDC_FIFO_DEPTH, 8) fifo_inst(
    .clk_w     (fifo_clk_w),
    .rst_w     (fifo_rst_w),
    .clk_r     (fifo_clk_r),
    .rst_r     (fifo_rst_r),

    .write     (fifo_write),
    .data_in   (fifo_data_in),
    
    .read      (fifo_read),
    .data_out  (fifo_data_out),
    .valid_out (fifo_valid_out),
    
    .full      (fifo_full),
    .empty     (fifo_empty)
  );
  
  assign fifo_clk_w = clk_in;
  assign fifo_rst_w = rst_in;
  
  assign fifo_data_in = data_in;
  assign fifo_write = valid_in;
  
  assign fifo_clk_r = clk_out;
  assign fifo_rst_r = rst_out;
  
  generate
    if (OUT_REG) begin : gen_reg
	    always_ff @ (posedge clk_out) begin
		    data_out  <= fifo_data_out;
		    valid_out <= fifo_valid_out;
		  end
    end
    else begin : gen_comb
	    always_comb begin
        data_out  = fifo_data_out;
        valid_out = fifo_valid_out;
		  end
    end
  endgenerate

  always_ff @ (posedge clk_out) begin
    empty[MAC_RX_CDC_DELAY-1:0] <= {empty[MAC_RX_CDC_DELAY-2:0], fifo_empty};
    fifo_read <= ~empty[MAC_RX_CDC_DELAY-1];
  end

endmodule : qnigma_cdc
