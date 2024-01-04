package qnigma_math_pkg;

  parameter bit VERBOSE = 0;

  parameter int ALU_RAM_WIDTH = 32; // RAM width. Check with vendor for optimum value

  typedef enum logic {
    F25519, // field 25519 
    F1305   // field 1305
  } pri_t; // Prime select

  // Field parameters
  parameter int B_BITS         = $clog2(19); 
  parameter int FIELD_BITS_255 = 255;
  parameter int FIELD_BITS_130 = 130;
  parameter int FIELD_BITS     = FIELD_BITS_255; 
  parameter int SCALAR_BITS    = 256;
  parameter int POINT_IFC_BITS = 8;

  // parameter int P1305_1    = P1305 << 2; // P*4
  // parameter int P25519_2P2 = P25519 << 1; // P*2
  // parameter int P25519_2P4 = P25519 << 4; // P*16

  //////////////////
  // ALU settings //
  //////////////////
  parameter int ALU_BITS    = 256;                    // ALU multiplcation operand width
  parameter int MUL_BITS    = 16;                     // target multipliers are 18-19 operand bits
  parameter int NUM_MUL     = ALU_BITS/MUL_BITS;      // number of multipliers required for schoolbook method
  parameter int ALU_OP_BITS = ALU_BITS + ALU_RAM_WIDTH;  // 
  
  typedef bit [ALU_BITS   -1:0] opr_t;
  typedef bit [ALU_OP_BITS-1:0] core_opr_t;
  typedef bit [FIELD_BITS -1:0] fld_t;

  /////////////
  // ALU RAM //
  /////////////

  // maximum number of words needed to store an operand for curve25519 related operations. 280 bits max total
  parameter int WORDS_PER_OPER  = FIELD_BITS_255/ALU_RAM_WIDTH + 1 + 1; // + 7 + 2 = 9 (32-bit RAM words)
  parameter int ALU_ENTRY_WIDTH = WORDS_PER_OPER*ALU_RAM_WIDTH; 

  // maximum number of words needed to store an operand for poly1305 related operations. 160 bits max total
  parameter int WORDS_PER_OPER_1305  = FIELD_BITS_130/ALU_RAM_WIDTH + 1;

  parameter int ADDR_BITS    = $clog2(41*WORDS_PER_OPER);     // needed to store all RAM word addresses. only 2 entries exceed 256b. 42 is number of words. 
  parameter int IFC_PER_WRD  = ALU_RAM_WIDTH/POINT_IFC_BITS;    // define bits needed to encode position of ext_i
  parameter int EXT_MUX_BITS = $clog2(IFC_PER_WRD);         // define bits needed to encode position of ext_i

  // RAM word address 

  typedef logic [ADDR_BITS               -1:0] ptr_t; 
  typedef logic [$clog2(WORDS_PER_OPER+1)-1:0] len_t;
  typedef logic [ALU_RAM_WIDTH           -1:0] wrd_t;

  // Curve parameters and generator point
  // curve25519

  parameter [ALU_ENTRY_WIDTH-1:0] ZERO      = 280'h0;
  parameter [ALU_ENTRY_WIDTH-1:0] ONE       = 280'h1;
  parameter [ALU_ENTRY_WIDTH-1:0] CURVE_GX  = 280'h9;
  parameter [ALU_ENTRY_WIDTH-1:0] CURVE_A24 = 280'd121665;
  parameter [ALU_ENTRY_WIDTH-1:0] P25519    = (1 << FIELD_BITS_255) - 19;
  parameter [ALU_ENTRY_WIDTH-1:0] P25519_1  = P25519 << 1;
  parameter [ALU_ENTRY_WIDTH-1:0] P25519_2  = P25519 << 2;
  parameter [ALU_ENTRY_WIDTH-1:0] P25519_3  = P25519 << 3;
  parameter [ALU_ENTRY_WIDTH-1:0] P25519_4  = P25519 << 4;
  parameter [ALU_ENTRY_WIDTH-1:0] P25519_B  = 280'd19;
  parameter [ALU_ENTRY_WIDTH-1:0] P1305     = (1 << FIELD_BITS_130) - 5;
  parameter [ALU_ENTRY_WIDTH-1:0] P1305_1   = P1305 << 1;
  parameter [ALU_ENTRY_WIDTH-1:0] P1305_2   = P1305 << 2;
  parameter [ALU_ENTRY_WIDTH-1:0] P1305_B   = 280'd5;

  ///////////////////
  // ADDRESS TABLE //
  ///////////////////

   // default number of words to store field element
  localparam len_t LEN_RAM_ECP   = WORDS_PER_OPER;
  // localparam len_t LEN_RAM_P1305 = WORDS_PER_OPER_1305;

  // constants for point multiplication
  parameter ptr_t NULL               =                                0;
  parameter ptr_t ADDR_ZERO          = NULL               + LEN_RAM_ECP;  
  parameter ptr_t ADDR_ONE           = ADDR_ZERO          + LEN_RAM_ECP; 
  parameter ptr_t ADDR_CURVE_GX      = ADDR_ONE           + LEN_RAM_ECP; 
  parameter ptr_t ADDR_CURVE_A24     = ADDR_CURVE_GX      + LEN_RAM_ECP; 
  parameter ptr_t ADDR_A             = ADDR_CURVE_A24     + LEN_RAM_ECP; 
  parameter ptr_t ADDR_AA            = ADDR_A             + LEN_RAM_ECP; 
  parameter ptr_t ADDR_B             = ADDR_AA            + LEN_RAM_ECP; 
  parameter ptr_t ADDR_BB            = ADDR_B             + LEN_RAM_ECP; 
  parameter ptr_t ADDR_E             = ADDR_BB            + LEN_RAM_ECP; 
  parameter ptr_t ADDR_C             = ADDR_E             + LEN_RAM_ECP; 
  parameter ptr_t ADDR_D             = ADDR_C             + LEN_RAM_ECP; 
  parameter ptr_t ADDR_DA            = ADDR_D             + LEN_RAM_ECP; 
  parameter ptr_t ADDR_CB            = ADDR_DA            + LEN_RAM_ECP; 
  parameter ptr_t ADDR_F             = ADDR_CB            + LEN_RAM_ECP; 
  parameter ptr_t ADDR_G             = ADDR_F             + LEN_RAM_ECP; 
  parameter ptr_t ADDR_H             = ADDR_G             + LEN_RAM_ECP; 
  parameter ptr_t ADDR_I             = ADDR_H             + LEN_RAM_ECP; 
  parameter ptr_t ADDR_J             = ADDR_I             + LEN_RAM_ECP; 
  parameter ptr_t ADDR_X1            = ADDR_J             + LEN_RAM_ECP; 
  parameter ptr_t ADDR_X2            = ADDR_X1            + LEN_RAM_ECP; 
  parameter ptr_t ADDR_Z2            = ADDR_X2            + LEN_RAM_ECP; 
  parameter ptr_t ADDR_X3            = ADDR_Z2            + LEN_RAM_ECP; 
  parameter ptr_t ADDR_Z3            = ADDR_X3            + LEN_RAM_ECP; 
  parameter ptr_t ADDR_UI            = ADDR_Z3            + LEN_RAM_ECP; 
  parameter ptr_t ADDR_UO            = ADDR_UI            + LEN_RAM_ECP; 
  parameter ptr_t ADDR_P25519        = ADDR_UO            + LEN_RAM_ECP; //  2^255-19 
  parameter ptr_t ADDR_P25519_1      = ADDR_P25519        + LEN_RAM_ECP; // (2^255-19)*2
  parameter ptr_t ADDR_P25519_2      = ADDR_P25519_1      + LEN_RAM_ECP; // (2^255-19)*2
  parameter ptr_t ADDR_P25519_3      = ADDR_P25519_2      + LEN_RAM_ECP; // (2^255-19)*2
  parameter ptr_t ADDR_P25519_4      = ADDR_P25519_3      + LEN_RAM_ECP; // (2^255-19)*16
  parameter ptr_t ADDR_P25519_B      = ADDR_P25519_4      + LEN_RAM_ECP; // 19
  parameter ptr_t ADDR_INV_R0        = ADDR_P25519_B      + LEN_RAM_ECP; // Storage for FLT R0 variable. R1 is in Z2 or Z3
  parameter ptr_t ADDR_P1305         = ADDR_INV_R0        + LEN_RAM_ECP; //  2^130-5
  parameter ptr_t ADDR_P1305_1       = ADDR_P1305         + LEN_RAM_ECP; // (2^130-5)*2
  parameter ptr_t ADDR_P1305_2       = ADDR_P1305_1       + LEN_RAM_ECP; // (2^130-5)*2
  parameter ptr_t ADDR_P1305_B       = ADDR_P1305_2       + LEN_RAM_ECP; // 5
  parameter ptr_t ADDR_MUL_LO        = ADDR_P1305_B       + LEN_RAM_ECP; // Multiplication result higher half
  parameter ptr_t ADDR_MUL_HI        = ADDR_MUL_LO        + LEN_RAM_ECP; // Multiplication result lower half
  parameter ptr_t ADDR_POLY1305_ACC  = ADDR_MUL_HI        + LEN_RAM_ECP; // Poly1305 Accumulator
  parameter ptr_t ADDR_POLY1305_BLK  = ADDR_POLY1305_ACC  + LEN_RAM_ECP; // Poly1305 Block (message)
  parameter ptr_t ADDR_POLY1305_KEYS = ADDR_POLY1305_BLK  + LEN_RAM_ECP; // Poly1305 Key (S part)
  parameter ptr_t ADDR_POLY1305_KEYR = ADDR_POLY1305_KEYS + LEN_RAM_ECP; // Poly1305 Key (R part)
  parameter ptr_t ADDR_ADD_CAL       = ADDR_POLY1305_KEYR + LEN_RAM_ECP; // Poly1305 Key (R part)
  parameter ptr_t ADDR_ADD_ADJ       = ADDR_ADD_CAL       + LEN_RAM_ECP; // Poly1305 Key (R part)

  parameter int KM = 16;
  parameter int KA = 32;
  parameter int W  = 256 + KM;
  parameter int WA = 256 + KA;
  parameter int WM = 256;
  parameter int NM = W/KM;
  parameter int NA = WA/KA;

  typedef enum logic [3:0] {
    add,
    sub,
    mul,
    cpy
  } alu_op_t;

  typedef struct packed {
    ptr_t    cpy_src;
    ptr_t    cpy_dst;
    ptr_t    wr_ptr;
    ptr_t    rd_ptr_a;
    ptr_t    rd_ptr_b;
    logic    opa_res;
    logic    opb_res;
    alu_op_t op_typ;
    pri_t    pri;
  } task_t;

  function automatic [2*WM:0] mod ();
    input bit [2*WM:0] a;
    input bit [WM-1:0] p;

    bit [2*WM:0] dvd;

    bit [2*WM:0] quo;
    bit [2*WM:0] cmp;
    bit [2*WM:0] chk;
    bit [2*WM-1:0] tmp;
    bit [2*WM-1:0] rem;

    quo = 0;
    cmp = 0;
    dvd = a;
    // $display("p = %x", p);
    for (int i = 0; i < 2*WM+1; i = i + 1) begin
      tmp = cmp[2*WM-2:0] - p;
      cmp = (cmp >= p) ? ({tmp, dvd[2*WM]} ) : {cmp[2*WM-1:0], dvd[2*WM]};
      dvd = dvd << 1;
      quo = quo << 1;
      quo[0] = (cmp >= p);
    end
    chk = quo * p;
    rem = a - chk;
    mod = rem;
  endfunction

  function automatic [W-1:0] mod_inv ();
  
    input bit signed [W:0] A; // pad msb with 0 to make positive (2's comp)
    input bit signed [W:0] M;

    bit signed [W:0] q;
    bit signed [W:0] m0;
    bit signed [W:0] m0r;
    bit signed [W:0] a0;

    bit signed [W:0] x;
    bit signed [W:0] y;
    bit signed [W:0] yr;
    bit signed [W:0] t;

    m0 = M;
    a0 = A;
    
    x = 1;
    y = 0;
    t = 0;
    q = 0;

    if (M == 1) mod_inv = 0;

    while (m0 > ONE) begin
      q = a0 / m0;
      t = m0;
      m0r = a0 % m0;
      m0 = m0r;
      a0 = t;
      t = y;
      yr = x - q * y;
      y = yr;
      x = t;
    end
    // Make positive
    if (y < 0) y += M;
    mod_inv = y;
  endfunction

endpackage