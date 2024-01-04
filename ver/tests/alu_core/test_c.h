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

    unsigned err_ctr;
    unsigned pass_ctr;
    uint32_t rand_opa;
    uint32_t rand_opb;

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
        op_none,
        op_add,
        op_sub,
        op_mul
    } cur_test_op; // Current operation being verified

    uint32_t get_rand()
    {
        std::uniform_int_distribution<std::uint32_t> dist(0, UINT32_MAX);
        return dist(generator);
    };

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

public:
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
    };

    ~test_c(){
        //        display_result(alu_err);
    };

    bool run(
        Vtop *tb)
    {
        switch (state)
        {
        case (SETUP):
        {
            tb->cal = false;
            printf("=============================================== \n");
            printf("Performing ALU core verfication");
            printf("Total testcases per operation: %d \n", RANDOM_CASES);
            printf("=============================================== \n");
            state = NEXT;
            break;
        }
        // Select next operand, next long_int or exit test
        case (NEXT):
        {
            state = SET_DUT; // By default, next step is to generate random operands
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
                return true; // Test complete
                break;
            }
            }
            break;
        }
        // Setup DUT nodes
        case (SET_DUT):
        {
            // rand_opa = get_rand();
            // rand_opb = get_rand();
            rand_opa = 0x12345678;
            rand_opb = 0x23456789;

            tb->opa = rand_opa;
            tb->opb = rand_opb;
            tb->test_add = cur_test_op == op_add;
            tb->test_sub = cur_test_op == op_sub;
            tb->test_mul = cur_test_op == op_mul;
            state = REQUEST;
            break;
        }
        // Request calculation
        case (REQUEST):
        {
            tb->cal = true; // Note: deassert at next tick
            state = RUN;
            break;
        }
        // Run calculation
        case (RUN):
        {
            tb->cal = false; // 1-tick request is enough, deassert here
            if (tb->done)
            {
                uint64_t res = tb->res;
                printf("RESULT %lx", res);
                cur_test++;
                state = (cur_test == RANDOM_CASES) ? NEXT : SET_DUT;
            }
            break;
        }
            // Display result
        }
        return false;
    }
};

#endif
