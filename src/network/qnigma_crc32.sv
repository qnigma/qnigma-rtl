module qnigma_crc32 (
  input  logic        clk,
  input  logic        rst,
  input  logic [7:0]  dat,
  input  logic        val,
  output logic        ok,
  output logic [31:0] crc
);
  localparam [31:0] CRC_MAGIC_NUMBER = 32'hDEBB20E3;

  assign ok = (crc == CRC_MAGIC_NUMBER);
  logic [31:0] crc_reg;
  
  always_comb begin
    crc_reg[0] = (crc[2] ^ crc[8] ^ dat[2]);
    crc_reg[1] = (crc[0] ^ crc[3] ^ crc[9] ^ dat[0] ^ dat[3]);
    crc_reg[2] = (crc[0] ^ crc[1] ^ crc[4] ^ crc[10] ^ dat[0] ^ dat[1] ^ dat[4]);
    crc_reg[3] = (crc[1] ^ crc[2] ^ crc[5] ^ crc[11] ^ dat[1] ^ dat[2] ^ dat[5]);
    crc_reg[4] = (crc[0] ^ crc[2] ^ crc[3] ^ crc[6] ^ crc[12] ^ dat[0] ^ dat[2] ^ dat[3] ^ dat[6]);
    crc_reg[5] = (crc[1] ^ crc[3] ^ crc[4] ^ crc[7] ^ crc[13] ^ dat[1] ^ dat[3] ^ dat[4] ^ dat[7]);
    crc_reg[6] = (crc[4] ^ crc[5] ^ crc[14] ^ dat[4] ^ dat[5]);
    crc_reg[7] = (crc[0] ^ crc[5] ^ crc[6] ^ crc[15] ^ dat[0] ^ dat[5] ^ dat[6]);
    crc_reg[8] = (crc[1] ^ crc[6] ^ crc[7] ^ crc[16] ^ dat[1] ^ dat[6] ^ dat[7]);
    crc_reg[9] = (crc[7] ^ crc[17] ^ dat[7]);
    crc_reg[10] = (crc[2] ^ crc[18] ^ dat[2]);
    crc_reg[11] = (crc[3] ^ crc[19] ^ dat[3]);
    crc_reg[12] = (crc[0] ^ crc[4] ^ crc[20] ^ dat[0] ^ dat[4]);
    crc_reg[13] = (crc[0] ^ crc[1] ^ crc[5] ^ crc[21] ^ dat[0] ^ dat[1] ^ dat[5]);
    crc_reg[14] = (crc[1] ^ crc[2] ^ crc[6] ^ crc[22] ^ dat[1] ^ dat[2] ^ dat[6]);
    crc_reg[15] = (crc[2] ^ crc[3] ^ crc[7] ^ crc[23] ^ dat[2] ^ dat[3] ^ dat[7]);
    crc_reg[16] = (crc[0] ^ crc[2] ^ crc[3] ^ crc[4] ^ crc[24] ^ dat[0] ^ dat[2] ^ dat[3] ^ dat[4]);
    crc_reg[17] = (crc[0] ^ crc[1] ^ crc[3] ^ crc[4] ^ crc[5] ^ crc[25] ^ dat[0] ^ dat[1] ^ dat[3] ^ dat[4] ^ dat[5]);
    crc_reg[18] = (crc[0] ^ crc[1] ^ crc[2] ^ crc[4] ^ crc[5] ^ crc[6] ^ crc[26] ^ dat[0] ^ dat[1] ^ dat[2] ^ dat[4] ^ dat[5] ^ dat[6]);
    crc_reg[19] = (crc[1] ^ crc[2] ^ crc[3] ^ crc[5] ^ crc[6] ^ crc[7] ^ crc[27] ^ dat[1] ^ dat[2] ^ dat[3] ^ dat[5] ^ dat[6] ^ dat[7]);
    crc_reg[20] = (crc[3] ^ crc[4] ^ crc[6] ^ crc[7] ^ crc[28] ^ dat[3] ^ dat[4] ^ dat[6] ^ dat[7]);
    crc_reg[21] = (crc[2] ^ crc[4] ^ crc[5] ^ crc[7] ^ crc[29] ^ dat[2] ^ dat[4] ^ dat[5] ^ dat[7]);
    crc_reg[22] = (crc[2] ^ crc[3] ^ crc[5] ^ crc[6] ^ crc[30] ^ dat[2] ^ dat[3] ^ dat[5] ^ dat[6]);
    crc_reg[23] = (crc[3] ^ crc[4] ^ crc[6] ^ crc[7] ^ crc[31] ^ dat[3] ^ dat[4] ^ dat[6] ^ dat[7]);
    crc_reg[24] = (crc[0] ^ crc[2] ^ crc[4] ^ crc[5] ^ crc[7] ^ dat[0] ^ dat[2] ^ dat[4] ^ dat[5] ^ dat[7]);
    crc_reg[25] = (crc[0] ^ crc[1] ^ crc[2] ^ crc[3] ^ crc[5] ^ crc[6] ^ dat[0] ^ dat[1] ^ dat[2] ^ dat[3] ^ dat[5] ^ dat[6]);
    crc_reg[26] = (crc[0] ^ crc[1] ^ crc[2] ^ crc[3] ^ crc[4] ^ crc[6] ^ crc[7] ^ dat[0] ^ dat[1] ^ dat[2] ^ dat[3] ^ dat[4] ^ dat[6] ^ dat[7]);
    crc_reg[27] = (crc[1] ^ crc[3] ^ crc[4] ^ crc[5] ^ crc[7] ^ dat[1] ^ dat[3] ^ dat[4] ^ dat[5] ^ dat[7]);
    crc_reg[28] = (crc[0] ^ crc[4] ^ crc[5] ^ crc[6] ^ dat[0] ^ dat[4] ^ dat[5] ^ dat[6]);
    crc_reg[29] = (crc[0] ^ crc[1] ^ crc[5] ^ crc[6] ^ crc[7] ^ dat[0] ^ dat[1] ^ dat[5] ^ dat[6] ^ dat[7]);
    crc_reg[30] = (crc[0] ^ crc[1] ^ crc[6] ^ crc[7] ^ dat[0] ^ dat[1] ^ dat[6] ^ dat[7]);
    crc_reg[31] = (crc[1] ^ crc[7] ^ dat[1] ^ dat[7]);
  end

  always @ (posedge clk) crc <= (val) ? crc_reg : '1;


endmodule : qnigma_crc32
