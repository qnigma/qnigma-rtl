module qnigma_alu
  import
    color_pkg::*,
    qnigma_math_pkg::*;
(
  input  logic      clk,
  input  logic      rst,
  input  task_t     task_info,
  input  logic      task_valid,
  output logic      task_done,
  output logic      alu_eql,

  // Load interface for base point
  input  wrd_t ext_wr_dat,
  input  ptr_t ext_wr_ptr, // register address to read 
  input  logic ext_wr_val,
  input  logic ext_wr_sof,
  // Read interface for output point
  input  fld_t ext_rd_fld, // Readout data type, 
  input  logic ext_rd_req, // Request Uo data. Expext stream of data at 'uo_val'
  input  logic ext_rd_nxt, // next word
  input  ptr_t ext_rd_ptr, // register int_ram_a to read from  RAM
  output wrd_t ext_rd_dat, // read data
  output logic ext_rd_val, // read data valid
  output logic ext_rd_eof  //
);

  localparam bit VERBOSE = 1;

  // Core operand width
  // Must hold at most (2^255*19)

  opr_t p;

  opr_t ctr;

  logic[(NUM_MUL+2)*MUL_BITS-1:0]  core_opa; // todo: prune MSbits
  logic[(NUM_MUL+2)*MUL_BITS-1:0]  opa_prev; // todo: prune MSbits
  logic[(NUM_MUL+2)*MUL_BITS-1:0]  core_opb; // todo: prune MSbits
  logic[(NUM_MUL+2)*MUL_BITS-1:0]  read_dat;
  logic[(NUM_MUL+2)*MUL_BITS-1:0]  opa_reg;
  logic[(NUM_MUL+2)*MUL_BITS-1:0]  opb_reg;
  
  logic[FIELD_BITS_255-1:0]  cache;

  logic [2*ALU_BITS-1:0] core_res;
  logic [2*ALU_BITS-1:0] res_reg;

  logic core_cal;
  logic core_done;

  logic ram_don;
   
  logic core_mul;
  logic core_add;
  logic core_sub;

  logic core_ovf;
  logic core_eql;
 
  logic opa_res_hi; // set ALU operand A as current result's higher half
  logic opb_res;    // 
  logic opb_res_lo;    // 
  logic opa_res;    // 
  logic opa_cache;
  logic opa_last;

  ptr_t write_ptr;
  ptr_t read_ptr_opa;
  ptr_t read_ptr_opb;
  ptr_t copy_ptr_src;
  ptr_t copy_ptr_dst;

  logic read_opa_opb;
  logic read_opb;
  logic copy;
  logic ram_done;
  
  logic [ALU_RAM_WIDTH-1:0] read_dat_a;
  logic [ALU_RAM_WIDTH-1:0] read_dat_b;

  logic [FIELD_BITS-1:0] write_dat;
  logic [FIELD_BITS-1:0] res_lo;
  logic [FIELD_BITS-1:0] res_lo_reg;
  logic [FIELD_BITS-1:0] res_hi;
  logic [FIELD_BITS-1:0] res_hi_reg;

  logic sub_neg;

  logic read_val_a;
  logic read_val_b;

  logic write;

  logic [2:0] cur_red_len;
  logic [2:0] ctr_red;

  logic overflow;
  
  pri_t cur_fld;
  ptr_t cur_addr_p;

  assign cur_addr_p = ADDR_P25519;
  
  enum logic [7:0] {
    IDLE,
    MUL_CAL,
    MUL_BHI,
    MUL_RED_SEL,
    MUL_RED_CAL,
    MUL_WRITE_ADJ,
    COPY,
    READ,
    WRITE,
    ADD_CAL,
    ADD_REQ,
    ADD_ADJ
  } state;

  // core operations: Add, subtract and multiply (not modulo)
  // when multiplying, operands have to be loaded
  // when adding or subtracting, we can load operands limb-by-limb 
  qnigma_alu_core #(
    .N  (NUM_MUL),  // Number of multipliers 16
    .K  (MUL_BITS), // Multiplier width 16
    .WA ((NUM_MUL+2)*MUL_BITS) // Adder input width 
  ) alu_core_inst (
    .clk (clk     ),
    .rst (rst     ),
    .opa (core_opa),
    .opb (core_opb),
    
    .mul (core_mul),
    .add (core_add),
    .sub (core_sub),
    .cal (core_cal),

    .res (core_res),
    // .ldr (core_ldr),
    .ovf (core_ovf),
    .eql (core_eql),
    .don (core_done)
  );
  
  logic [$clog2(WORDS_PER_OPER+1)-1:0] ram_words;
 
  ptr_t red_p_init;

  alu_op_t cur_op;
  ptr_t cur_p_addr;
  ptr_t cur_b_addr;
  logic writing;

  logic cache_pend;

  qnigma_alu_ram_ctl alu_ram_ctl_inst (
    .clk           (clk         ),
    .rst           (rst         ),
    .words         (ram_words   ), 
    .read_opa_opb  (read_opa_opb),
    .read_opb      (read_opb    ),
    .read_ptr_opa  (read_ptr_opa),
    .read_ptr_opb  (read_ptr_opb),
    .read_dat      (read_dat    ),
    .read_val_b    (read_val_b  ),
    .read_val_a    (read_val_a  ),

    .write         (write       ),
    .write_ptr     (write_ptr   ),
    .write_dat     (write_dat   ),

    .copy          (copy        ),    
    .copy_ptr_src  (copy_ptr_src),
    .copy_ptr_dst  (copy_ptr_dst), 

    .done          (ram_done), // RAM operation complete
    
    .ext_wr_dat    (ext_wr_dat),
    .ext_wr_ptr    (ext_wr_ptr),
    .ext_wr_val    (ext_wr_val),
    .ext_wr_sof    (ext_wr_sof),
    .ext_rd_fld    (ext_rd_fld),
    .ext_rd_req    (ext_rd_req),
    .ext_rd_nxt    (ext_rd_nxt),
    .ext_rd_ptr    (ext_rd_ptr),
    .ext_rd_dat    (ext_rd_dat),
    .ext_rd_val    (ext_rd_val),
    .ext_rd_eof    (ext_rd_eof)
  );

  // assign high and low results
  // for fast reduction
  always_comb begin 
    case (cur_fld)
      F25519 : begin
        res_lo = res_reg[  FIELD_BITS_255-1:             0];
        res_hi = res_reg[2*FIELD_BITS_255-1:FIELD_BITS_255];
      end
      F1305  : begin
        res_lo = res_reg[  FIELD_BITS_130-1:             0];
        res_hi = res_reg[2*FIELD_BITS_130-1:FIELD_BITS_130];
      end
    endcase
  end
 
  assign cur_p_addr    = (cur_fld == F25519) ? ADDR_P25519    : ADDR_P1305;
  assign cur_b_addr    = (cur_fld == F25519) ? ADDR_P25519_B  : ADDR_P1305_B;
  assign ram_words     = (cur_fld == F25519) ? WORDS_PER_OPER - 1: WORDS_PER_OPER_1305; 
  assign red_p_init    = (cur_fld == F25519) ? ADDR_P25519_4  : ADDR_P1305_2;
  

  // assign write_dat = (write_prev_res) ? res_reg : (write_prev) ? opa_reg : core_res;

  // Register data from RAM
  always_ff @ (posedge clk) begin
    if (read_val_a) opa_reg <= read_dat;
    if (read_val_b) opb_reg <= read_dat;
  end

  // Cache for low half (register)
  always_ff @ (posedge clk) if (core_done) res_reg  <= core_res;
  always_ff @ (posedge clk) if (core_done) cache    <= res_lo;
  always_ff @ (posedge clk) if (core_cal ) opa_prev <= core_opa;

  enum logic [4:0] {
    sel_wr_core_res,
    sel_wr_opa_last,
    sel_wr_res_reg
  } wr_sel;

  enum logic [4:0] {
    sel_opa_res_hi,
    sel_opa_res_lo,
    sel_opa_res,
    sel_opa_cache,
    sel_opa_last,
    sel_opa_reg
  } opa_sel;

  enum logic [2:0] {
    sel_opb_res,
    sel_opb_red_pow,
    sel_opb_cur_p,
    sel_opb_reg
  } opb_sel;

  always_comb begin 
    if      (wr_sel  == sel_wr_res_reg)     write_dat = res_reg;
    else if (wr_sel  == sel_wr_opa_last)    write_dat = opa_prev;
    else /* (opa_sel == sel_wr_core_res )*/ write_dat = core_res;
  end

  always_comb begin 
    if      (opa_sel == sel_opa_res_hi) core_opa = res_hi;
    else if (opa_sel == sel_opa_res_lo) core_opa = res_lo;
    else if (opa_sel == sel_opa_res)    core_opa = res_reg;
    else if (opa_sel == sel_opa_cache ) core_opa = cache;
    else if (opa_sel == sel_opa_last  ) core_opa = opa_prev;
    else /* (opa_sel == sel_opa_reg )*/ core_opa = opa_reg;
  end

  always_comb begin 
    if      (opb_sel == sel_opb_res)     core_opb = res_reg[(NUM_MUL+2)*MUL_BITS-1:0];
    else if (opb_sel == sel_opb_red_pow) core_opb = cur_red_pow;
    else if (opb_sel == sel_opb_cur_p  ) core_opb = cur_p;
    else /* (opa_sel == sel_opb_reg )*/  core_opb = opb_reg;
  end

  fld_t cur_p;
  always_comb begin
    case (cur_fld)
      F25519 : cur_p = P25519;
      F1305  : cur_p = P1305;
    endcase
  end

  always_comb begin
    case (cur_fld)
      F25519 : cur_red_len = 6; // 19 = 16 + 2 + 1
      F1305  : cur_red_len = 3; // 5  = 4 + 1
    endcase
  end

  ptr_t copy_ptr_src_reg;
  ptr_t copy_ptr_dst_reg;

  always_ff @ (posedge clk) begin
    if (task_valid) begin
      cur_op       <= task_info.op_typ;
      copy_ptr_src <= task_info.cpy_src;
      copy_ptr_dst <= task_info.cpy_dst;
      read_ptr_opa <= task_info.rd_ptr_a;
    end
  end

  logic op_add;
  logic op_sub;
  logic op_mul;
  logic shift_red;
  logic fld_overflow_bit;

  always_comb begin
    if (cur_fld == F25519) fld_overflow_bit = core_res[FIELD_BITS_255];
    else                   fld_overflow_bit = core_res[FIELD_BITS_130];
  end

  logic [(NUM_MUL+2)*MUL_BITS-1:0] cur_red_pow;

  always_comb begin
    if (cur_fld == F25519) begin
      if      (ctr_red == 1) cur_red_pow = P25519_4; // 16
      else if (ctr_red == 2) cur_red_pow = P25519_3; // 8
      else if (ctr_red == 3) cur_red_pow = P25519_2; // 4
      else if (ctr_red == 4) cur_red_pow = P25519_1; // 2
      else                   cur_red_pow = P25519;
    end
    else begin
      if      (ctr_red == 1) cur_red_pow = P1305_2; // 4
      else if (ctr_red == 2) cur_red_pow = P1305_1; // 2
      else                   cur_red_pow = P1305;
    end
  end

  always_ff @ (posedge clk) begin
    if (rst) begin
      state <= IDLE;
    end
    else begin
      case (state)
        IDLE : begin
          opa_sel        <= sel_opa_reg;
          opb_sel        <= sel_opb_reg;
          wr_sel         <= sel_wr_core_res;
          op_add         <= task_info.op_typ == add;
          op_sub         <= task_info.op_typ == sub;
          op_mul         <= task_info.op_typ == mul;
          
          writing        <= 0;
          core_cal       <= 0;
          ctr_red        <= 0;
          cur_fld        <= task_info.pri; 

          read_ptr_opb   <= task_info.rd_ptr_b;
          task_done      <= 0;
          if (task_valid) begin
            read_opa_opb <= (task_info.op_typ != cpy);
            copy         <= (task_info.op_typ == cpy);
            state        <= (task_info.op_typ == cpy) ? COPY : READ;
            core_add     <= (task_info.op_typ == add);
            core_sub     <= (task_info.op_typ == sub);
            core_mul     <= (task_info.op_typ == mul);
          end
        end
        COPY : begin
          copy <= 0;
          if (ram_done) state <= READ;
        end
        READ : begin
          read_opa_opb <= 0;
     //     opb_sel <= sel_opb_cur_p;
          read_ptr_opb  <= cur_b_addr;
          if (ram_done) begin
            core_cal   <= 1;
            read_opb   <= cur_op == mul;
            if      (cur_op == mul) state <= MUL_CAL;
            else if (cur_op == add) state <= ADD_CAL;
            else if (cur_op == sub) state <= ADD_CAL;
          end
        end
        // Multiply
        MUL_CAL : begin
        read_opb <= 0;
          if (core_done) begin
            opa_sel       <= sel_opa_res_hi;
            opb_sel       <= sel_opb_reg;
            write_ptr     <= task_info.wr_ptr; // store Lower half of multiplication result
            core_add      <= 0;
            core_sub      <= 0;
            core_mul      <= 1; // multiply 
            core_cal      <= 1;
            state         <= MUL_BHI;
          end else begin
            core_cal      <= 0;
          end
        end
        MUL_BHI : begin
          if (core_done) begin // result now = B * XYhi
            opa_sel    <= sel_opa_cache;
            opb_sel    <= sel_opb_res;
            read_opb   <= 1;
            core_add   <= 1;
            core_sub   <= 0;
            core_mul   <= 0;
            core_cal   <= 1;
            state      <= MUL_RED_SEL;
          end else begin
            read_opb   <= 0;
            core_cal   <= 0;
          end
        end
        MUL_RED_SEL : begin
          opa_sel      <= sel_opa_reg;
          opb_sel      <= sel_opb_red_pow;
          shift_red    <= 0;
          core_cal     <= 0;
          read_opb     <= 0;
          wr_sel <= core_ovf ? sel_wr_opa_last : sel_wr_core_res;
          if (core_done) begin
            overflow   <= core_ovf;
            state      <= (ctr_red == cur_red_len) ? WRITE : MUL_RED_CAL;
          end
        end
        MUL_RED_CAL : begin
          shift_red <= 1;
          state     <= MUL_RED_SEL;
          ctr_red   <= ctr_red + 1;
          opa_sel   <= overflow ? sel_opa_last : sel_opa_res;
          read_opb  <= (ctr_red != cur_red_len-1);  
          core_mul  <= 0;
          core_add  <= 0;
          core_sub  <= 1;
          core_cal  <= 1;
        end
        ////////////////////
        // Add and adjust //
        ////////////////////
        // Calculating ordinary addition X + Y
        ADD_CAL : begin
          read_opb     <= 0;
          read_ptr_opb <= cur_addr_p;
          if (core_done) begin // result now = A + B
            overflow  <= fld_overflow_bit;
            core_mul  <= 0;
            core_add  <= ~op_add;
            core_sub  <= op_add;
            opa_sel   <= sel_opa_res_lo;
            opb_sel   <= sel_opb_cur_p;
            state     <= ADD_ADJ;
            write_ptr <= task_info.wr_ptr;
            // write     <= 0;
            core_cal  <= 1;
          end
          else
            core_cal <= 0;
        end
        ADD_ADJ : begin
          // write     <= 0;
          read_opb  <= 0;
          core_cal  <= 0;
          write_ptr <= task_info.wr_ptr;
          if (op_add) wr_sel <= (core_ovf & ~overflow) ? sel_wr_res_reg : sel_wr_core_res;
          else        wr_sel <=             ~overflow  ? sel_wr_res_reg : sel_wr_core_res;
          if (core_done) begin
            alu_eql <= core_eql;
            state   <= WRITE;
          end
        end
        WRITE : begin
          writing <= 1;
          // write <= ~writing;
          core_cal <= 0;
          if (ram_done) begin
            state    <= IDLE;
            task_done <= 1;
          end
        end
        default :;
      endcase
    end
  end

  assign write = core_done && ((state == ADD_ADJ) || ((state == MUL_RED_SEL) && (ctr_red == cur_red_len)));

endmodule : qnigma_alu