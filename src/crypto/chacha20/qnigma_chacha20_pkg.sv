package qnigma_chacha20_pkg;

  // Variable lengths (all are N 32-bit words) 
  parameter int ROUNDS          = 20; // Total rounds
  parameter int ADATA_WORDS     = 4;  // 
  parameter int NONCE_WORDS     = 3;
  parameter int KEY_WORDS       = 8;
  parameter int DATA_WORDS      = 8;
  parameter int TAG_WORDS       = 4;
  parameter int WORD_SIZE       = 32;
  parameter int WORDS = 16;
  
  // Initialization constants
  parameter [31:0] CONST0 = 32'h61707865;
  parameter [31:0] CONST1 = 32'h3320646e;
  parameter [31:0] CONST2 = 32'h79622d32;
  parameter [31:0] CONST3 = 32'h6b206574;
  
  // Types (ChaCha20)
  typedef bit [WORD_SIZE-1:0] word_t; // Associated Data

  typedef bit [ADATA_WORDS-1:0][WORD_SIZE-1:0] cha_ada_t; // Associated Data
  typedef bit [NONCE_WORDS-1:0][WORD_SIZE-1:0] cha_non_t; // Nonce
  typedef bit [  KEY_WORDS-1:0][WORD_SIZE-1:0] cha_key_t; // Secret key
  typedef bit [  TAG_WORDS-1:0][WORD_SIZE-1:0] cha_tag_t; // Tag
  typedef bit                  [WORD_SIZE-1:0] cha_ctr_t; // Block counter
  typedef bit [WORDS -1:0]     [WORD_SIZE-1:0] cha_kst_blk_t; // Keystream

  // display functions for simulation
  task display_chacha_key ();
    input cha_kst_blk_t kst;
    for (int i = 0; i < 16; i = i + 4) $write("        %x  %x  %x  %x\n", kst[i], kst[i+1], kst[i+2], kst[i+3]);
  endtask

  // display functions for simulation
  // task display_chacha_state ();
  //   input [15:0][WORD_SIZE-1:0] state;
  //   for (int i = 0; i < 16; i = i + 4) $write("        %x  %x  %x  %x\n", kst[i], kst[i+1], kst[i+2], kst[i+3]);
  // endtask

  // Keystream buffer settings
  parameter int DATA_WIDTH = 8; // Data interface width
  
  parameter int KEYSTREAM_BUFFER_BLOCKS     = 4; // Amount of 512-bit blocks stored in buffer
  parameter int KST_BUF_BLK_BITS = $clog2(KEYSTREAM_BUFFER_BLOCKS); // Amount of 512-bit blocks stored in buffer

  parameter int KST_RAM_WIDTH   = 32; // Block RAM width 
  parameter int KST_ENT_PER_BLK = $bits(cha_kst_blk_t)/KST_RAM_WIDTH; 
  
  parameter int KST_RAM_WRD_BITS      = $clog2(KST_ENT_PER_BLK);
  parameter int KEYSTREAM_RAM_ENTRIES = KST_ENT_PER_BLK*KEYSTREAM_BUFFER_BLOCKS;
  parameter int KST_RAM_DEPTH         = $clog2(KEYSTREAM_RAM_ENTRIES);

  
  parameter int KST_WORDS_PER_BLOCK_BITS = KST_RAM_WIDTH/DATA_WIDTH;

endpackage : qnigma_chacha20_pkg