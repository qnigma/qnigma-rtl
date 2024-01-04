module qnigma_mdio_serial # (
  parameter int MDC_DIV = 0
)
(
    input  logic clk,
    input  logic rst,
    // transaction control
    input  logic        r_nw,
    input  logic        send,
    output logic        ready,
    output logic        done,
    input  logic [ 4:0] phyad,
    input  logic [ 4:0] regad,
    input  logic [15:0] dat_in ,

    // register output
    output logic [15:0] val_out,
    output logic [15:0] dat_out,
    output logic [ 4:0] adr_out,

    // serial interface
    output logic mdo,
    input  logic mdi,
    output logic mdt,
    output logic mdc

);

  logic [MDC_DIV-1:0] ctr;
  
  parameter int MDC_DIV_HALF = MDC_DIV >> 1;

  always_ff @ (posedge clk) ctr <= (ctr == MDC_DIV-1) ? 0 : ctr + 1;

  logic tick;
  logic tick_neg;
  logic tick_pos;

  assign tick_neg = ctr == 0;
  assign tick_pos = ctr == MDC_DIV_HALF-1;
  
  assign tick = tick_neg;

  always_ff @ (posedge clk) ctr <= (ctr == MDC_DIV-1) ? 0 : ctr + 1;

  always_ff @ (posedge clk) begin
    if      (state == IDLE) mdc <= 0;
    else if (tick_pos)      mdc <= 1;
    else if (tick_neg)      mdc <= 0;
  end

  enum logic [7:0] {
  /*0*/ IDLE, 
  /*1*/ PREAMBLE,
  /*2*/ START,
  /*3*/ OPER,
  /*4*/ PHY_ADR,
  /*5*/ REG_ADR,
  /*6*/ TA_READ,
  /*7*/ TA_WRITE,
  /*8*/ DATA_READ,
  /*9*/ DATA_WRITE,
  /*a*/ READ,
  /*b*/ STOP
  } state;

  always_comb begin
    case (state)
       IDLE       : begin mdt = 0; mdo = 0;                          end
       PREAMBLE   : begin mdt = 1; mdo = 1;                          end
       START      : begin mdt = 1; mdo = start_done;                 end
       OPER       : begin mdt = 1; mdo = (oper_done) ? ~r_nw : r_nw; end
       PHY_ADR    : begin mdt = 1; mdo = phyad_tx[4];                end
       REG_ADR    : begin mdt = 1; mdo = regad_tx[4];                end
       TA_WRITE   : begin mdt = 1; mdo = ~ta_done;                   end
       TA_READ    : begin mdt = 0; mdo = 0;                          end
       DATA_WRITE : begin mdt = 1; mdo = dat_tx[15];                 end
       DATA_READ  : begin mdt = 0; mdo = 0;                          end
       default    : begin mdt = 0; mdo = 0;                          end
    endcase
  end

  logic [2:0] ctr_phyad;
  logic [2:0] ctr_regad;
  
  logic [4:0] regad_tx;
  logic [4:0] phyad_tx;
  logic [4:0] cur_regad;
  
  assign ready = (state == IDLE) && !sending;

  logic [15:0] dat_rx;
  logic [15:0] dat_tx;
  logic sending;
  logic cur_r_nw;

  always_ff @ (posedge clk) begin
    if      (send) sending <= 1;
    else if (done) sending <= 0;
  end

  logic [3:0] ctr_dat;
  parameter int PREAMBLE_BITS = 32;
  logic [$clog2(PREAMBLE_BITS+1)-1:0] ctr_pre;

  logic pre_done;
  logic start_done;
  logic oper_done;
  logic phyad_done;
  logic regad_done;
  logic ta_done;
  logic data_done;

  // assign pre_done   = state == PREAMBLE;
  // assign start_done = state == START;
  // always_ff @ (posedge clk)  oper_done <= state == OPER;
  // assign phyad_done = ctr_phyad == 4;
  // assign regad_done = ctr_regad == 4;
  // assign ta_done    = (state == TA_WRITE) || (state == TA_READ);
  // assign data_done  = ctr_dat == 15;

  // always_ff @ (posedge clk) begin
  //   if (send) regad_tx <= regad; else regad_tx <= regad_tx << 1;
  //   if (send) phyad_tx <= phyad; else phyad_tx <= phyad_tx << 1;
  // end

  always_ff @ (posedge clk) begin
    if (rst) begin
      state <= IDLE;
    end
    else if (tick) begin
      case (state)
        IDLE    : begin
          ctr_pre    <= 0;
          ctr_phyad  <= 0;
          ctr_regad  <= 0;
          ctr_dat    <= 0;
          regad_tx   <= regad;
          cur_regad  <= regad;
          phyad_tx   <= phyad;
          cur_r_nw   <= r_nw;
          dat_tx     <= dat_in;
          start_done <= 0;
          oper_done  <= 0;
          ta_done    <= 0;
          if (sending) begin
            state <= PREAMBLE; 
            if (r_nw) $display("[PHY control]: requesting read");
            else      $display("[PHY control]: requesting write");
          end
        end
        PREAMBLE     : begin ctr_pre    <= ctr_pre + 1;                                      if (ctr_pre == PREAMBLE_BITS-1) state <= START;                           end
        START        : begin start_done <= 1;                                                if (start_done                ) state <= OPER;                            end
        OPER         : begin oper_done  <= 1;                                                if (oper_done                 ) state <= PHY_ADR;                         end
        PHY_ADR      : begin ctr_phyad  <= ctr_phyad + 1; phyad_tx   <= phyad_tx << 1;       if (ctr_phyad == 4            ) state <=                         REG_ADR; end
        REG_ADR      : begin ctr_regad  <= ctr_regad + 1; regad_tx   <= regad_tx << 1;       if (ctr_regad == 4            ) state <= (cur_r_nw) ? TA_READ : TA_WRITE; end
        TA_READ      : begin ta_done    <= 1;                                                if (ta_done                   ) state <= DATA_READ;                       end
        TA_WRITE     : begin ta_done    <= 1;                                                if (ta_done                   ) state <= DATA_WRITE;                      end
        DATA_READ    : begin ctr_dat    <= ctr_dat + 1;     dat_rx   <= {dat_rx[14:0], mdi}; if (ctr_dat == 15             ) state <= IDLE;                            end
        DATA_WRITE   : begin ctr_dat    <= ctr_dat + 1;     dat_tx   <= dat_tx   << 1;       if (ctr_dat == 15             ) state <= IDLE;                            end
        default : state <= IDLE;
      endcase
    end
  end
  
  always_ff @ (posedge clk) done <= (ctr_dat == 15) && tick;

  assign val_out = cur_r_nw && done; 
  assign dat_out = dat_rx; 
  assign adr_out = cur_regad; 

endmodule