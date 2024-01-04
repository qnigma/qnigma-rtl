#ifndef FIELD_C_H
#define FIELD_C_H

#include "pkt_c.h"
#include "Vtop__Syms.h"
#include <stdexcept>

class field_c
{

public:
    template <size_t N>
    struct long_int
    {
        bool operator==(const long_int<N> &other) const
        {
            for (size_t idx = 0; idx < sizeof(long_int); idx++)
                if (this->v[idx] != other.v[idx])
                    return false;
            return true;
        }

        bool operator!=(const long_int<N> &other) const
        {
            return !operator==(other);
        }

        bool operator>(const long_int<N> &other) const
        {
            for (size_t idx = sizeof(long_int); idx > 0; idx--)
                if (this->v[idx - 1] <= other.v[idx - 1])
                    return false;
            return true;
        }

        uint32_t v[N];
    };

    template <size_t N>
    static void set_int(WData *dut_val, const long_int<N> &tb_val, const unsigned &dut_limbs)
    {
        if (dut_limbs < N)
        {
            throw std::runtime_error("dut_limbs must be greater than or equal to N!");
            return;
        }
        for (size_t idx = 0; idx < N; idx++)
        {
            dut_val[idx] = tb_val.v[N - 1 - idx];
        }
        for (size_t idx = N; idx < dut_limbs; idx++)
        {
            dut_val[idx] = 0;
        }
    }

    using fld_25519_t = field_c::long_int<8>;

    using fld_1305_t = field_c::long_int<5>;

    const fld_25519_t P25519 = {
        0x7FFFFFFF,
        0xFFFFFFFF,
        0xFFFFFFFF,
        0xFFFFFFFF,
        0xFFFFFFFF,
        0xFFFFFFFF,
        0xFFFFFFFF,
        0xFFFFFFED};

    const fld_1305_t P1305 = {
        0x00000003,
        0xFFFFFFFF,
        0xFFFFFFFF,
        0xFFFFFFFF,
        0xFFFFFFFB};
};

#endif