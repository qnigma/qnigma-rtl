
#include <iostream>

#include <stdlib.h>
#include <stdio.h>

// #include "Vtop_top.h"
#include "Vtop.h"

#include "test_c.cpp"

#include "verilated.h"
#include "verilated_vcd_c.h"

VerilatedVcdC *tfp;
Vtop *tb;

unsigned tim = 0;
unsigned const SIMTIME = 2500;

test_c *test;

void tick(int tim, Vtop *tb, VerilatedVcdC *tfp)
{
  tb->eval();
  if (tfp)
    tfp->dump(tim * 2);
  tb->clk = 0;
  tb->eval();
  if (tfp)
    tfp->dump(tim * 2 + 1);
  tb->clk = 1;
  tb->eval();
  if (tfp)
    tfp->flush();
}

int main(int argc, char **argv)
{
  tb = new Vtop;

  Verilated::commandArgs(argc, argv);
  Verilated::traceEverOn(true);
  VerilatedVcdC *tfp = new VerilatedVcdC;

  test = new test_c(tb);

  if (tfp)
  {
    tb->trace(tfp, 99);
    tfp->open("dump_chacha20.vcd");
  }

  while (++tim < 300000000)
  {
    if (test->run(tb))
      break;
    tick(tim, tb, tfp);
  }
  if (tfp)
    test->~test_c();
  printf("done. simtime: %d", tim);
}
