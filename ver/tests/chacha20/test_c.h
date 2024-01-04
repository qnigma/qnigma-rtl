#ifndef TEST_ALU_C
#define TEST_ALU_C

#include "../../src/model_ifc_c.h"
#include "../../src/field_c.h"
#include <random>
#include <array>
/*
 * Perform Aritmetic Unit verification for Curve25519 and Poly1305
 * Target RTL modules
 * 1. qnigma_alu (top)
 * 2. qnigma_alu_core
 * Flow:
 * 1. Verify against testvector with boundary values
 * 2. Verify against random values
 * Coverage:
 * 1. Modular addition
 * 2. Modular subtraction
 * 3. Modular multiplication
 * 4. Modular multiplcative inverse
 */

class test_c
{
private:
    static const unsigned RESET_TICKS = 50;
    static const unsigned MAX_STRING_LEN = 128;
    static const unsigned TEST_TIMEOUT = 1000000;
    static const unsigned TESTS_TOTAL = 4;

    unsigned cur_test; // Current test being run
    using key_t = field_c::long_int<8>;
    using nonce_t = field_c::long_int<3>;
    unsigned cur_len;
    unsigned ctr_rst;

    unsigned tests_passed;
    unsigned tests_failed;
    std::vector<uint8_t> plaintext_check;
    struct test_vect_t
    {
        key_t key;            // Private key
        nonce_t non;          // Nonce
        uint32_t ini_blk_ctr; // initial block counter
        std::string plaintext;
        std::vector<uint8_t> ciphertext;
    };

    test_vect_t test_vect[TESTS_TOTAL];
    unsigned to_ctr;
    std::vector<uint8_t> ciphertext_check;
    unsigned cur_str_idx;

    enum
    {
        SETUP,
        LOAD_PRIVATE_KEY,
        LOAD_NONCE,
        DEASSERT_RESET,
        GEN_POLY1305_OTK,
        CHECK_POLY_OTK,
        RUN_TEST,
        RESULT
    } state;

public:
    // Define range of the distribution

    // Constructor
    test_c(Vtop *tb);

    ~test_c();

    template <size_t N>
    static void display(const field_c::long_int<N> &tb_val);

    bool run(
        Vtop *tb);

    void disp_result(
        const bool &pass);
};
#endif
