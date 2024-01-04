module qnigma_math_chacha20_kst
  import
    qnigma_chacha20_pkg::*;
(
  input  logic         clk,
  input  logic         rst,
  input  logic         req,
  output logic         val,
  output logic         run,
  input  cha_non_t     non,
  input  cha_key_t     key,
  input  cha_ctr_t     bin,
  output cha_tag_t     tag,
  output cha_kst_blk_t kst
);

  cha_ctr_t blk;

  parameter int ROUNDS = 20;
  parameter int QROUND_INSTS = 4;

  function automatic [31:0] rev;
    input bit [31:0] in;
    rev = {in[7:0], in[15:8], in[23:16], in[31:24]};
  endfunction

  logic [QROUND_INSTS-1:0][WORD_SIZE-1:0] add_a;
  logic [QROUND_INSTS-1:0][WORD_SIZE-1:0] add_b;
  logic [QROUND_INSTS-1:0][WORD_SIZE-1:0] add_q;

  logic [QROUND_INSTS-1:0][WORD_SIZE-1:0] a_i;
  logic [QROUND_INSTS-1:0][WORD_SIZE-1:0] b_i;
  logic [QROUND_INSTS-1:0][WORD_SIZE-1:0] c_i;
  logic [QROUND_INSTS-1:0][WORD_SIZE-1:0] d_i;

  logic [QROUND_INSTS-1:0][WORD_SIZE-1:0] a_o;
  logic [QROUND_INSTS-1:0][WORD_SIZE-1:0] b_o;
  logic [QROUND_INSTS-1:0][WORD_SIZE-1:0] c_o;
  logic [QROUND_INSTS-1:0][WORD_SIZE-1:0] d_o;

  cha_ctr_t blk_ctr;
  
  logic [15:0][WORD_SIZE-1:0] ini; // Initial state
  logic [15:0][WORD_SIZE-1:0] cha;   // Current state

  logic [3:0]                qctr; // Quarter Round counter. Keep track of Qround state
  logic [$clog2(ROUNDS)-1:0] rctr; // Round counter. Keep track of current round
  logic [3:0]                actr; // Adder counter. Reuse adders from quarter rounds and sequence their use 
  logic start;
  logic round_done;
  
  logic cal;
  
  enum logic [2:0] {INI, BLK, ADD} s;
  enum logic {col, row} round, nxt_round;

  always_ff @ (posedge clk) start <= req;
  
  logic val_r;

  always_ff @ (posedge clk) val <= (actr == 3);

  assign run = (s != INI);
  
  // Initialize counter
  // Increment block counter with each new block
  always_ff @ (posedge clk) if (rst) blk <= bin; else if (val) blk <= blk + 1;

  // State machine
  always_ff @ (posedge clk) begin
    if (rst) s <= INI;
    else begin
      case (s)
        INI : if (req)                         s <= BLK; // Initialize
        BLK : if (rctr == ROUNDS-1 && qctr[3]) s <= ADD; // Block function
        ADD : if (actr == 3)                   s <= INI; // FInal addition
        default :                              s <= INI;
      endcase
    end
  end

  // Initial State
  assign ini =
      {rev(non[0]), rev(non[1]), rev(non[2]), blk        ,
       rev(key[0]), rev(key[1]), rev(key[2]), rev(key[3]),
       rev(key[4]), rev(key[5]), rev(key[6]), rev(key[7]), 
       CONST3     , CONST2     , CONST1     , CONST0     };

  ////////////////////
  // Block function //
  ////////////////////

  always_comb begin
    if (req) begin
      cha = ini;
    end
    else begin
      case (round)
        col : begin cha[0] = a_o[0]; cha[4] = b_o[0]; cha[8]  = c_o[0]; cha[12] = d_o[0];
                    cha[1] = a_o[1]; cha[5] = b_o[1]; cha[9]  = c_o[1]; cha[13] = d_o[1];
                    cha[2] = a_o[2]; cha[6] = b_o[2]; cha[10] = c_o[2]; cha[14] = d_o[2];
                    cha[3] = a_o[3]; cha[7] = b_o[3]; cha[11] = c_o[3]; cha[15] = d_o[3]; end
        row : begin cha[0] = a_o[0]; cha[5] = b_o[0]; cha[10] = c_o[0]; cha[15] = d_o[0];
                    cha[1] = a_o[1]; cha[6] = b_o[1]; cha[11] = c_o[1]; cha[12] = d_o[1];
                    cha[2] = a_o[2]; cha[7] = b_o[2]; cha[8]  = c_o[2]; cha[13] = d_o[2];
                    cha[3] = a_o[3]; cha[4] = b_o[3]; cha[9]  = c_o[3]; cha[14] = d_o[3]; end
      endcase
    end
  end

  always_comb begin
      case (nxt_round)
        col : begin a_i[0] = cha[0]; b_i[0] = cha[4]; c_i[0] = cha[8] ; d_i[0] = cha[12];
                    a_i[1] = cha[1]; b_i[1] = cha[5]; c_i[1] = cha[9] ; d_i[1] = cha[13];
                    a_i[2] = cha[2]; b_i[2] = cha[6]; c_i[2] = cha[10]; d_i[2] = cha[14];
                    a_i[3] = cha[3]; b_i[3] = cha[7]; c_i[3] = cha[11]; d_i[3] = cha[15]; end
        row : begin a_i[0] = cha[0]; b_i[0] = cha[5]; c_i[0] = cha[10]; d_i[0] = cha[15];
                    a_i[1] = cha[1]; b_i[1] = cha[6]; c_i[1] = cha[11]; d_i[1] = cha[12];
                    a_i[2] = cha[2]; b_i[2] = cha[7]; c_i[2] = cha[8] ; d_i[2] = cha[13];
                    a_i[3] = cha[3]; b_i[3] = cha[4]; c_i[3] = cha[9] ; d_i[3] = cha[14]; end
      endcase
  end

  // Quarter round counter
  always_ff @ (posedge clk) if (req) qctr <= 1; else qctr <= (s == BLK && ~qctr[3]) ? qctr + 1 : 0;
  // Block function counter
  always_ff @ (posedge clk) if (req) rctr <= 0; else rctr <= (s == BLK) ? (qctr[3]) ? rctr + 1: rctr : 0;
  // Addition counter (State after 20 rounds + Initial State)
  always_ff @ (posedge clk) if (req) actr <= 0; else actr  <= (s == ADD) ? actr + 1 : 0;
  // Select next round
  always_ff @ (posedge clk) if (rst | req | val) nxt_round <= col; else if (rctr != ROUNDS-1 && s == BLK && qctr[3]) nxt_round <= (nxt_round == col) ? row : col;
  // Select current round
  always_ff @ (posedge clk) round <= nxt_round;

  //////////////
  // Addition //
  //////////////
  always_comb begin
    for (int i = 0; i < QROUND_INSTS; i = i + 1) begin
      add_a[i] = cha[QROUND_INSTS*i+actr];
      add_b[i] = ini[QROUND_INSTS*i+actr];
    end
  end

  always_ff @ (posedge clk) begin
    for (int i = 0; i < QROUND_INSTS; i = i + 1) begin
      kst[QROUND_INSTS*i+actr] <= add_q[i];
    end
  end

  // always_ff @ (posedge clk) round <= qctr == 0 && s == BLK;
  always_comb cal = qctr == 0 && s == BLK | req;

  genvar gv;

  generate
    for (gv = 0; gv < QROUND_INSTS; gv = gv + 1) begin : gen_qround
      qnigma_math_chacha20_qround qround_inst (
        .clk (clk),
        .rst (cal),
        .run (s == BLK),
        .a   (add_a[gv]),
        .b   (add_b[gv]),
        .q   (add_q[gv]),
        .a_i (a_i[gv]),
        .b_i (b_i[gv]),
        .c_i (c_i[gv]),
        .d_i (d_i[gv]),
        .a_o (a_o[gv]),
        .b_o (b_o[gv]),
        .c_o (c_o[gv]),
        .d_o (d_o[gv])
      );
    end
  endgenerate

endmodule
