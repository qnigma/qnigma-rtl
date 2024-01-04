
module debug_top (
  input logic clk,
  input logic rst,

  // Ethernet 
  // input logic [15:0] eth_phyid0,
  // input logic [15:0] eth_phyid1,
  // input logic        eth_aneg_complete,
  // input logic        eth_aneg_error,
  // input logic        eth_speed_is_10,
  // input logic        eth_speed_is_100,
  // input logic        eth_speed_is_1000
  input  logic [15:0] bmsr,
  input  logic [15:0] phyid_1,
  input  logic [15:0] phyid_2,
  input  logic        uart_rx,
  output logic        uart_tx
  // 
);

  function automatic [3:0] ascii2hex ();
    input bit [7:0] in;
    case (in)
      "0"      : ascii2hex = 4'h0;
      "1"      : ascii2hex = 4'h1;
      "2"      : ascii2hex = 4'h2;
      "3"      : ascii2hex = 4'h3;
      "4"      : ascii2hex = 4'h4;
      "5"      : ascii2hex = 4'h5;
      "6"      : ascii2hex = 4'h6;
      "7"      : ascii2hex = 4'h7;
      "8"      : ascii2hex = 4'h8;
      "9"      : ascii2hex = 4'h9;
      "a", "A" : ascii2hex = 4'ha;
      "b", "B" : ascii2hex = 4'hb;
      "c", "C" : ascii2hex = 4'hc;
      "d", "D" : ascii2hex = 4'hd;
      "e", "E" : ascii2hex = 4'he;
      "f", "F" : ascii2hex = 4'hf;
      default  : ascii2hex = 4'h0;
    endcase
  endfunction

  function automatic [7:0] hex2ascii ();
    input bit [3:0] in;
    case (in)
      4'h0 : hex2ascii = "0";
      4'h1 : hex2ascii = "1";
      4'h2 : hex2ascii = "2";
      4'h3 : hex2ascii = "3";
      4'h4 : hex2ascii = "4";
      4'h5 : hex2ascii = "5";
      4'h6 : hex2ascii = "6";
      4'h7 : hex2ascii = "7";
      4'h8 : hex2ascii = "8";
      4'h9 : hex2ascii = "9";
      4'ha : hex2ascii = "a";
      4'hb : hex2ascii = "b";
      4'hc : hex2ascii = "c";
      4'hd : hex2ascii = "d";
      4'he : hex2ascii = "e";
      4'hf : hex2ascii = "f";
    endcase
  endfunction

 // logic [7:0] string_ram [STRING_RAM_DEPTH**2-1:0];

  localparam PHYID1_STRING_LEN = 15;
  localparam PHYID2_STRING_LEN = 15;

  localparam [PHYID1_STRING_LEN-1:0][7:0] STRING_PHYID1 = "[PHY]: PHYID1: ";
  localparam [PHYID1_STRING_LEN-1:0][7:0] STRING_PHYID2 = "[PHY]: PHYID2: ";
  // localparam [] "[PHY]: Autonegotiation complete "
  // localparam [] "[PHY]: Autonegotiation complete "
  // localparam [] "[PHY]: Autonegotiation error "

  // eth_phyid0
  // eth_phyid1
  // eth_aneg_complete
  // eth_aneg_error
  // eth_speed_is_10
  // eth_speed_is_100
  // eth_speed_is_1000

  always_ff @ (posedge clk) begin

  end
  
  logic [7:0] uart_txd;
  logic [7:0] uart_rxd;
  
  logic uart_txv;
  logic uart_rxv;
  logic cts;

  uart uart_inst (
    .clk_rx    (clk),
    .clk_tx    (clk),
    .rst       (rst),
  
  	.rx        (uart_rx),
  	.tx        (uart_tx),
  
  	.txd       (uart_txd),
  	.txv       (uart_txv),
  
  	.rxd       (uart_rxd),
  	.rxv       (uart_rxv),
    .tx_active (),
    .rdy       (cts)
  );

  logic [PHYID1_STRING_LEN+4-1:0][7:0] cur_str;

  enum logic [7:0] {
    IDLE,
    SEND_STRING,
    NEW_LINE,
    CARRIAGE_RETURN
  } state;
  
  parameter int POLL_TICKS = 25000000;
  
  logic [$clog2(POLL_TICKS+1)-1:0] ctr_poll; 

  logic [3:0][7:0] cur_dat_ascii;

  logic [3:0][3:0] cur_dat;

  always_comb begin
    for (int i = 0; i < 4; i = i + 1) begin
      cur_dat_ascii[i] = hex2ascii(cur_dat[i]);
    end
  end

  assign cur_dat = phyid_1;
  
  logic [7:0] cur_idx;
  
  always_ff @ (posedge clk) begin
    if (rst) begin
      state <= IDLE;
    end
    else begin
      case (state)
        IDLE : begin
          uart_txv <= 0;
          cur_str <= {STRING_PHYID1, cur_dat_ascii};
          // cur_str <= STRING_PHYID1;
          cur_idx <= 0;
          if (ctr_poll == POLL_TICKS-1) begin
            state <= SEND_STRING;
            ctr_poll <= 0;
          end
          else ctr_poll <= ctr_poll + 1;
        end
        SEND_STRING : begin
          if (cts && !uart_txv) begin
            uart_txd <= cur_str[cur_idx];
            uart_txv <= 1;
            cur_idx <= cur_idx + 1;
          end else begin
            uart_txv <= 0;
          end
          if (cur_idx == PHYID1_STRING_LEN+4-1) state <= NEW_LINE; 
        end
        NEW_LINE : begin
          if (cts && !uart_txv) begin
            uart_txd <= 8'h0a;
            uart_txv <= 1;
            state <= CARRIAGE_RETURN;
          end
          else 
            uart_txv <= 0;
        end
        CARRIAGE_RETURN : begin
          if (cts && !uart_txv) begin
            uart_txd <= 8'h0d;
            uart_txv <= 1;
            state <= IDLE;
          end
          else 
            uart_txv <= 0;
        end
      endcase
    end
  end

endmodule