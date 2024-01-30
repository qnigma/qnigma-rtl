module uart #
(                            
  parameter int   DATA_BITS = 8,
  parameter int   STOP_BITS = 1,
  parameter [1:0] PARITY_MODE  = 0, // 0: None, 1: Even, 2: Odd
  parameter int   BAUD_RATE = 115200,
  parameter int   CLK_FREQ  = 125000000
)
(
    input  logic       clk,
    input  logic       rst,

	input  logic       rx,
	output logic       tx,

	input  logic [7:0] txd,
	input  logic       txv,
	output logic       cts,
	
	output logic [7:0] rxd,
	output logic       rxv
);
  
  uart_rx #(
    .DATA_BITS (DATA_BITS),
    .STOP_BITS (STOP_BITS),
    .PARITY_MODE    (PARITY_MODE   ),
    .BAUD_RATE (BAUD_RATE),
    .CLK_FREQ  (CLK_FREQ )
  ) uart_rx_inst (
    .clk (clk),
    .rst (rst),
    .rx  (rx ),
    .dat (rxd),
    .val (rxv)
  );
  
  uart_tx #(
    .DATA_BITS   (DATA_BITS),
    .STOP_BITS   (STOP_BITS),
    .PARITY_MODE (PARITY_MODE   ), // 0: None, 1: Even, 2: Odd
    .BAUD_RATE   (BAUD_RATE),
    .CLK_FREQ    (CLK_FREQ )
  ) uart_tx_inst (
    .clk  (clk),
    .rst  (rst),
    .tx   (tx ),
    .dat  (txd),
    .val  (txv),
    .cts  (cts) 
  );

endmodule
