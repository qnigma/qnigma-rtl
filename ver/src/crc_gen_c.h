#ifndef CRC_GEN_C_H
#define CRC_GEN_C_H

#include <fstream>
#include <iostream>

class crc_gen_c
{
public:
    uint32_t crc_tbl[256];

    std::ofstream f;

    const uint32_t CRC_POLY = 0xEDB88320;

    crc_gen_c();

    ~crc_gen_c(){};
};

#endif
