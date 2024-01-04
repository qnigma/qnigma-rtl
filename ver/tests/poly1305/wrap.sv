module wrap
  import
    color_pkg::*,
    qnigma_math_pkg::*,
    qnigma_crypt_pkg::*,
    qnigma_poly1305_pkg::*,
    qnigma_chacha20_pkg::*;
(
  input  logic clk,
  input  logic rst,
  output logic don
);
  
  localparam MESSAGE_LENGTH = 34;

  localparam [MESSAGE_LENGTH-1:0][7:0] MESSAGE        = "Cryptographic Forum Research Group";
  localparam poly_tag_t                TESTVECTOR_TAG = {8'ha8, 8'h06, 8'h1d, 8'hc1, 8'h30, 8'h51, 8'h36, 8'hc6, 8'hc2, 8'h2b, 8'h8b, 8'haf, 8'h0c, 8'h01, 8'h27, 8'ha9};
  localparam key_t                     KEY            = 256'h85d6be7857556d337f4452fe42d506a80103808afb0db2fd4abff6af4149f51b;

  enum logic [1:0] {
    SEND,
    CHECK
  } state;
  
  logic [31:0] tx_ctr;

  parameter int TB_BLOCKS   = 8;
  parameter int MAX_BLOCKS  = 8;
  
  poly_blk_t [TB_BLOCKS-1:0][MAX_BLOCKS-1:0] check_block_dat;
  logic      [TB_BLOCKS-1:0][          31:0] check_block_num;

  logic       vin;
  logic       val;
  logic       sof;
  logic       eof;
  logic       cts;
  logic       lst;
  logic [7:0] din;

  poly_blk_t  tag;
  logic       tag_val;

  always_ff @ (posedge clk) begin
    if (rst) begin
      don <= 0;
      state <= SEND;
      tx_ctr <= MESSAGE_LENGTH-1;
    end
    else begin
      case (state)
        SEND  : begin
          if (cts & !lst) begin // If last, deassert vin next tick
            tx_ctr <= tx_ctr - 1; 
            din    <= MESSAGE[tx_ctr];
            vin    <= 1;
            sof    <= tx_ctr == MESSAGE_LENGTH-1;
            eof    <= tx_ctr == 0;
          end
          else begin
            vin    <= 0;
            sof    <= 0;
            eof    <= 0;
          end
          if (tx_ctr == 0) state <= CHECK;
       //  $display("Sending %d byte of data", tx_len);
        end
        CHECK : begin
          vin <= 0;
          eof <= 0;
          sof <= 0;
          if (tag_val) begin
            don <= 1;
            $display("Comparing tag with reference [RFC8439]... ");
            $display("Poly1305 Tag calculated: %x", tag);
            $display("Poly1305 Tag testvector: %x", TESTVECTOR_TAG);
            if (tag == TESTVECTOR_TAG) begin
              display_pass();
            end
            else begin
              display_fail();
            end
          end
        end
        default :;
      endcase
    end
  end

  logic [W-1:0] alu_opa;
  logic [W-1:0] alu_opb;
  logic         alu_cal;
  logic         alu_eql;

  logic [W-1:0] alu_res;
  logic         alu_rdy;


  logic alu_add;
  logic alu_mul;
  
  pri_t alu_fld;

  assign alu_fld = F1305;

  qnigma_poly1305 dut (
    .clk      (clk),
    .rst      (rst),

    .din      (din),
    .vin      (vin),
    .sof      (sof),
    .eof      (eof),
    .cts      (cts),
    .lst      (lst),

    .key      (KEY),

    .alu_opa  (alu_opa), // current accumulator 
    .alu_opb  (alu_opb), // current block
    .alu_add  (alu_add), // Operation to MAU
    .alu_mul  (alu_mul), // Operation to MAU
    .alu_cal  (alu_cal), // request to calculate

    .alu_res  (alu_res),
    .alu_rdy  (alu_rdy),
    .tag      (tag),
    .tag_val  (tag_val)
  );

  qnigma_alu alu_inst (
    .clk (clk    ),
    .rst (rst    ),
    .fld (alu_fld),
    .opa (alu_opa),
    .opb (alu_opb),
    .mul (alu_mul),
    .add (alu_add),
    .sub (0      ),
    .inv (0      ),
    .cal (alu_cal),
    .res (alu_res),
    .eql (alu_eql),
    .rdy (alu_rdy)
  );

endmodule
