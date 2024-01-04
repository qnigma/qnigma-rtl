/* Copyright: qnigma
This module controls ECP and external point load/read RAM interfaces
==============================================
The reason to use this module is the usage of 256-bit integers in ECP and the need to store them
We utilize block RAM to store the value by spliting the 256-bit number in slices (entries)
We store one 256-bit operands across several RAM entries (addresses). 
That way, we can have a relatively narrow, but larger (deeper) RAM
==============================================
The module handles mainly 4 operations (as logically split into 4 I/O blocks):
  - Write big number for ECP (ALU results are stored)
  - Read  big number for ECP (ALU operands A and B are fetched)
  - Load base point (Ui)
  - Read output point (Uo)
==============================================
'proc_read_write' block handles interaction with ECP
Read and write should never happen at the same time. 
Write and Read interface operate on ALU_BITS and serdes them to ALU_RAM_WIDTH;
==============================================
Loading the base point and reading output point is implemented with data streaming in mind
When implementing a communication device, we will not have the parallel bus to send the would coordinate
Instead, we want to be able to load/read the points (public keys actually) in a serial manner with
the interface width matching the upper protocol (e.g. 8-bit bus for gigabit)
In this case, we need to further serialize each RAM entry to accomodate for POINT_IFC_BITS.

The idea is for the upper logic to direct the Public key information (e.g. 32 bytes) to ui_dat/ui_val
when the appropriate field in, say SSH packet, is detected by packet parser. When transmitting the public key,
use the uo_* interface to provide a stream of Uo coordinate to appropriate field in outcoming packet 
===============================================
Usage notes: 
1. The module is designed to be reset before each new multiplcation
*/
module qnigma_alu_ram_ctl
  import
    qnigma_math_pkg::*;
