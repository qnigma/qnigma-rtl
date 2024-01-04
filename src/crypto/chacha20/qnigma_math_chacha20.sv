/*

 +--------------------+
 |  Keystream buffer  |
 +-^-----^-------------+
   |blk_*|
 +-v-----v--------------+
 |  ChaCha20 block gen  |
 +---|||----------------+
key>-+||
non>--+|
ini>---+

 +--------------------+
 |  Keystream buffer  |
 +--------------------+

*/

module qnigma_math_chacha20
  import
    qnigma_chacha20_pkg::*;
(
  input  logic                  clk  ,
  input  logic                  rst  , // Hold reset high until start using the core
  input  logic                  ena  , // Hold reset high until start using the core
  // Input data stream
  input  logic [DATA_WIDTH-1:0] dat_i,
  input  logic                  val_i,
  input  logic                  sof_i,
  input  logic                  eof_i,
  output logic                  cts_i,
  // Output data stream
  output logic [DATA_WIDTH-1:0] dat_o,
  output logic                  val_o,
  output logic                  sof_o,
  output logic                  eof_o,
  input  cha_key_t              key  , // Key
  input  cha_non_t              non  , // Nonce
  input  cha_ctr_t              ini    // Initial Block Counter
);

  logic blk_nxt, blk_val, blk_run;

  cha_tag_t tag;
  cha_ctr_t bin;
  cha_kst_blk_t blk_kst;

  // Keystream generation
  qnigma_math_chacha20_kst math_chacha20_kst_tx_inst (
    .clk (clk    ),
    .rst (rst    ),
    .req (blk_nxt), // Accept new keystream request 
    .val (blk_val), // Keystream valid
    .kst (blk_kst), // Keystream block value
    .run (blk_run), // Keystream block calculation in progress
    .non (non    ), // Nonce
    .key (key    ), // Current key
    .bin (ini    ),
    .tag (tag    )
  );

  // Nonce handling
  // math_chacha20_nonce math_chacha20_nonce_inst (
  //   .clk (clk    ),
  //   .rst (~ena   ),
  //   .nxt (nxt_non), // Request next nonce value
  //   .non (non    ), // Current nonce
  //   .val (non_val) // Nonce valid
  // );

  logic read;
  logic buf_rdy;
  logic load_done;
  logic val_r;
  
  logic [KST_WORDS_PER_BLOCK_BITS-1:0][DATA_WIDTH-1:0] kst_dat;

  logic [$clog2(KST_WORDS_PER_BLOCK_BITS)-1:0] ctr_req;
  logic [$clog2(KST_WORDS_PER_BLOCK_BITS)-1:0] ctr_xor;
  logic rea_prev;

  // Buffer ChaCha20 keystream 
  qnigma_math_chacha20_buf math_chacha20_kst_buf_inst (
    .clk     (clk    ),
    .rst     (rst    ),
    .blk_nxt (blk_nxt), // Accept Request for next block
    .blk_run (blk_run), // Block generation in progress
    .blk_kst (blk_kst), // Output keystream block data (512 bits)
    .blk_val (blk_val), // Output Keystream block valid
    .rdy     (buf_rdy), // Buffer has keystream, can accept data
    .str     (kst_dat), // Serialized keystream 
    .read    (read   )
  );

  assign cts_i = buf_rdy;

  always_ff @ (posedge clk) begin
    ctr_xor <= ctr_req; // RAM output is still too wide for target interface

    if (rst  ) ctr_req <= 0;
    if (val_i) ctr_req <= ctr_req + 1;

    val_r <= val_i;
    val_o <= val_r;
  end

  always_ff @ (posedge clk) begin
    if      (rst ) load_done <= 0;
    else if (read) load_done <= 1;
  end

  assign read = val_i && (ctr_req == KST_WORDS_PER_BLOCK_BITS-1);

  always_ff @ (posedge clk) begin
    rea_prev <= read;
    // if (rea_prev) $display("READ %x", kst_dat);
  end

  // always_ff @ (posedge clk) begin
  //   if (read && ) begin
  //     ctr_rea <= 0;
  //     val_o   <= 1;
  //   end
  //   else if (ctr_rea != KST_WORDS_PER_BLOCK_BITS-1) ctr_rea <= ctr_rea + 1;
  //   else ctr_rea <= 0;
  // end
  
  logic [DATA_WIDTH-1:0] dat_r;
  logic [DATA_WIDTH-1:0] dat_c;
  
  always_ff @ (posedge clk) dat_r <= dat_i;
  
  assign dat_c = kst_dat[ctr_xor];

  always_ff @ (posedge clk) dat_o <= dat_r ^ dat_c;

  // Buffer ChaCha20 keystream 
  // math_chacha20_dat_buf math_chacha20_dat_buf_inst (
  //   .clk (clk    ),
  //   .rst (~ena   ),
  //   .req (req    )
  // );

  // always_ff @ (posedge clk) begin
  //   if (rst) begin
  //     otk_rdy <= 0;
  //   end
  //   else if (val && !otk_rdy) begin
  //     otk     <= kst;
  //     otk_rdy <= 1;
  //   end
  // end

endmodule
