/* 
 * Top-level wrap 
*/
module wrap   
  import
    color_pkg::*,
    qnigma_math_pkg::*;
(
  input  logic         clk,
  input  logic         rst,
  // CPP interface
  input  logic         test_add,
  input  logic         test_sub,
  input  logic         test_mul,
  input  logic         test_inv,
  
  input  logic         run, // 1-tick strobe from TB to calculate
  
  input  logic [255:0] opa, // Operand A 
  input  logic [255:0] opb, // Operand B

  input  logic         fld_25519, // 1 = F25519, 0 = F1305
  // Result
  output logic         done,  // Test passed
  output logic         pass,  // Test passed
  output logic         bad_op // Operands set by CPP TB are not in the field 
);

  parameter int TEST_CASES = 12;

  logic [W-1:0] x_invm;
  logic [W-1:0] cur_p;
  
  logic alu_cal;

  logic alu_rdy;
  
  logic [$clog2(TEST_CASES+1)-1:0] cur;

  logic [WORDS_PER_OPER-2:0][ALU_RAM_WIDTH-1:0] cur_opa;
  logic [WORDS_PER_OPER-2:0][ALU_RAM_WIDTH-1:0] cur_opb;
  logic [WORDS_PER_OPER-2:0][ALU_RAM_WIDTH-1:0] res;

  len_t cur_words_per_oper;

  logic [W-1:0] sum_q;
  logic [W-1:0] sub_q;

  logic [W  :0] add_ab;
  logic [W-1:0] add_ab_mod;
  logic [W  :0] sub_ab;
  logic [W-1:0] sub_ab_mod;
  logic [W  :0] alu_res;

  logic [2*W:0] mul_ab;
  logic [W-1:0] inv_chk;
  logic [W-1:0] inv_chk_n;
  
  pri_t alu_fld;
  
  logic [2*W-1:0] pipa;
  logic [W-1:0] pipam;

  logic alu_add;
  logic alu_sub;
  logic alu_mul;
  logic alu_inv;
  logic alu_eql;

  assign alu_fld = (fld_25519) ? F25519 : F1305;
  assign cur_p   = (fld_25519) ? P25519 : P1305;

  enum logic [2:0] {
    IDLE,
    LOAD_OPA,
    LOAD_OPB,
    REQ,
    RUN,
    READ_RES,
    CHECK
  } state;
  
  task_t task_info;
  logic      task_valid;
  logic      task_done;
  logic      rdy;
  
  qnigma_alu alu_inst (
    .clk            (clk           ),
    .rst            (rst           ),
    .task_info      (task_info      ),
    .task_valid     (task_valid),
    .task_done      (task_done ),
    .alu_eql        (alu_eql       ),

    .ext_wr_dat     (ext_wr_dat    ),
    .ext_wr_ptr     (ext_wr_ptr    ),
    .ext_wr_val     (ext_wr_val    ),
    .ext_wr_sof     (ext_wr_sof    ),
    .ext_rd_fld     (ext_rd_fld    ),
    .ext_rd_req     (ext_rd_req    ),
    .ext_rd_nxt     (ext_rd_nxt    ),
    .ext_rd_ptr     (ext_rd_ptr    ),
    .ext_rd_dat     (ext_rd_dat    ),
    .ext_rd_val     (ext_rd_val    ),
    .ext_rd_eof     (    )
  );

  wrd_t ext_wr_dat;
  ptr_t ext_wr_ptr;
  logic ext_wr_val;
  logic ext_wr_sof;

  fld_t ext_rd_fld;
  logic ext_rd_req;
  logic ext_rd_nxt;
  ptr_t ext_rd_ptr;
  wrd_t ext_rd_dat;
  logic ext_rd_val;

  // Adder check
  assign add_ab = cur_opa + cur_opb;
  assign add_ab_mod = add_ab > cur_p ? add_ab - cur_p : add_ab;

  // Subtractor check
  assign sub_ab = cur_opa - cur_opb;
  assign sub_ab_mod = cur_opa > cur_opb ? sub_ab : sub_ab + cur_p;

  // Multiplier check
  assign mul_ab  = cur_opa * cur_opb;
  
  localparam ptr_t TEST_ADDR_OPA = 50;
  localparam ptr_t TEST_ADDR_OPB = 50+14;
  localparam ptr_t TEST_ADDR_RES = 50+24;
  
  len_t load_ctr_a;
  len_t load_ctr_b;
  len_t read_ctr;
  
  logic loading;
  logic load_done;

  always_ff @ (posedge clk) begin
    if (rst) begin
      state   <= IDLE;
      pass    <= 0;
      done    <= 0;
    end
    else begin
      case (state)
        IDLE : begin
          loading <= 0;
          cur_opa <= opa;
          cur_opb <= opb;
          res     <= 0;
          load_done <= 0;
          if (fld_25519) begin
            load_ctr_a         <= WORDS_PER_OPER - 2;
            load_ctr_b         <= WORDS_PER_OPER - 2;
            read_ctr           <= WORDS_PER_OPER - 2;
            cur_words_per_oper <= WORDS_PER_OPER - 2;
          end
          else begin
            load_ctr_a         <= WORDS_PER_OPER_1305 - 1;
            load_ctr_b         <= WORDS_PER_OPER_1305 - 1;
            read_ctr           <= WORDS_PER_OPER_1305 - 1;
            cur_words_per_oper <= WORDS_PER_OPER_1305 - 1;
          end
          task_info.cpy_src  <= 0;
          task_info.cpy_dst  <= 0;
          task_info.wr_ptr   <= TEST_ADDR_RES;
          task_info.rd_ptr_a <= TEST_ADDR_OPA;
          task_info.rd_ptr_b <= TEST_ADDR_OPB;
          if      (test_add) task_info.op_typ <= add;
          else if (test_sub) task_info.op_typ <= sub;
          else if (test_mul) task_info.op_typ <= mul;
          task_info.pri <= (fld_25519) ? F25519 : F1305;
          done <= 0;
          pass <= 0;
          if (run) state <= LOAD_OPA;
        end
        LOAD_OPA : begin
          load_ctr_a <= load_ctr_a - 1;
          ext_wr_dat <= cur_opa[load_ctr_a];
          ext_wr_ptr <= TEST_ADDR_OPA;
          ext_wr_val <= 1;
          ext_wr_sof <= load_ctr_a == WORDS_PER_OPER-2;
          if (load_ctr_a == 0) begin
            loading <= 0;
            state <= LOAD_OPB;
          end
          else loading <= 1;
        end
        LOAD_OPB : begin
          loading <= 1;
          load_ctr_b <= load_ctr_b - 1;
          ext_wr_dat <= cur_opb[load_ctr_b];
          ext_wr_ptr <= TEST_ADDR_OPB;
          ext_wr_sof <= load_ctr_b == WORDS_PER_OPER-2;
          // if (load_ctr_b == 0) load_done <= 1;
          if (load_ctr_b == 0) begin
            state <= REQ;
         //   ext_wr_val <= 0;
          end
          else ext_wr_val <= 1;
        end
        REQ : begin
          ext_wr_val <= 0;
          task_valid <= 1;
          state      <= RUN;
        end
        RUN : begin
          task_valid <= 0;
          if (task_done) state <= READ_RES;
        end
        READ_RES : begin
          ext_rd_req <= 1;
          ext_rd_nxt <= ext_rd_req;
          ext_rd_ptr <= TEST_ADDR_RES;
          if (read_ctr == 0) state <= CHECK;
          if (ext_rd_val) begin
            read_ctr      <= read_ctr - 1;
            res[read_ctr] <= ext_rd_dat;
          end
        end
        CHECK : begin
          ext_rd_req <= 0;
          ext_rd_nxt <= 0;
          done       <= 1;
          if      (task_info.op_typ == add) begin 
            if (res == add_ab_mod             ) begin
              pass <= 1;
              // $display("PASS");
            end 
            else begin
              $display("BAD");
              $display("SHOULD BE %x", add_ab_mod);
              $display("GOT       %x", res);
            end
          end
          else if (task_info.op_typ == sub) begin 
            if (res == sub_ab_mod             ) begin
              pass <= 1;
              // $display("PASS");
            end 
            else begin
              $display("BAD");
              $display("SHOULD BE %x", sub_ab_mod);
              $display("GOT       %x", res);

            end
          end
          else if (task_info.op_typ == mul) begin 
            if (res == mod(mul_ab, cur_p )    ) begin
              pass <= 1;
              // $display("PASS");
            end 
            else begin
              $display("BAD");
              $display("SHOULD BE %x", mod(mul_ab, cur_p ));
              $display("GOT       %x", res);

            end
          end
          else if (alu_inv) begin 
            if (res == mod_inv(cur_opa, cur_p)) pass <= 1; 
          end
          state <= IDLE;
        end
        default :;
      endcase
    end
  end
endmodule : wrap
