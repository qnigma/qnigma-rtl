package qnigma_crypt_pkg;
  
  typedef bit [31:0][7:0] key_t; // Elliptic Curve Key (256-bit X25519)

  function automatic key_t dec_litte_endian();
    input key_t in;
    key_t out;
    for (int i = 0; i < 32; i = i + 1) out[i] = in[31-i];
    dec_litte_endian = out;
  endfunction

  function automatic key_t dec_scalar_25519 ();
    input key_t k;
    key_t k_list;
    k_list = k;
    k_list[31] = k_list[31] & 248;
    k_list[0] = k_list[0] & 127;
    k_list[0] = k_list[0] | 64;
    k_list = dec_litte_endian(k_list);
    dec_scalar_25519 = k_list;
  endfunction

endpackage : qnigma_crypt_pkg