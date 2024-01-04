// generates MAC over entire message
// does not include a buffer, cts means able to accept least 1 byte
// message is split into 64-byte blocks plus last block that is at most 64 bytes
// procedure:
// 1. SOF is detected on input stream - meaning a new packet:
//    a. set accumulator to 0
//    b. reset eof pending since new packet started
// 2. sssemble message as in a byte-reversed manner 
//    with 0x01 terminator and 0x00 padding
//    Start with n = 0. Treat data as data stream :

// Once 64 bytes of data have been accepted, perform add, then multiply, repeat for all blocks

module qnigma_poly1305
  import
    qnigma_math_pkg::*,
    qnigma_crypt_pkg::*,
    qnigma_chacha20_pkg::*,
    qnigma_poly1305_pkg::*;
(
  input  logic                      clk,
  input  logic                      rst,

  input  logic [7:0]                din, // plaintext data
  input  logic                      vin, // plaintext valid
  input  logic                      sof, // start of frame, first plaintext byte, reset accumulator
  input  logic                      eof, // end of frame, last plaintext byte, trigger to generate MAC
  output logic                      cts, // able to accept at least 1 byte
  output logic                      lst, // able to accept only 1 more byte before 16 is block
  input  key_t                      key, // Poly1305 OTK from ChaCha20

  output ptr_t                    ptr_opa, // operator A for ALU
  output ptr_t                    ptr_opb, // operator B for ALU
  output logic                    alu_add, // operation will be modular addition
  output logic                    alu_mul, // operation will be modular multiplcation
  output logic                    alu_cal, // request to calculate

  input  logic [FIELD_BITS_130-1:0] alu_res, // result from ALU
  input  logic                      alu_rdy, // result from ALU is valid
  
  output poly_tag_t                 tag,
  output logic                      tag_val
);

  assign alu_mul = ~alu_add_nmul;
  assign alu_add =  alu_add_nmul;

  logic [127:0] key_s;
  logic [127:0] key_r;
  logic alu_add_nmul;

  assign key_s = le_bytes_to_num(key[15:0]);
  assign key_r = le_bytes_to_num(key[31:16]) & 
                 128'h0ffffffc0ffffffc0ffffffc0fffffff; // clamp

  logic [$clog2(BLOCK_BYTES+1)-1:0] blk_ctr; 
  logic val;
  
  poly_acc_t acc; 
  poly_blk_t blk;

  logic upd_acc;
  logic add_done;
  logic mul_done;

  logic mul_done_comb;
  logic mul_done_reg;
  
  logic add_run;
  logic mul_run;
  
  logic add_run_reg;
  logic mul_run_reg;
  logic add_s;
  logic cal_req;
  logic cal_run;
  
  logic run;
  logic pad_ok;
  logic add_key_s;

  logic pad_done;
  logic one_add;

  logic eof_reg;
  logic eof_det;
  logic [7:0] sipo_din;
  logic shift;
  
  logic pad;
  logic shifting;
  logic one_add_done;

  // Only adding acc+blk or 
  assign alu_opa =  ADDR_POLY1305_ACC;
  // assign alu_opb =  (add_key_s) ? key_s : (add_done) ? key_r : blk;
  assign alu_opb =  (add_key_s) ? ADDR_POLY1305_KEYS : (add_done) ? ADDR_POLY1305_KEYR : ADDR_POLY1305_BLK;
  // assign alu_add_nmul = !eof; 
  // assign alu_mul =  eof; 

  always_ff @ (posedge clk) begin
    if (sof) begin
      $display("[Poly1305]: SOF detected. Using keys:");
      $display("            s=%x", key_s);
      $display("            r=%x", key_r);
    end
    if (alu_cal) begin
      $write("[Poly1305]: ");
      if (alu_add_nmul)  $display("Adding   acc=%x + blk=%x", acc, blk);
      if (~alu_add_nmul) $display("Multiply acc=%x * blk=%x", acc, blk);
    end
    if (add_s) begin
      $display("Adding   acc=%x + s=%x", acc, key_s);
    end
  end

  always_ff @ (posedge clk) begin
    if (vin) begin // Data is incoming, add pending
      add_done <= 0;
    end
    else if (!alu_add_nmul && !shifting && alu_rdy) add_done <= 1; // ALU read. First after val is always add. Assert done
  end

  always_ff @ (posedge clk) begin
    if (alu_cal) add_run_reg <= alu_add; else if (alu_rdy) add_run_reg <= 0;
    if (alu_cal) mul_run_reg <= alu_mul; else if (alu_rdy) mul_run_reg <= 0;
  end

  assign add_run =  add_run_reg | (alu_cal & alu_add);
  assign mul_run =  mul_run_reg | (alu_cal & alu_mul);

  assign mul_done_comb = alu_add_nmul && add_done && alu_rdy;
  assign mul_done = mul_done_reg | mul_done_comb;

  //
  always_ff @ (posedge clk) begin
    if (vin) begin // Data is incoming, add pending
      mul_done_reg <= 0;
    end
    else if (mul_done_comb) begin
      mul_done_reg <= 1; // ALU read. First after val is always add. Assert done
    end
  end

  // Operation select. Add = 1, Mul = 0
  always_ff @ (posedge clk) begin
    if (sof) begin // When starting a new packet, add
      alu_add_nmul <= 1; // initially set to add. 
    end
    else if (alu_cal) begin // Change operation when requesting new calculation
      alu_add_nmul <= ~alu_add_nmul; // Always interlieve operations
    end
  end

  // Request ALU calculation if:
  // 1. Core running and
  // 2. ALU is ready and
  // 3. and block fully loaded, e.g. not being shifted
  // 4. multiplcation is done

  ///////////////
  // Add Key S //
  ///////////////
  
  assign add_s = eof_det & !cal_run & pad_done;  // request to add s after eof received and ALU not busy
  
  assign cal_req = !shifting && !mul_done; // request calculation if not shifting and multiplication not done 

  assign cal_run = mul_run | add_run;

  // conditions to request calculation:
  // - 1. logic is running AND
  // - 2. ALU is ready (not busy) AND
  // - 3.a Not shifing stage and Multiplier is not done yet OR
  // - 3.b EOF is detected and core is not running

  always_ff @ (posedge clk) alu_cal <= run && alu_rdy && ((cal_req | add_s) | (blk_ctr == BLOCK_BYTES-1)); // calculate ALU
  // assign alu_cal = run /*&& (cal_req | add_s)*/; // calculate ALU

  assign cts = (blk_ctr <= BLOCK_BYTES-2) && alu_rdy && shifting;


  always_ff @ (posedge clk) begin
    if (rst | sof | (alu_add_nmul & add_done & alu_rdy &!pad_done)) shifting <= 1; 
    else if ((blk_ctr == BLOCK_BYTES-1) | !run) begin
      shifting <= 0;
    end
  end

  // Keep track of accumulator
  always_ff @ (posedge clk) begin
    if (sof) acc <= 0;      // new packet received, reset accumulator
    else if (alu_rdy) begin // when ALU is ready...
      acc <= alu_res; // accumulator is always result of ALU calculation
    end
  end

  // logic [16:0][7:0] msg;

  // SOF assumes at least 1 byte
  // Reset when started calculation
  // Increment block counter if:
  // 1. data incoming OR
  // 2. EOF is received (append 1)
  // 3. Padding is being loaded

  always_ff @ (posedge clk) begin : proc_blk_ctr
    if      (sof)     blk_ctr <= 1; // start with first block
    else if (alu_cal) blk_ctr <= 0; // request ALU calculation
    else if (vin | eof_reg | pad) begin
      blk_ctr <= blk_ctr + 1;
    end
  end

  // set if logic packet is being loaded
  always_ff @ (posedge clk) begin
    if      (sof)                  run <= 1; // new packet, start logic
    else if (add_key_s && alu_rdy && alu_mul) run <= 0; // when padding is ok and EOF is detected
  end

  // Request to add S to the result (final step)
  always_ff @ (posedge clk) begin
    if      (sof)                              add_key_s <= 0;
    else if (add_done && mul_done && pad_done) add_key_s <= 1; // when padding is ok and EOF is detected
  end

  // set if logic packet is being padded
  always_ff @ (posedge clk) begin
    if      (rst | sof | pad_done) pad <= 0; // new packet, reset EOF detected
    else if (eof_reg)              pad <= 1; // new packet, reset EOF detected
  end

  // add one when EOF is detected or when block is filled (write 0x01 to 17th byte)
  assign one_add = (eof_reg || blk_ctr == BLOCK_BYTES-1);

  // shift 0x01 in the shiftreg after each block received
  always_ff @ (posedge clk) begin
    if      (vin)                             one_add_done <= 0; // data incoming, pending 0x01 
    else if (one_add)                         one_add_done <= 1; // added 0x01 to 17th byte when block is 16 data bytes (1 tick)
  end

  // assume pad is done shifting if padding was in progress and reached complete block size 
  always_ff @ (posedge clk) begin
    if      (vin)                             pad_done <= 0; // data incoming, pad is not done
    else if (pad && blk_ctr == BLOCK_BYTES-1) pad_done <= 1; // padding complete when full block is written
  end

  // Delay eof by 1 tick to append 0x01 (padding Poly1305 block)
  always_ff @ (posedge clk) eof_reg <= eof;
  
  // Remember EOF received until new SOF 
  always_ff @ (posedge clk) if (sof | !run) eof_det <= 0; else if (eof) eof_det <= 1;

  assign lst = blk_ctr == BLOCK_BYTES-2;

  // select what data to shift into the shiftreg:
  // 1. If padding, it's 0x00, otherwise:
  // 2. If adding one, it's 0x01, otherwise
  // 3. It's normal data input
  assign sipo_din = pad ? 8'h00 : one_add ? 8'h01 : din;

  // shift shiftreg condition:
  // 1. data valid incoming OR
  // 2. end of frame detected OR
  // 3. 
  assign shift = vin | eof_reg | pad | one_add; // Shift with new data or when padding


  // Final output
  always_ff @ (posedge clk) begin
    if (run) begin
      tag_val <= 0;
    end
    else begin
      if (!run && alu_rdy & eof_det) begin
        tag_val <= 1;
        tag <= le_bytes_to_num(alu_res);
      end
    end
  end


  qnigma_sipo #(
    .WIDTH  (8),
    .LENGTH (BLOCK_BYTES),
    .RIGHT  (1) 
  ) shiftreg_inst (
    .clk   (clk),
    .rst   (alu_cal), // Reset SIPO to zero when block is loaded in ALU
    .par_o (blk),     // Assembled message block Parallel data
    // .load  (0),    // Provide new eord to 'ser_o'
    .shift (shift),   // Provide new eord to 'ser_o'
    .ser_i (sipo_din) // Serialized block to be written to RAM
  );

  // Message (or last part of message (mod 16bytes)): "Cats"
  // B.16     B.6  B.5  B.4  B.3  B.2  B.1  B.0
  // 0x00 ... 0x00 0x00 0x01 "s"  "t"  "a"  "C"  -> 
  // 0x00 ... 0x00 0x00 0x01 0x73 0x74 0x61 0x43 ->
  // For a full block:
  // B.16     B.6  B.5  B.4  B.3  B.2  B.1  B.0
  // 0x01 ... "e"  "w"  "o"  "l"  "l"  "e"  "H"  -> 
  // 0x00 ... 0x65 0x77 0x6F 0x6C 0x6C 0x65 0x48 ->
  // Bitwise select which bytes will be replaced with 0x00 message block padding

endmodule
