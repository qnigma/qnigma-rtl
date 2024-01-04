/* 
 * ChaCha20 Quarter Round and Add
 * This module is capable of 2 operations 
 * 1. Compute quarter round in 8 clock cycles 
 * 2. Compute 2 sums (a + b)
 * 
 */
module qnigma_math_chacha20_qround (
  input  logic        clk,
  input  logic        rst,
  input  logic        run,

  input  logic [31:0] a, 
  input  logic [31:0] b, 
  output logic [31:0] q, 

  input  logic [31:0] a_i, 
  input  logic [31:0] b_i, 
  input  logic [31:0] c_i, 
  input  logic [31:0] d_i,

  output logic [31:0] a_o, 
  output logic [31:0] b_o, 
  output logic [31:0] c_o, 
  output logic [31:0] d_o
);

  enum logic [7:0] {a0, d0, c1, b1, a2, d2, c3, b3} s;
  
  // Rolled values
  logic [31:0] xor16;
  logic [31:0] xor12;
  logic [31:0] xor8 ;
  logic [31:0] xor7 ;

  assign q = add_q;
  
  always_comb begin
    xor16 = {xor_q[15:0], xor_q[31:16]};
    xor12 = {xor_q[19:0], xor_q[31:20]};
    xor8  = {xor_q[23:0], xor_q[31:24]};
    xor7  = {xor_q[24:0], xor_q[31:25]};
  end

  always_ff @ (posedge clk) begin
    if (rst) begin
      s <= a0;
      a_o <= a_i;
      b_o <= b_i;
      c_o <= c_i;
      d_o <= d_i;
    end
    else if (run) begin
      case (s)
        a0 : begin s <= d0; a_o <= add_q; end
        d0 : begin s <= c1; d_o <= xor16; end
        c1 : begin s <= b1; c_o <= add_q; end
        b1 : begin s <= a2; b_o <= xor12; end
        a2 : begin s <= d2; a_o <= add_q; end
        d2 : begin s <= c3; d_o <= xor8 ; end
        c3 : begin s <= b3; c_o <= add_q; end
        b3 : begin s <= a0; b_o <= xor7 ; end
        default :;
      endcase
    end
  end

  always_comb begin
    if (run) begin
      case (s)
        a0      : begin add_a = a_o; add_b = b_o; end
        c1      : begin add_a = c_o; add_b = d_o; end
        a2      : begin add_a = a_o; add_b = b_o; end
        c3      : begin add_a = c_o; add_b = d_o; end
        default : begin add_a = a_o; add_b = b_o; end
      endcase
    end
    else begin
      add_a = a;
      add_b = b;
    end
  end

  always_comb begin
    case (s)
      d0      : begin xor_a = a_o; xor_b = d_o; end
      b1      : begin xor_a = c_o; xor_b = b_o; end
      d2      : begin xor_a = a_o; xor_b = d_o; end
      b3      : begin xor_a = c_o; xor_b = b_o; end
      default : begin xor_a = a_o; xor_b = b_o; end
    endcase
  end

  logic [31:0] add_a;
  logic [31:0] add_b;
  logic [31:0] add_q;
  
  logic [31:0] xor_a;
  logic [31:0] xor_b;
  logic [31:0] xor_q;

  qnigma_math_chacha20_add #(.W (32), .R (0)) add_i (
    .clk (clk),
    .a   (add_a),
    .b   (add_b),
    .q   (add_q)
  );

  qnigma_xor #(.W (32)) xor_i (
    .a  (xor_a),
    .b  (xor_b),
    .q  (xor_q)
  );

endmodule
