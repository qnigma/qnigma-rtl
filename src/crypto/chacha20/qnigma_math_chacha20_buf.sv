// Handles precalculated keystream storage
// When not full, always fetch new keystream block and load it into RAM 
// Readout the keystream when new data arrives
// - Keystream block = 512-bit ChaCha20 keystream block
// - Keystream word = Serialized Keystream block to width of KST_RAM_WIDTH


// RAM structure:
/*
 


  W-1      0      
  +--------+
  |        |
  +--------+
  |        |
  +--------+
  |        |
  +--------+
  |        |
  +--------+
  |        |
  +--------+

*/
module qnigma_math_chacha20_buf
  import
    qnigma_chacha20_pkg::*;
(
  input  logic                 clk,
  input  logic                 rst,
  // ChaCha20 block generation
  output logic                 blk_nxt,  // Request next keysteam block generation at blk 
  input  logic                 blk_run,  // ChaCha20 block generation running 
  input  cha_kst_blk_t         blk_kst,  // Keystream block value
  input  logic                 blk_val,  // Keystream block valid
  // Keystream
  output logic                     rdy,  // Ready to output keystream
  input  logic                     read, // Read request for 1 word
  output logic [KST_RAM_WIDTH-1:0] str   // Keystream output 1-tick after 'read'
);

  cha_kst_blk_t cur_blk_wr; // Current block shiftregister being written

  logic [KST_BUF_BLK_BITS:0] blk_idx_wr; // block index writing to (1 extra bit for full/empty flags)
  logic [KST_BUF_BLK_BITS:0] blk_idx_rd; // block index reading from (1 extra bit for full/empty flags)

  logic [KST_BUF_BLK_BITS-1:0] blk_adr_wr;
  logic [KST_BUF_BLK_BITS-1:0] blk_adr_rd;
  
  // Word index being written inside keystream block
  logic [KST_RAM_WRD_BITS-1:0] word_adr_wr;   
  logic [KST_RAM_WRD_BITS-1:0] word_adr_rd;

  logic [KST_BUF_BLK_BITS:0] num_blocks;

  logic full;
  logic write;
  logic blk_pend;

  logic [KST_RAM_DEPTH-1:0] ram_addr_write;
  logic [KST_RAM_DEPTH-1:0] ram_addr_read;
  logic [KST_RAM_DEPTH  :0] idx_rd;

  logic [KST_RAM_WIDTH-1:0] ram_data_write;

  // Serialize block {512-bits} to RAM data width
  qnigma_piso #(
    .WIDTH (KST_RAM_WIDTH),
    .LENGTH ($bits(cha_kst_blk_t)/KST_RAM_WIDTH)
  ) qnigma_piso_inst (
    .clk   (clk),
    .set   (blk_val),   // New block written
    .par_i (blk_kst),   // Load new block
    .shift (write),     // Provide new eord to 'ser_o'
    .ser_o (ram_data_write) // Serialized block to be written to RAM
  );

  ///////////////////////////
  // Keystream RAM control //
  ///////////////////////////
  logic [KST_RAM_WIDTH-1:0] ram [KEYSTREAM_RAM_ENTRIES-1:0];

  // Write port
  always_ff @ (posedge clk) begin : proc_ram_wr
    if (write) ram[ram_addr_write] <= ram_data_write;
  end

  // Read port
  always_ff @ (posedge clk) begin : proc_ram_rd
    str <= ram[ram_addr_read];
  end

  // Increment read address
  always_ff @ (posedge clk) begin : proc_adr_rd
    if      (rst  ) idx_rd <= 0;
    else if (read ) idx_rd <= idx_rd + 1;
  end

  assign blk_idx_rd    = idx_rd[KST_RAM_DEPTH:KST_RAM_WRD_BITS];
  assign word_adr_rd   = idx_rd[KST_RAM_WRD_BITS-1:0];
  assign ram_addr_read = idx_rd[KST_RAM_DEPTH-1:0];

  // assign idx_rd = blk_idx_rd[KST_RAM_DEPTH-1:KST_RAM_WRD_BITS];

  // Serialize keystream block into words at write side
  always_ff @ (posedge clk) begin
    if (blk_val) // New block valid 
      write <= 1; // Start loading word-by-word
    else if (word_adr_wr == '1) // All words written
      write <= 0;
  end
  
  // Increment write address with each word written
  always_ff @ (posedge clk) begin
    if (rst)
      word_adr_wr <= 0;
    else if (write)
      word_adr_wr <= word_adr_wr + 1;
  end

  // RAM adderss is a concatenation of block index and word position
  assign ram_addr_write = {blk_adr_wr, word_adr_wr};
  assign blk_adr_wr = blk_idx_wr[KST_BUF_BLK_BITS-1:0];
  //assign blk_adr_rd = blk_idx_rd[KST_BUF_BLK_BITS-1:0];

  // Ready to accept next block when 

  assign rdy  = (num_blocks != 0); // keystream buffered and ready if any data is stored
  assign full = (num_blocks[KST_BUF_BLK_BITS] == 1); // buffer full 


  always_ff @ (posedge clk) begin
    if (rst) blk_nxt <= 0;
    else if (!full && !blk_run && !blk_nxt) begin // If buffer is not full and ChaCha20 is not busy...
      blk_nxt <= 1;                               // Send request to calculate next block
    end
    else blk_nxt <= 0;
  end

  always_ff @ (posedge clk) begin
    if      (rst) blk_idx_wr <= 0;
    else if (next_wr) blk_idx_wr <= blk_idx_wr + 1;
  end 

  // Difference between write and read address (amount of entries used)
  assign num_blocks = blk_idx_wr - blk_idx_rd;

  always_ff @ (posedge clk) begin
    if (blk_val) begin
      $display("ChaCha20 keystream block calculated:");
      display_chacha_key(blk_kst);
    end
  end

  always_ff @ (posedge clk) begin
    if (write) begin
      // $display("writing data at %x: %x", ram_addr_write, ram_data_write);
    end
  end

  // When block is ready, assert the flag
  // When it's written, deassern 
  // When buffer gets filled, we can precompute 1 block
  // And we wait untill a block is read to immediately write the block
  always_ff @ (posedge clk) begin
    if      (blk_val) blk_pend <= 1; // If block is received, 
    else if (next_wr) blk_pend <= 0;
  end
 
  logic blk_done;
  assign blk_done = (word_adr_wr == '1);

  logic next_wr;
  assign next_wr = blk_done && write;

endmodule
