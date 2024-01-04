#ifndef TEST_ALU_C
#define TEST_ALU_C

#include "../../src/model_ifc_c.h"
#include "../../src/field_c.h"
#include <random>

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
    static const int RANDOM_CASES = 50;
    unsigned cur_test;
    std::mt19937 generator;

    field_c::fld_25519_t rand_25519_opa;
    field_c::fld_25519_t rand_25519_opb;

    field_c::fld_1305_t rand_1305_opa;
    field_c::fld_1305_t rand_1305_opb;

    unsigned err_ctr;
    unsigned pass_ctr;

    field_c::fld_25519_t gen_rand_25519(

    )
    {
        std::uniform_int_distribution<std::uint32_t> dist(0, UINT32_MAX);
        field_c::fld_25519_t val;
        val.v[0] = dist(generator) & 0x7FFFFFFF;
        val.v[1] = dist(generator) & 0xFFFFFFFF;
        val.v[2] = dist(generator) & 0xFFFFFFFF;
        val.v[3] = dist(generator) & 0xFFFFFFFF;
        val.v[4] = dist(generator) & 0xFFFFFFFF;
        val.v[5] = dist(generator) & 0xFFFFFFFF;
        val.v[6] = dist(generator) & 0xFFFFFFFF;
        val.v[7] = dist(generator) & 0xFFFFFFFF;

        if (val.v[0] == 0x7FFFFFFF &&
            val.v[1] == 0xFFFFFFFF &&
            val.v[2] == 0xFFFFFFFF &&
            val.v[3] == 0xFFFFFFFF &&
            val.v[4] == 0xFFFFFFFF &&
            val.v[5] == 0xFFFFFFFF &&
            val.v[6] == 0xFFFFFFFF &&
            val.v[7] >= 0xFFFFFFED)
            val.v[7] = val.v[7] - 19;

        return val;
    };

    field_c::fld_1305_t gen_rand_1305(

    )
    {
        std::uniform_int_distribution<std::uint32_t> dist(0, UINT32_MAX);
        field_c::fld_1305_t val;
        val.v[0] = dist(generator) & 0x00000003;
        val.v[1] = dist(generator) & 0xFFFFFFFF;
        val.v[2] = dist(generator) & 0xFFFFFFFF;
        val.v[3] = dist(generator) & 0xFFFFFFFF;
        val.v[4] = dist(generator) & 0xFFFFFFFB;

        if (val.v[0] == 0x00000003 &&
            val.v[1] == 0xFFFFFFFF &&
            val.v[2] == 0xFFFFFFFF &&
            val.v[3] == 0xFFFFFFFF &&
            val.v[4] >= 0xFFFFFFFB)
            val.v[4] = val.v[4] - 5;

        return val;
    };

public:
    // Define range of the distribution
    void disp_result(
        const unsigned &_pass_ctr,
        const unsigned &_err_ctr)
    {
        printf("Passed: %d, Failed: %d. ", _pass_ctr, _err_ctr);

        if (_err_ctr == 0)
            printf("\x1b[32m[OK]\x1b[0m\n");
        else
            printf("\x1b[31m[FAIL]\x1b[0m\n");
    };

    // Constructor
    test_c(
        Vtop *tb,
        unsigned int seed) : generator(seed)
    {
        state = SETUP;
        cur_test_op = op_none;
        cur_test = 0;
        err_ctr = 0;
        pass_ctr = 0;
    }

    ~test_c(){
        //        display_result(alu_err);
    };

    enum
    {
        SETUP,
        GEN_RAND,
        SET_DUT,
        REQUEST,
        RESULT,
        NEXT,
        RUN
    } state;

    enum
    {
        F25519,
        F1305
    } cur_field;

    enum
    {
        op_none,
        op_add,
        op_sub,
        op_mul,
        op_inv
    } cur_test_op; // Current operation being verified

    bool run(
        Vtop *tb)
    {
        switch (state)
        {
        case (SETUP):
        {
            tb->run = false;
            printf("=============================================== \n");
            printf("Performing ALU verfication ");
            if (cur_field == F25519)
            {
                printf("[Curve25519]\n");
            }
            else if (cur_field == F1305)
            {
                printf("[Poly1305]\n");
            }
            printf("Total testcases per operation: %d \n", RANDOM_CASES);
            printf("=============================================== \n");
            state = NEXT;
            break;
        }
        // Select next operand, next long_int or exit test
        case (NEXT):
        {
            state = GEN_RAND; // By default, next step is to generate random operands
            switch (cur_test_op)
            {
            case (op_none):
            {
                cur_test_op = op_add;
                printf("\x1b[34mVerifying modular addition...       \x1b[0m\n");
                break;
            }
            case (op_add):
            {
                cur_test_op = op_sub;
                printf("\x1b[34mVerifying modular subtraction...       \x1b[0m\n");
                break;
            }
            case (op_sub):
            {
                cur_test_op = op_mul;
                printf("\x1b[34mVerifying modular multiplication...       \x1b[0m\n");
                // return true; // Test complete
                break;
            }
            case (op_mul):
            {
                cur_test_op = op_inv;
              //  if (cur_field == F1305) // Don't test invert for Poly1305
                return true;        // Test complete
                printf("\x1b[34mVerifying modular inversion...       \x1b[0m\n");
                break;
            }
            case (op_inv):
            {
                cur_test_op = op_none; // Go to Poly1305 addition test
                cur_field = F1305;     // Next long_int is Prime 1305
                state = SETUP;         // Go setup the simulation
                break;
            }
            }
            break;
        }
        // Generate random operands for the DUT
        case (GEN_RAND):
        {
            if (cur_field == F25519)
            {
                rand_25519_opa = gen_rand_25519();
                rand_25519_opb = gen_rand_25519();
            }
            else if (cur_field == F1305)
            {
                rand_1305_opa = gen_rand_1305();
                rand_1305_opb = gen_rand_1305();
            }
            state = SET_DUT;
            break;
        }
        // Setup DUT nodes
        case (SET_DUT):
        {
            tb->fld_25519 = cur_field == F25519;
            if (cur_field == F25519)
            {
                field_c::set_int(tb->opa, rand_25519_opa, 8);
                field_c::set_int(tb->opb, rand_25519_opb, 8);
            }
            else if (cur_field == F1305)
            {
                field_c::set_int(tb->opa, rand_1305_opa, 8);
                field_c::set_int(tb->opb, rand_1305_opb, 8);
            }
            tb->test_add = cur_test_op == op_add;
            tb->test_sub = cur_test_op == op_sub;
            tb->test_mul = cur_test_op == op_mul;
            tb->test_inv = cur_test_op == op_inv;
            state = REQUEST;
            break;
        }
        // Request calculation
        case (REQUEST):
        {
            tb->run = true; // Note: deassert at next tick
            state = RUN;
            break;
        }
        // Run calculation
        case (RUN):
        {
            tb->run = false; // 1-tick request is enough, deassert here
            if (tb->done)
            {
                if (++cur_test == RANDOM_CASES)
                {
                    cur_test = 0;
                    state = RESULT; // All tests complete for current operation
                }
                else
                    state = GEN_RAND; // Tests remaining, generate new operands
                if (tb->pass)
                    pass_ctr++;
                else
                    err_ctr++;
            }
            break;
        }
        // Display result
        case (RESULT):
        {
            disp_result(pass_ctr, err_ctr);
            pass_ctr = 0;
            err_ctr = 0;
            state = NEXT; // Continue to next test
            break;
        }
        }
        return false;
    }
};
#endif