(
  input  logic clk,
  input  logic rst,
  input  len_t words,
  // Write interface for ECP
  input  logic write,  // just write
  input  logic read_opa_opb,   // just read
  input  logic read_opb,    // just read
  input  logic copy,      // copy

  input  ptr_t                                      write_ptr,
  input  logic [ALU_RAM_WIDTH * WORDS_PER_OPER-2:0] write_dat,
  input  ptr_t                                      read_ptr_opa,
  input  ptr_t                                      read_ptr_opb,
  output logic [ALU_RAM_WIDTH * WORDS_PER_OPER-2:0] read_dat,
  output logic                                      read_val_a,
  output logic                                      read_val_b,

  input  ptr_t                                      copy_ptr_src,
  input  ptr_t                                      copy_ptr_dst,

  output logic                                      done,
  // Load interface for base point
  input  wrd_t                                      ext_wr_dat,
  input  ptr_t                                      ext_wr_ptr, // register address to read 
  input  logic                                      ext_wr_val,
  input  logic                                      ext_wr_sof,
  // Read interface for output point                
  input  fld_t                                      ext_rd_fld, // Readout data type, 
  input  logic                                      ext_rd_req, // Request Uo data. Expext stream of data at 'uo_val'
  input  logic                                      ext_rd_nxt, // next word
  input  ptr_t                                      ext_rd_ptr, // register int_ram_a to read from RAM
  output wrd_t                                      ext_rd_dat, // read data
  output logic                                      ext_rd_val, // read data valid
  output logic                                      ext_rd_eof  // read data valid
);

  // current data to write
  // total width is equal to operand width
  logic [ALU_RAM_WIDTH * WORDS_PER_OPER-1:0]       write_dat_hi_reg;
  
  logic reading, writing, copying;

  logic read_next;
  
  // ECP RAM interface (Port A, read/write)
  // Write and read complete word in parts
  logic int_ram_w; // Write int_ram_d at int_ram_a
  wrd_t int_ram_d; // Data to write (eqials to 1 slice)
  ptr_t int_ram_a; // Adderss to write to / read from
  wrd_t int_ram_q; // Data at int_ram_a (1 clk delay)

  // External RAM interface (Port B, read/write)
  logic ext_ram_w;
  wrd_t ext_ram_d;
  ptr_t ext_ram_a;
  wrd_t ext_ram_q;

  logic [$clog2(ALU_BITS/POINT_IFC_BITS)-1:0] ext_ctr_wr;
  logic [$clog2(ALU_BITS/POINT_IFC_BITS)-1:0] ext_ctr_rd;

  logic [ALU_RAM_WIDTH-POINT_IFC_BITS-1:0] ext_ram_d_reg;
  
  ptr_t ram_read_ptr_b;
  
  ptr_t ram_adr_src;
  ptr_t ram_adr_dst;
  
  logic shift_write;
  logic shift_read;
  logic write_hi_pend;

  len_t ctr_wr_lo;
  len_t ctr_wr_hi;
  len_t ctr_rd_a; 
  len_t ctr_rd_b; 
  len_t ctr_copy; 
  len_t cur_words_per_oper;

  logic load_opb;

  logic ext_rd_req_reg;
  wrd_t ram_data_write;

  ptr_t rd_ptr_last;

  enum logic [6:0] {
    IDLE,
    WRITE,
    READ_A,
    READ_B,
    COPY_READ,
    COPY_WRITE,
    DONE
  } state;
  
  always_ff @ (posedge clk) cur_words_per_oper <= words;

  always_ff @ (posedge clk) begin : proc_read_write
    if (rst) begin
      state <= IDLE;
    end
    else begin
      case (state) 
        IDLE       : begin
          done           <= 0;
          shift_read     <= 0;
          shift_write    <= 0;
          ram_read_ptr_b <= read_ptr_opb + cur_words_per_oper - 1;
          ctr_wr_lo      <= 0;
          ctr_wr_hi      <= 0;
          ctr_rd_a       <= 0;
          ctr_rd_b       <= 0;
          ctr_copy       <= 0;
          load_opb       <= 0;
          if (write) begin
            int_ram_w    <= 1;
            shift_write  <= 1;
            int_ram_a    <= write_ptr + cur_words_per_oper - 1;
            state        <= WRITE;
          end
          else if (read_opa_opb) begin
            int_ram_w    <= 0;
            int_ram_a    <= read_ptr_opa + cur_words_per_oper - 1;
            state        <= READ_A;
          end
          else if (read_opb) begin
            int_ram_w    <= 0;
            int_ram_a    <= read_ptr_opb + cur_words_per_oper - 1;
            state        <= READ_B;
          end
          else if (copy) begin
            int_ram_w    <= 0;
            int_ram_a    <= copy_ptr_src;
            ram_adr_src  <= copy_ptr_src;
            ram_adr_dst  <= copy_ptr_dst;
            state        <= COPY_WRITE;
          end
        end
        WRITE    : begin
          ctr_wr_lo      <= ctr_wr_lo + 1;
          if (ctr_wr_lo == cur_words_per_oper-1) begin
            load_opb     <= 1;
            state        <= DONE;
            shift_write  <= 0;
            int_ram_w    <= 0;
          end
          else begin
            int_ram_w    <= 1;
            shift_write  <= 1;
            int_ram_a    <= int_ram_a - 1;
          end
        end
        READ_A   : begin
          shift_read     <= 1;
          ctr_rd_a       <= ctr_rd_a + 1;
          int_ram_w      <= 0;
          if (ctr_rd_a == cur_words_per_oper-1) begin
            state        <= READ_B;
            int_ram_a    <= ram_read_ptr_b;
          end
          else 
            int_ram_a    <= int_ram_a - 1;
        end
        READ_B   : begin
          shift_read     <= 1;
          ctr_rd_a <= 0;
          ctr_rd_b       <= ctr_rd_b + 1;
          if (ctr_rd_b == cur_words_per_oper-1) begin
            state        <= DONE;
          end
          else begin
            int_ram_a    <= int_ram_a - 1;
          end
        end
        COPY_READ  : begin
          int_ram_w      <= 0;
          ram_adr_src    <= ram_adr_src + 1;
          int_ram_a      <= ram_adr_src;
          state          <= COPY_WRITE;
        end
        COPY_WRITE : begin
          int_ram_w      <= 1;
          ctr_copy       <= ctr_copy + 1;
          ram_adr_dst    <= ram_adr_dst + 1;
          int_ram_a      <= ram_adr_dst;
          state          <= (ctr_copy == words) ? DONE : COPY_READ;
        end
        DONE : begin
          ctr_rd_b      <= 0;
          shift_read    <= 0;
          int_ram_w     <= 0;
          done          <= 1;
          state         <= IDLE;
        end
        default :;
      endcase
    end
  end
  
  always_ff @ (posedge clk) read_val_a <= ctr_rd_a == words;
  always_ff @ (posedge clk) read_val_b <= ctr_rd_b == words;

  /////////////////////////////
  // External data interface //
  /////////////////////////////
  // External point U-cood load (public key)

  always_ff @ (posedge clk) begin
    ext_ram_d <= ext_wr_dat;
    ext_ram_w <= ext_wr_val;
    if      (ext_wr_val) ext_ram_a <= (ext_wr_sof) ? ext_wr_ptr + words - 1 : ext_ram_a - 1;
    else if (ext_rd_req) ext_ram_a <= (ext_rd_nxt) ? ext_ram_a + 1 : ext_rd_ptr;
    
    if (ext_rd_req) rd_ptr_last <= ext_rd_ptr + words;

    ext_rd_req_reg <= ext_rd_req;
    ext_rd_val <= ext_rd_req_reg;
  end

  assign ext_rd_eof = ext_rd_val & ext_ram_a == rd_ptr_last;

  assign ext_rd_dat = ext_ram_q;

  qnigma_alu_ram #(
    .AW   (ADDR_BITS), 
    .DW   (ALU_RAM_WIDTH)
  ) alu_ram_inst (
    .clk (clk),
    // Core interface
    .d_a (int_ram_d),
    .a_a (int_ram_a),
    .w_a (int_ram_w),
    .q_a (int_ram_q),
    // External point load (UI), and read (UO) 
    .d_b (ext_ram_d),
    .a_b (ext_ram_a),
    .w_b (ext_ram_w),
    .q_b (ext_ram_q)
  );

  qnigma_sipo #(
    .WIDTH  (ALU_RAM_WIDTH),
    .LENGTH (WORDS_PER_OPER-1),
    .RIGHT  (0) 
  ) sipo_read_inst (
    .clk   (clk       ),
    .rst   (read_opa_opb | read_opb), // reset SIPO to zero when block is loaded in ALU
    .par_o (read_dat  ), // assembled message block Parallel data
    .shift (shift_read), // provide new eord to 'ser_o'
    .ser_i (int_ram_q )  // serialized block to be written to RAM
  );

  qnigma_piso #(
    .WIDTH  (ALU_RAM_WIDTH),
    .LENGTH (WORDS_PER_OPER-1),
    .RIGHT  (1)
  ) piso_write_inst (
    .clk   (clk),
    .set   (write | load_opb),   // New block written
    .par_i (write_dat),   // Load new block
    .shift (shift_write),     // Provide new eord to 'ser_o'
    .ser_o (int_ram_d) // Serialized block to be written to RAM
  );

endmodule
