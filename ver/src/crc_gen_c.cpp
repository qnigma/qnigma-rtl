#include "crc_gen_c.h"

crc_gen_c::crc_gen_c()
{

  f.open("crc_table.txt", std::ios::out | std::ios::binary);
  if (f.fail())
    std::cout << "Error: Failed to open crc_table.txt \n";
  for (int i = 0; i < 256; i++)
  {
    uint32_t cur = i;
    for (int j = 0; j < 8; j++)
    {
      cur = (cur & 1) ? (cur >> 1) ^ CRC_POLY : cur >> 1;
    }
    crc_tbl[i] = cur;
    f << std::hex << cur << "\n";
  }
  f.close();
};
