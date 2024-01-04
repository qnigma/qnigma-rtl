package qnigma_poly1305_pkg;
  
  parameter int BLOCK_BYTES = 17; // Block size
  parameter int ACCUM_BYTES = 32; // Block accumulator size
  
  parameter bit [129:0] P1305 = 2**130 - 5;

  typedef bit [BLOCK_BYTES-1:0][7:0] poly_blk_t;
  typedef bit [ACCUM_BYTES-1:0][7:0] poly_acc_t;

  typedef bit [15:0][7:0] poly_tag_t;
  
  function automatic [15:0][7:0] le_bytes_to_num ();
    input logic [15:0][7:0] k_in;
    
    logic [15:0][7:0] k;

    for (int i = 0; i < 16; i = i + 1) k[i] = k_in[15-i];
    return k;
  endfunction

endpackage : qnigma_poly1305_pkg