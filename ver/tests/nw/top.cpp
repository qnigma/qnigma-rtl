
#include <memory>
#include <iostream>

#include <stdlib.h>
#include <stdio.h>

// #include "Vtop_top.h"
#include "Vtop.h"

#include "../../src/test_c.h"
#include "../../src/prm_c.h"

#include "verilated.h"
#include "verilated_vcd_c.h"

VerilatedVcdC *tfp;
Vtop *tb;

unsigned tim = 0;

unsigned status;
unsigned SIMULATION_TIMEOUT = 5000000;

void tick(int tim, Vtop *tb, VerilatedVcdC *tfp)
{
  tb->eval();
  if (tfp)
    tfp->dump(tim * 2);
  tb->clk = 0;
  tb->phy_rx_clk = 0;

  tb->eval();
  if (tfp)
    tfp->dump(tim * 2 + 1);
  tb->clk = 1;
  tb->phy_rx_clk = 1;

  tb->eval();
  if (tfp)
    tfp->flush();
}

test_c *test;

int main(int argc, char **argv)
{
  tb = new Vtop;
  int error = 0;

  Verilated::commandArgs(argc, argv);
  Verilated::traceEverOn(true);
  VerilatedVcdC *tfp = new VerilatedVcdC;
  test = new test_c();

  printf("TCP testbench\n");
  if (tfp)
  {
    tb->trace(tfp, 99);
    tfp->open("nw.vcd");
  }

  tb->rst = false;
  while (tim < SIMULATION_TIMEOUT)
  {
    tick(++tim, tb, tfp);
    if (test->run(tb, tim))
      break;
    if (tim > 1)
      tb->rst = false;
  }
  if (tfp)
    test->~test_c();
  return false;
}
