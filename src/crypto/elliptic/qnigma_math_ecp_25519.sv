module math_ecp_25519
  import
    qnigma_math_pkg::*;
(
  input  logic                      clk,
  input  logic                      rst,

  input  logic                      generator,    // use generator as base point
  input  logic   [SCALAR_BITS-1:0]  scalar,       // Scalar to multiply base point by
  input  logic                      start,        // strobe, request calculation (base point hast to be loaded)
  output logic                      ready,        // multiplication complete, (resulting point is available for readout)

  output task_t                     task_info,
  output logic                      task_valid,
  input  logic                      task_done
);

  // Prototype RAM to store constants 

  logic [SCALAR_BITS-1:0] n_reg;
  logic [FIELD_BITS -1:0] p_reg;
  
  logic [$clog2(W+1)-1:0] ctr_exp_point;
  logic [$clog2(FIELD_BITS+1)-1:0] ctr_exp_invert;
  logic ue;

  logic next;

  logic write;

  logic running;
  logic op_copy;
  logic done;

  logic swap_reg;  // 
  logic swap_prev; // Previous value of swap_reg
  logic swap;
  logic ladder_done;

  // Montgomery curve arithmetic.
  // We use X-coordinate (aka U) as the key
  // This allows us to completely skip Y-coord calculation

  enum logic [7:0] {
   /*0x00*/ READY  ,
   /*0x01*/ SHIFT  ,
   /*0x02*/ CPY_X1,
   /*0x03*/ CPY_X2,
   /*0x04*/ CPY_Z2,
   /*0x05*/ CPY_X3,
   /*0x06*/ CPY_Z3,
   /*0x07*/ CAL_A,
   /*0x08*/ CAL_AA,
   /*0x09*/ CAL_B,
   /*0x0a*/ CAL_BB,
   /*0x0b*/ CAL_E,
   /*0x0c*/ CAL_C,
   /*0x0d*/ CAL_D,
   /*0x0e*/ CAL_DA,
   /*0x0f*/ CAL_CB,
   /*0x10*/ CAL_F,
   /*0x11*/ CAL_X3,
   /*0x12*/ CAL_G,
   /*0x13*/ CAL_H,
   /*0x14*/ CAL_Z3,
   /*0x15*/ CAL_X2,
   /*0x16*/ CAL_I,
   /*0x17*/ CAL_J,
   /*0x18*/ CAL_Z2,
  //  /*0x19*/ INV_Z  , // Invert Z once to then multiply (U/Z) and  
   INV_MUL,
   INV_SQR,
   /*0x1a*/ FIN_X    // Final U-coordinate output
  } state, nxt_state;

  always_ff @ (posedge clk) 
    if      (ready ) state <= READY; 
    else if (next) state <= nxt_state;

  // always_ff @ (posedge clk) start <= start;
  
  logic point_ladder_done;
  logic invert_ladder_done;

  always_ff @ (posedge clk) task_valid <= next;
  
  ptr_t base_point;

  always_ff @ (posedge clk) next <= start | (!task_valid & task_done);
  assign base_point         = (generator) ? ADDR_CURVE_GX : ADDR_UI;
  assign point_ladder_done  = (ctr_exp_point  == SCALAR_BITS-1);
  assign invert_ladder_done = (ctr_exp_invert == FIELD_BITS_255);

  always_comb begin
    case (state)
      CPY_X1  : begin task_info.cpy_src = base_point; task_info.cpy_dst = ADDR_X1    ; end // set P1(x) as pase point. Generator or pub key
      CPY_X2  : begin task_info.cpy_src = ADDR_ONE  ; task_info.cpy_dst = ADDR_X2    ; end // set P2(x) to 1
      CPY_Z2  : begin task_info.cpy_src = ADDR_ZERO ; task_info.cpy_dst = ADDR_Z2    ; end // set P2(z) to 0
      CPY_X3  : begin task_info.cpy_src = ADDR_X1   ; task_info.cpy_dst = ADDR_X3    ; end // set P3(x) to P1(x)
      CPY_Z3  : begin task_info.cpy_src = ADDR_ONE  ; task_info.cpy_dst = ADDR_Z3    ; end // set P3(z) to 1
    //  CPY_INV : begin task_info.cpy_src = ADDR_ONE  ; task_info.cpy_dst = ADDR_INV_R1; end // 
      default : begin task_info.cpy_src = ADDR_ZERO ; task_info.cpy_dst = NULL       ; end
    endcase

    case (state)
      READY   : begin task_info.op_typ = cpy; task_info.wr_ptr = NULL   ; nxt_state = CPY_X1;                              end 
      CPY_X1  : begin task_info.op_typ = cpy; task_info.wr_ptr = NULL   ; nxt_state = CPY_X2;                              end
      CPY_X2  : begin task_info.op_typ = cpy; task_info.wr_ptr = NULL   ; nxt_state = CPY_Z2;                              end
      CPY_Z2  : begin task_info.op_typ = cpy; task_info.wr_ptr = NULL   ; nxt_state = CPY_X3;                              end
      CPY_X3  : begin task_info.op_typ = cpy; task_info.wr_ptr = NULL   ; nxt_state = CPY_Z3;                              end
      CPY_Z3  : begin task_info.op_typ = cpy; task_info.wr_ptr = NULL   ; nxt_state = SHIFT ;                              end
      SHIFT   : begin task_info.op_typ = mul; task_info.wr_ptr = NULL   ; nxt_state = point_ladder_done ? INV_MUL : CAL_A ;end
      CAL_A   : begin task_info.op_typ = add; task_info.wr_ptr = ADDR_A ; nxt_state = CAL_AA;                              end
      CAL_AA  : begin task_info.op_typ = mul; task_info.wr_ptr = ADDR_AA; nxt_state = CAL_B ;                              end
      CAL_B   : begin task_info.op_typ = sub; task_info.wr_ptr = ADDR_B ; nxt_state = CAL_BB;                              end
      CAL_BB  : begin task_info.op_typ = mul; task_info.wr_ptr = ADDR_BB; nxt_state = CAL_E ;                              end
      CAL_E   : begin task_info.op_typ = sub; task_info.wr_ptr = ADDR_E ; nxt_state = CAL_C ;                              end
      CAL_C   : begin task_info.op_typ = add; task_info.wr_ptr = ADDR_C ; nxt_state = CAL_D ;                              end
      CAL_D   : begin task_info.op_typ = sub; task_info.wr_ptr = ADDR_D ; nxt_state = CAL_DA;                              end
      CAL_DA  : begin task_info.op_typ = mul; task_info.wr_ptr = ADDR_DA; nxt_state = CAL_CB;                              end
      CAL_CB  : begin task_info.op_typ = mul; task_info.wr_ptr = ADDR_CB; nxt_state = CAL_F ;                              end
      CAL_F   : begin task_info.op_typ = add; task_info.wr_ptr = ADDR_F ; nxt_state = CAL_X3;                              end
      CAL_X3  : begin task_info.op_typ = mul; task_info.wr_ptr = ADDR_X3; nxt_state = CAL_G ;                              end
      CAL_G   : begin task_info.op_typ = sub; task_info.wr_ptr = ADDR_G ; nxt_state = CAL_H ;                              end
      CAL_H   : begin task_info.op_typ = mul; task_info.wr_ptr = ADDR_H ; nxt_state = CAL_Z3;                              end
      CAL_Z3  : begin task_info.op_typ = mul; task_info.wr_ptr = ADDR_Z3; nxt_state = CAL_X2;                              end
      CAL_X2  : begin task_info.op_typ = mul; task_info.wr_ptr = ADDR_X2; nxt_state = CAL_I ;                              end
      CAL_I   : begin task_info.op_typ = mul; task_info.wr_ptr = ADDR_I ; nxt_state = CAL_J ;                              end
      CAL_J   : begin task_info.op_typ = add; task_info.wr_ptr = ADDR_J ; nxt_state = CAL_Z2;                              end
      CAL_Z2  : begin task_info.op_typ = mul; task_info.wr_ptr = ADDR_Z2; nxt_state = SHIFT ;                              end

      // INV_Z   : begin task_info.op_typ = inv; task_info.wr_ptr = NULL   ; nxt_state = FIN_X ;                     end

      INV_MUL : begin task_info.op_typ = mul; task_info.wr_ptr = (p_reg[FIELD_BITS-1]) ? ptr_inv_r0 : ptr_inv_r1  ; nxt_state = (invert_ladder_done) ? FIN_X : INV_SQR ; end
      INV_SQR : begin task_info.op_typ = mul; task_info.wr_ptr = NULL   ; nxt_state = INV_MUL ;                            end
      FIN_X   : begin task_info.op_typ = mul; task_info.wr_ptr = ADDR_UO; nxt_state = READY ;                              end
      default : begin task_info.op_typ = mul; task_info.wr_ptr = NULL   ; nxt_state = READY ;                              end
    endcase

    case (nxt_state)
      // READY   : begin task_info.rd_ptr_a = NULL                                    ; task_info.rd_ptr_b = NULL                                     ; task_info.opa_res = 1; task_info.opb_res = 1; end
      // SHIFT   : begin task_info.rd_ptr_a = NULL                                    ; task_info.rd_ptr_b = NULL                                     ; task_info.opa_res = 1; task_info.opb_res = 1; end
      CAL_A   : begin task_info.rd_ptr_a = (swap) ? ADDR_X3 : ADDR_X2              ; task_info.rd_ptr_b = (swap) ? ADDR_Z3 : ADDR_Z2               ; task_info.opa_res = 0; task_info.opb_res = 0; end
      CAL_AA  : begin task_info.rd_ptr_a = NULL                                    ; task_info.rd_ptr_b = NULL                                     ; task_info.opa_res = 1; task_info.opb_res = 1; end
      CAL_B   : begin task_info.rd_ptr_a = (swap) ? ADDR_X3 : ADDR_X2              ; task_info.rd_ptr_b = (swap) ? ADDR_Z3 : ADDR_Z2               ; task_info.opa_res = 0; task_info.opb_res = 0; end
      CAL_BB  : begin task_info.rd_ptr_a = NULL                                    ; task_info.rd_ptr_b = NULL                                     ; task_info.opa_res = 1; task_info.opb_res = 1; end
      CAL_E   : begin task_info.rd_ptr_a = ADDR_AA                                 ; task_info.rd_ptr_b = NULL                                     ; task_info.opa_res = 0; task_info.opb_res = 1; end
      CAL_C   : begin task_info.rd_ptr_a = (swap) ? ADDR_X2 : ADDR_X3              ; task_info.rd_ptr_b = (swap) ? ADDR_Z2 : ADDR_Z3               ; task_info.opa_res = 0; task_info.opb_res = 0; end
      CAL_D   : begin task_info.rd_ptr_a = (swap) ? ADDR_X2 : ADDR_X3              ; task_info.rd_ptr_b = (swap) ? ADDR_Z2 : ADDR_Z3               ; task_info.opa_res = 0; task_info.opb_res = 0; end
      CAL_DA  : begin task_info.rd_ptr_a = NULL                                    ; task_info.rd_ptr_b = ADDR_A                                   ; task_info.opa_res = 1; task_info.opb_res = 0; end
      CAL_CB  : begin task_info.rd_ptr_a = ADDR_C                                  ; task_info.rd_ptr_b = ADDR_B                                   ; task_info.opa_res = 0; task_info.opb_res = 0; end
      CAL_F   : begin task_info.rd_ptr_a = ADDR_DA                                 ; task_info.rd_ptr_b = NULL                                     ; task_info.opa_res = 0; task_info.opb_res = 1; end
      CAL_X3  : begin task_info.rd_ptr_a = NULL                                    ; task_info.rd_ptr_b = NULL                                     ; task_info.opa_res = 1; task_info.opb_res = 1; end
      CAL_G   : begin task_info.rd_ptr_a = ADDR_DA                                 ; task_info.rd_ptr_b = ADDR_CB                                  ; task_info.opa_res = 0; task_info.opb_res = 0; end
      CAL_H   : begin task_info.rd_ptr_a = NULL                                    ; task_info.rd_ptr_b = NULL                                     ; task_info.opa_res = 1; task_info.opb_res = 1; end
      CAL_Z3  : begin task_info.rd_ptr_a = ADDR_X1                                 ; task_info.rd_ptr_b = NULL                                     ; task_info.opa_res = 0; task_info.opb_res = 1; end
      CAL_X2  : begin task_info.rd_ptr_a = ADDR_AA                                 ; task_info.rd_ptr_b = ADDR_BB                                  ; task_info.opa_res = 0; task_info.opb_res = 0; end
      CAL_I   : begin task_info.rd_ptr_a = ADDR_CURVE_A24                          ; task_info.rd_ptr_b = ADDR_E                                   ; task_info.opa_res = 0; task_info.opb_res = 0; end
      CAL_J   : begin task_info.rd_ptr_a = ADDR_AA                                 ; task_info.rd_ptr_b = NULL                                     ; task_info.opa_res = 0; task_info.opb_res = 1; end
      CAL_Z2  : begin task_info.rd_ptr_a = ADDR_E                                  ; task_info.rd_ptr_b = NULL                                     ; task_info.opa_res = 0; task_info.opb_res = 1; end
       
      // INV_Z   : begin task_info.rd_ptr_a = (swap) ? ADDR_Z3 : ADDR_Z2              ; task_info.rd_ptr_b = NULL                                     ; task_info.opa_res = 0; task_info.opb_res = 1; end
      
      INV_MUL : begin task_info.rd_ptr_a = ptr_inv_r0;                            ; task_info.rd_ptr_b = ptr_inv_r1                                ; task_info.opa_res = 0; task_info.opb_res = 1; end
      INV_SQR : begin task_info.rd_ptr_a = (p_reg[FIELD_BITS-1]) ? ptr_inv_r0 : ptr_inv_r1 ; task_info.rd_ptr_b = (p_reg[FIELD_BITS-1]) ?  ptr_inv_r0 : ptr_inv_r1   ; task_info.opa_res = 0; task_info.opb_res = 1; end
      
      FIN_X   : begin task_info.rd_ptr_a = (swap) ? ADDR_X3 : ADDR_X2             ; task_info.rd_ptr_b = NULL                                      ; task_info.opa_res = 0; task_info.opb_res = 1; end
      default : begin task_info.rd_ptr_a = NULL                                   ; task_info.rd_ptr_b = NULL                                      ; task_info.opa_res = 1; task_info.opb_res = 1; end
    endcase
  end
  
  ptr_t ptr_inv_r0;
  ptr_t ptr_inv_r1;

  assign ptr_inv_r0 = ADDR_INV_R0;
  assign ptr_inv_r1 = (swap) ? ADDR_Z3 : ADDR_Z2;

  // Multiplcaion complete
  always_ff @ (posedge clk) begin : process_rdy
    if (rst | state == READY) ready <= 0;
    else ready <= (next & state == FIN_X);
  end

  // Request ALU calculation immediately after entering the state.
  // ALU is requested only if calculation is required 

  always_ff @ (posedge clk) begin
    if (start & !running)                       running <= 1;
    else if (running && state == FIN_X && next) running <= 0;
  end

  // Load and shift the scalar. We only look at n_reg[0]
  // TODO: look if shiftreg+mux is better
  always_ff @ (posedge clk) begin : process_n_reg
    if (start) begin // request for new multiplcation...
      n_reg <= scalar; // Load the new scalar
    end
    else if (state == SHIFT && next) begin // shift n_reg with each ladder step
      n_reg <= n_reg << 1;
    end
  end
  
  // Load and shift the P-2 for modular inverse. We only look at p_reg[0]
  // TODO: look if shiftreg+mux is better
  always_ff @ (posedge clk) begin : process_p_reg
    if (start) begin // request for new multiplcation...
      p_reg <= P25519 - 2; // Load the new scalar
    end
    else if (state == INV_SQR && next) begin // shift n_reg with each ladder step
      p_reg <= p_reg << 1;
    end
  end

  // Swap selects the Montgomery ladder branch
  always_ff @ (posedge clk) begin : process_swap
    if (start) begin
      swap_reg  <= 0;
    end
    else if (nxt_state == SHIFT && next) begin
      swap_reg  <= n_reg[SCALAR_BITS-2];
      swap_prev <= swap_reg;
    end
  end
  
  assign swap = (swap_reg ^ swap_prev);

  // Scalar bit counter. Defines stop condifiton 
  always_ff @ (posedge clk) begin : process_ctr_exp_invert
    if      (rst  |  state == READY) ctr_exp_invert <= 0;
    else if (next && state == INV_MUL) ctr_exp_invert <= ctr_exp_invert + 1;
  end
  always_ff @ (posedge clk) begin : process_ctr_exp_point
    if      (rst  |  state == READY) ctr_exp_point <= 0;
    else if (next && state == SHIFT) ctr_exp_point <= ctr_exp_point + 1;
  end

endmodule