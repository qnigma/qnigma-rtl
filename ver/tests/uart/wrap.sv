module wrap
(
  input  logic clk,
  input  logic rst,
  output logic don
);

  logic [7:0] txd;
  logic [7:0] rxd;
  logic       cts;
  
  logic txv;
  logic rxv;

  logic rx;
  logic tx;

  assign rx = tx;

  uart #(                            
    .DATA_BITS (8),
    .STOP_BITS (1),
    .PARITY_MODE    (0), // 0: None, 1: Even, 2: Odd
    .BAUD_RATE (115200),
    .CLK_FREQ  (100000000)
  ) dut (
    .clk   (clk),
    .rst   (rst),
  
  	.rx    (rx ),
  	.tx    (tx ),
  
  	.txd   (txd),
  	.txv   (txv),
  	.cts   (cts),
  
  	.rxd   (rxd),
  	.rxv   (rxv)
  );

  enum logic [7:0] {
    IDLE,
    SEND,
    RECV,
    DONE
  } state;

  always_ff @ (posedge clk) begin
    if (rst) begin
      state <= IDLE;
      txd   <= 8'h00; 
    end
    else begin
      case (state)
        IDLE : begin 
          txv <= 0; 
          don <= 0;          
          if (cts) state <= SEND; 
        end 
        SEND : begin 
          txv <= 1; 
          don <= 0;          
          state <= RECV; 
        end 
        RECV : begin 
          txv <= 0; 
          don <= 0; 
          if (rxv) begin
            txd <= txd + 1;
            state <= (txd == 8'hff) ? DONE : IDLE; 
            if (rxd == txd) $display("data %x, OK", rxd);
            else            $display("data %x/%x, FAIL", txd, rxd);
          end
        end 
        DONE : begin 
          txv <= 0; 
          don <= 1;          
          state <= DONE; 
        end 
        default:;
      endcase
    end
  end

endmodule
