`define COLOR_RED "\x1b[31m"
`define COLOR_GREEN "\x1b[32m"
`define COLOR_RESET "\x1b[0m"

module wrap   
  import
    qnigma_chacha20_pkg::*;
(
  input  logic         clk,
  input  logic         rst,
  output logic [255:0] res,
  output logic         don
);

  // Test vector (RFC8439 2.3.2)
  parameter cha_non_t NONCE = {
    32'h00000009,
    32'h0000004a, 
    32'h00000000
  };

  parameter cha_key_t KEY = {
    32'h00010203,
    32'h04050607,
    32'h08090a0b,
    32'h0c0d0e0f,
    32'h10111213,
    32'h14151617,
    32'h18191a1b,
    32'h1c1d1e1f
  };

  parameter cha_ctr_t COUNTER = 
    32'h00000001
  ;

  parameter [15:0][31:0] TEST_VECTOR_ROUNDS = {
    32'h837778ab, 32'he238d763, 32'ha67ae21e, 32'h5950bb2f,
    32'hc4f2d0c7, 32'hfc62bb2f, 32'h8fa018fc, 32'h3f5ec7b7,
    32'h335271c2, 32'hf29489f3, 32'heabda8fc, 32'h82e46ebd,
    32'hd19c12b4, 32'hb04e16de, 32'h9e83d0cb, 32'h4e3c50a2
  };

  parameter cha_kst_blk_t TEST_VECTOR = {
    32'h4e3c50a2, 32'he883d0cb, 32'hb94e16de, 32'hd19c12b5,   
    32'ha2028bd9, 32'h05d7c214, 32'h09aa9f07, 32'h466482d2,  
    32'h4e6cd4c3, 32'h9aaa2204, 32'h0368c033, 32'hc7f4d1c7,  
    32'hc47120a3, 32'h1fdd0f50, 32'h15593bd1, 32'he4e7f110
  };
    

  enum logic [3:0] {
    INI,
    REMOVE_RESET,
    TEST_BLOCK_FUNCTION,
    TEST_CYPHERTEXT
  } state;

  logic req, val, run;

  cha_ada_t ada;
  cha_non_t non;
  cha_key_t key;
  cha_tag_t tag;
  cha_ctr_t bin;
  cha_kst_blk_t kst;

  // Keystream generator
  qnigma_math_chacha20_kst dut (
    .clk (clk),
    .rst (cha_rst),
    // .ini (ini),
    .req (req),
    .run (run),
    .val (val),
    .non (non),
    .key (key),
    .bin (bin),
    .tag (tag),
    .kst (kst)
  );

  parameter int PLAINTEXT_LENGTH = 114;

  parameter [PLAINTEXT_LENGTH-1:0][7:0] PLAINTEXT = 
    "Ladies and Gentlemen of the class of '99: If I could offer you only one tip for the future, sunscreen would be it.";

  logic [7:0] ctr;
  logic       cha_rst;

  always_ff @ (posedge clk) begin
    if (rst) begin
      state   <= INI;
      cha_rst <= 1;
      bin <= COUNTER;
      // err_ctr <= 0;
    end
    else begin
      case (state)
        INI : begin
          $display("Performing ChaCha20 verification [RFC8439]");
          state <= REMOVE_RESET;
          ada <= 0;
          non <= NONCE;
          key <= KEY;
          // vi <= 1;
          don <= 0;
          cha_rst <= 0;
          ctr <= 0;
        end
        REMOVE_RESET : begin
          ctr <= ctr + 1;
          if (ctr == 100) begin
            req     <= 1;
            state   <= TEST_BLOCK_FUNCTION;
            cha_rst <= 0;
          end
        end
        TEST_BLOCK_FUNCTION : begin
          req <= 0;
          if (val) begin
            state <= TEST_CYPHERTEXT;
            $display("Result after 20 rounds:");
            display_chacha_key (kst);
            $write("Comparing with test vector...");
            if (kst == TEST_VECTOR) begin
              $write(`COLOR_GREEN);
              $write("[PASS]");
              $display(`COLOR_RESET);
            end
            else begin
              $write(`COLOR_RED);
              $write("[FAIL]");
              $display(`COLOR_RESET);
            end
          end
          // state <= INI;
        end
        TEST_CYPHERTEXT : begin
            don <= 1;
        end
        default :;
      endcase
    end
  end

endmodule : wrap
