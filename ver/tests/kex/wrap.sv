module wrap 
  import
    color_pkg::*,
    qnigma_crypt_pkg::*,
    qnigma_math_pkg::*,
    qnigma_chacha20_pkg::*;
(
  input  logic        clk,
  input  logic        rst,
  output logic [31:0] res,
  output logic        don
);
  
  parameter int W = 256;
  parameter int RESET_TICKS = 100;

  enum logic [7:0] {
    idle_s,
    // Alice pub
    ALICE_PREP,
    ALICE_CALC,
    ALICE_READ_REQ_PUB,
    ALICE_READ_PUB,
    ALICE_CHECK_PUB,
    // Bob pub
    BOB_PREP,
    BOB_CALC,
    BOB_READ_REQ_PUB,
    BOB_READ_PUB,
    BOB_CHECK_PUB,
    // Alice shared
    PREP_SHARED_ALICE,
    LOAD_SHARED_ALICE,
    CALC_SHARED_ALICE,
    ALICE_READ_REQ_SHARED,
    ALICE_READ_SHARED,
    ALICE_CHECK_SHARED,
    // Bob shared
    PREP_SHARED_BOB,
    LOAD_SHARED_BOB,
    CALC_SHARED_BOB,
    BOB_READ_REQ_SHARED,
    BOB_READ_SHARED,
    BOB_CHECK_SHARED,
    done_s
  } state;

  logic [W-1:0] scalar;
  logic start, ready;
  logic [31:0] ticks;
  logic [$clog2(RESET_TICKS+1)-1:0] ctr_rst;
  logic [31:0][7:0]         u_base;   // Base point X-coordinate for EC scalar multiplcation
  logic [W-1:0]             u_result; // Result U-coordinate

  logic                     generator;  // Ignore u_base, use Curve25510 generator

  pri_t                     alu_fld;  // ALU field selection. Always P25519 in this test
  logic                     alu_eql;

  logic [4:0] load_ctr;
  logic [4:0] ctr_read;

  logic alu_cal;
  logic alu_opa_res;
  logic alu_opb_res;
  logic alu_add;
  logic alu_sub;
  logic alu_mul;
  logic alu_inv;

  fld_t ext_rd_fld;

  wrd_t ext_wr_dat;
  ptr_t ext_wr_ptr;
  logic ext_wr_val;
  logic ext_wr_sof;

  logic ext_rd_req;
  logic ext_rd_nxt;
  wrd_t ext_rd_dat;
  ptr_t ext_rd_ptr;
  logic ext_rd_val;

  //////////////////////////
  // Test vectors RFC7748 //
  //////////////////////////
   parameter [255:0] ECDHKE_U_COORD    = 256'h9;
   parameter [255:0] PRIVATE_KEY_ALICE = 256'h77076d0a7318a57d3c16c17251b26645df4c2f87ebc0992ab177fba51db92c2a;
   parameter [255:0] PUBLIC_KEY_ALICE  = 256'h8520f0098930a754748b7ddcb43ef75a0dbf3a0d26381af4eba4a98eaa9b4e6a;

   parameter [255:0] PRIVATE_KEY_BOB   = 256'h5dab087e624a8a4b79e17f8b83800ee66f3bb1292618b6fd1c2f8b27ff88e0eb;
   parameter [255:0] PUBLIC_KEY_BOB    = 256'hde9edb7d7b7dc1b4d35b61c2ece435373f8343c85b78674dadfc7e146f882b4f;

   parameter [255:0] SHARED_SECRET     = 256'h4a5d9d5ba4ce2de1728e3bf480350f25e07e21c947d19e3376f09b3c1e161742;

   //Input scalar as a number (base 10):
   parameter [255:0] SCALAR_IN_DEC = 256'd31029842492115040904895560451863089656472772604678260265531221036453811406496;
   //Input u-coordinate:
  //  parameter [255:0] U_COORD_IN = 256'he6db6867583030db3594c1a424b15f7c726624ec26b3353b10a903a6d0ab1c4c;
   parameter [255:0] U_COORD_IN = 256'h9;
  //  parameter [255:0] U_COORD_IN = 256'h0900000000000000000000000000000000000000000000000000000000000000;
   //Input u-coordinate as a number (base 10):
   parameter [255:0] U_COORD_IN_DEC = 256'd34426434033919594451155107781188821651316167215306631574996226621102155684838;
   //Output u-coordinate:
   parameter [255:0] U_COORD_OUT = 256'hc3da55379de9c6908e94ea4df28d084f32eccf03491c71f754b4075577a28552;

  always_ff @ (posedge clk) begin
    if (rst) begin
      state <= idle_s;
      ctr_rst <= 0;
      don <= 0;
    end
    else begin
      case (state)
        idle_s : begin  
          ctr_rst <= ctr_rst + 1; 
          if (ctr_rst == RESET_TICKS) begin
            state <= ALICE_PREP;
          end
        end
        ///////////////////////////////
        // Generate Alice Public Key //
        ///////////////////////////////
        ALICE_PREP : begin // Prepare Alice side
          $display("============================\n");
          $display("Performing ECDH verification\n");
          $display("============================\n");
          $display("Calculating Alice pub from priv: %x", PRIVATE_KEY_ALICE);
          start       <= 1; // Request multiplcation using generator and decoded private key
          scalar    <= dec_scalar_25519(PRIVATE_KEY_ALICE);
          generator <= 1;
          ticks     <= 0;
          state     <= ALICE_CALC;
        end
        ALICE_CALC : begin // Don't load point (use base). Start multiplcation...
          start <= 0;
          ticks <= ticks + 1;
          if (ready) begin
            $display("Core ready. Total execution ticks: %d", ticks);
            state <= ALICE_READ_REQ_PUB;
          end
        end
        ALICE_READ_REQ_PUB : begin // Request readout
          ext_rd_req   <= 1;
          ctr_read <= 0;
          state    <= ALICE_READ_PUB;
        end
        ALICE_READ_PUB : begin
          ext_rd_req <= 0;
          if (ext_rd_val) begin
            u_result <= {ext_rd_dat, u_result[W-1:POINT_IFC_BITS]};
            ctr_read <= ctr_read + 1;
          end
          if (ext_rd_eof) state <= ALICE_CHECK_PUB;
        end
        ALICE_CHECK_PUB : begin
          $display("Got Alice public key: %x. ", dec_litte_endian(u_result));
          if (dec_litte_endian(u_result) == PUBLIC_KEY_ALICE) display_pass(); else display_fail();
          state <= BOB_PREP;
        end
        /////////////////////////////
        // Generate Bob Public Key //
        /////////////////////////////
        BOB_PREP : begin
          $display("Calculating Bob pub from priv: %x", PRIVATE_KEY_BOB);

          start <= 1;
          scalar  <= dec_scalar_25519(PRIVATE_KEY_BOB);
          generator <= 1;
          ticks   <= 0;
          state   <= BOB_CALC;
        end
        BOB_CALC : begin
          start <= 0;
          ticks <= ticks + 1;
          if (ready) begin
            $display("Core ready. Total execution ticks: %d", ticks);
            state <= BOB_READ_REQ_PUB;
          end
        end
        BOB_READ_REQ_PUB : begin // Request readout
          ext_rd_req   <= 1;
          ctr_read <= 0;
          state    <= BOB_READ_PUB;
        end
        BOB_READ_PUB : begin
          ext_rd_req <= 0;
          if (ext_rd_val) begin 
            u_result <= {ext_rd_dat, u_result[W-1:POINT_IFC_BITS]};
            ctr_read <= ctr_read + 1;
          end
          if (ext_rd_eof) state <= BOB_CHECK_PUB;
        end
        BOB_CHECK_PUB : begin
          $display("Got Bob public key: %x. ", dec_litte_endian(u_result));
          if (dec_litte_endian(u_result) == PUBLIC_KEY_BOB) display_pass(); else display_fail();
          state <= PREP_SHARED_ALICE;
        end
        //////////////////////////////////
        // Generate Alice shared secret //
        //////////////////////////////////
        PREP_SHARED_ALICE : begin
          $display("Calculating shared at Alice: %x", PUBLIC_KEY_BOB);
          u_base <= dec_litte_endian(PUBLIC_KEY_BOB);
          scalar  <= dec_scalar_25519(PRIVATE_KEY_ALICE);
          generator  <= 0;
          ticks <= 0;
          state <= LOAD_SHARED_ALICE;
        end
        LOAD_SHARED_ALICE : begin
          ext_wr_dat <= u_base[load_ctr];
          ext_wr_val <= 1;
          load_ctr <= load_ctr + 1;
          if (load_ctr == WORDS_PER_OPER - 1) begin
            load_ctr <= 0;
            start <= 1;
            state <= CALC_SHARED_ALICE;
          end
        end
        CALC_SHARED_ALICE : begin
          ext_wr_val <= 0;
          start <= 0;
          ticks <= ticks + 1;
          if (ready) begin
            $display("Core ready. Total execution ticks: %d", ticks);
            state <= ALICE_READ_REQ_SHARED;
          end
        end
        ALICE_READ_REQ_SHARED : begin // Request readout
          ext_rd_req   <= 1;
          ctr_read <= 0;
          state    <= ALICE_READ_SHARED;
        end
        ALICE_READ_SHARED : begin
          ext_rd_req <= 0;
          if (ext_rd_val) begin
            u_result <= {ext_rd_dat, u_result[W-1:POINT_IFC_BITS]};
            ctr_read <= ctr_read + 1;
          end
          if (ext_rd_eof) state <= ALICE_CHECK_SHARED;
        end
        ALICE_CHECK_SHARED : begin
          $display("Got Alice shared secret: %x. ", dec_litte_endian(u_result));
          if (dec_litte_endian(u_result) == SHARED_SECRET) display_pass(); else display_fail();
          state <= PREP_SHARED_BOB;
        end
        ////////////////////////////////
        // Generate Bob shared secret //
        ////////////////////////////////
        PREP_SHARED_BOB : begin
          u_base  <= dec_litte_endian(PUBLIC_KEY_ALICE);
          scalar  <= dec_scalar_25519(PRIVATE_KEY_BOB);
          generator <= 0;
          ticks   <= 0;
          state   <= LOAD_SHARED_BOB;
        end
        // Use the ui_* interface to serialize data in the DUT
        LOAD_SHARED_BOB : begin
          ext_wr_dat <= u_base[load_ctr];
          ext_wr_val <= 1;
          load_ctr <= load_ctr + 1;
          if (load_ctr == WORDS_PER_OPER - 1) begin
            load_ctr <= 0;
            start <= 1;
            state <= CALC_SHARED_BOB;
            // chk_point <= 1;
          end
        end
        CALC_SHARED_BOB : begin
          ext_wr_val <= 0;
          start <= 0;
          ticks <= ticks + 1;
          if (ready) begin
            $display("Core ready. Total execution ticks: %d", ticks);
            state <= BOB_READ_REQ_SHARED;
          end
        end
        BOB_READ_REQ_SHARED : begin // Request readout
          ext_rd_req   <= 1;
          ctr_read <= 0;
          state    <= BOB_READ_SHARED;
        end
        BOB_READ_SHARED : begin
          ext_rd_req <= 0;
          if (ext_rd_val) begin
            u_result <= {ext_rd_dat, u_result[W-1:POINT_IFC_BITS]};
            ctr_read <= ctr_read + 1;
          end
          if (ext_rd_eof) state <= BOB_CHECK_SHARED;
        end
        BOB_CHECK_SHARED : begin
          $display("Got Bob shared secret: %x. ", dec_litte_endian(u_result));
          if (dec_litte_endian(u_result) == SHARED_SECRET) display_pass(); else display_fail();
          don <= 1;
        end
        default :;
      endcase
    end
  end

  assign alu_fld = F25519;
  
  task_t task_info;
  logic task_done;
  logic task_valid;
  logic ext_rd_eof;

  qnigma_alu alu_inst (
    .clk        (clk          ),
    .rst        (rst          ),
    .task_info  (task_info    ),
    .task_valid (task_valid   ),
    .task_done  (task_done    ),
    .alu_eql    (alu_eql      ),

    .ext_wr_dat (ext_wr_dat   ),
    .ext_wr_ptr (ext_wr_ptr   ),
    .ext_wr_val (ext_wr_val   ),
    .ext_wr_sof (ext_wr_sof   ),
    .ext_rd_fld (ext_rd_fld   ),
    .ext_rd_req (ext_rd_req   ),
    .ext_rd_nxt (ext_rd_nxt   ),
    .ext_rd_ptr (ext_rd_ptr   ),
    .ext_rd_dat (ext_rd_dat   ),
    .ext_rd_val (ext_rd_val   ),
    .ext_rd_eof (ext_rd_eof   )
  );
  
  math_ecp_25519 ecp_inst (
    .clk        (clk          ),
    .rst        (rst          ),

    .generator  (generator    ),    // Flag, use generator as base point
    .scalar     (scalar       ),       // Scalar to multiply by
    .start      (start        ),        // Strobe, request mult
    .ready      (ready        ),        // Strobe, multiplication complete
    .task_info  (task_info    ),    // Strobe, multiplication complete
    .task_valid (task_valid   ),  // Strobe, multiplication complete
    .task_done  (task_done    )  // Strobe, multiplication complete
  );
 
endmodule
