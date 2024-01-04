
#include <iostream>

#include <stdlib.h>
#include <stdio.h>

// #include "Vtop_top.h"
#include "Vtop.h"

#include "verilated.h"
#include "verilated_vcd_c.h"

VerilatedVcdC *tfp;
Vtop *tb;

unsigned tim = 0;
unsigned const SIMTIME = 2500000;

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
  // printf("ECC engine tesbench\n");
  if (tfp)
  {
    tb->trace(tfp, 99);
    tfp->open("poly1305.vcd");
  }
  tb->rst = true;
  while (tim < SIMTIME && !tb->don)
  {
    if (tim == 100)
      tb->rst = false;
    tick(tim++, tb, tfp);
  }
  if (tfp)
    tfp->close();
  printf("done");
}
