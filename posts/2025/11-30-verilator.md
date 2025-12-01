%{
  title: "Setting up Verilator for SystemVerilog",
  author: "Annabelle Adelaide",
  tags: ~w(fpga,simulation,systemverilog),
  description: "Basic setup of verilator"
}
---

# Setting up Verilator for SystemVerilog 

I have used a good amount of SystemVerilog for working on FPGA projects. At a certain level of abstraction
my eyes start to glaze over with how it handles functions and modules. To me, a simple verilog user,
it's becomes layers of imports and macros that are hard to parse. To that end, I wanted to give myself
some focused space to work on it. `verilator` is an open source simulator and linter. Verilators documentation is
at [https://verilator.org]

## Install

I run ubuntu, so this was a simple `apt-get install verilator`. I already have gtkwave installed as well.

## Minimal demo

I started with a simple hello world to get an understanding of the verilator workflow.

```verilog
// hello.v
module hello;
  initial begin $display("Hello world"); $finish; end
endmodule
```

To build a c++ simulation file, run:

```bash
$ verilator --binary -j 0 -Wall hello.v
```

and run:

```bash
$ obj_dir/Vhello
Hello world
- hello.v:2 Verilog $finish
```

Since I was recently introduced to `just` and hate writing making files, I wrote a quick `justfile` to run
and build with verilator:

```just
build target:
    verilator --binary -j 0 -Wall {{target}}.v

run target: (build target)
    obj_dir/V{{target}}
```

Now I can run:

```
$ just run hello
```

and it build and runs :). Not handling every case right now, but nice for my purposes.
Looking at what `verilator` is doing internally, it is essentially just building a c++ project with
auto-generated headers and a object which rnus through the verilog file.

## C++ exectuion

I can also call my translated SystemVerilog from a C++ wrapper. I put it in a file `sim_main.cpp`:

```c++
#include "Vhello.h"
#include "verilated.h"

int main(int argc, char** argv){
  // Create context
  VerilatedContext* contextp = new VerilatedContext;
  contextp->commandArgs(argc, argv);

  // Create instance of the inner verilog object
  Vhello* top = new Vhello{contextp};

  // Run
  while (!contextp->gotFinish()){
    top->eval();
  }

  // Cleanup
  delete top;
  delete contextp;
  return 0;
}
```

I can add some lines to my `justfile`:

```just
cpp wrapper target:
    verilaor --cc --exe --build -j 0 -Wall {{wrapper}} {{target}}.v

runcpp wrapper target: (cpp wrapper target)
    obj_dir/V{{target}}
```

Running `just runcpp sim_main.cpp hello`, builds and runs the program.
