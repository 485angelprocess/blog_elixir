%{
  title: "Forth machine - Basic Setup",
  author: "Annabelle Adelaide",
  tags: ~w(forth),
  description: "Starting a bootstrapped forth assembler"
}
---

# Forth machine - Basic setup

A project I've been revolving in my head for a long time is a forth core design.

The core should be completely ergonmic for forth, a stack based functional language.

There are some takeaways I want to get from other projects:

- [sapf](https://github.com/lfnoise/sapf) forms for repeatable set up, as well as lazy lists
- [astil_forth](https://github.com/mitranim/astil_forth) error handling forth
- [frugal](https://github.com/hoytech/frugal) minimal forth implementation

My higher goal is to develop multiprocessor set up for exploring digital video synthesis without the poor implemnentation of glsl.

## First steps

I'm busy a lot right now, so I'm incrementally building this up.

My start is to design the control loop. This is the human-centered basis of a forth interpreter.

For my purposes:
- Reads character input into a line buffer
- Looks up each word in the function buffer
- Runs that function

I'm starting with just this first step.

Now the bootstrapping of this system should be done within the system.
I start with a simulation of the system which can create a compiled program, loaded onto a real hardware system which can do the same.

General constraints:
- Functions return 1 value, take max 3 arguments

## Very basics

First I need to way to test the simulator works in order to bootstrap a compiler.

First test:

```
1 assert
```

This requires a minimal control loop and the assertion function.

## Interpreter loop

So for bootstrapping I need a function which transforms any int to the instructions needed to place that immediate onto the stack.

As a simple start point the core has two immediate instructions for bytes and words.

```forth
: interpret
  searchfunc if call ret then \ Looks up in dictionary
  isint  if imm  ret then \ Adds imm to stack
  INTERPRET_ERROR error
;
```

These functions might be broken down further, for now they are easy enough to write for simulation and I'm not trying to get too bogged down.

As a simple python setup:
```python
@staticmethod
def interpret(ctx: ForthContext):
    # Call function
    id = BaseLibrary.searchfunc(ctx)
    if id > 0:
        ctx.push(id)
        BaseLibrary.call(ctx)
        return

    # Immediate
    if BaseLibrary.isint(ctx):
        ctx.trace(f"{ctx.word}")
        ctx.push(BaseLibrary.imm(ctx))
        return
```

This doesn't quite use the stack and registers as tidy as I'd want but a start.

I add another simple test:
```forth
1 2 + 3 == assert \ Addition
```

## Define

Next I need a way to define new functions. For an easy control loop, I just added a conditional check:

```forth
: interpret
  isdefine if define ret then \ Defines new words
  searchfunc if call ret then \ Looks up in dictionary
  isint  if imm  ret then \ Adds imm to stack
  INTERPRET_ERROR error
;
```

The define function could be a separate function pointer which is moved, which may save cycles in the loop.

I use a register for the `DEFINE_STATE` which tracks if I am defining the label or the function, and should also help with the function comment.

For each word:

- ':' is a function which sets the define state to `label`
- if define state is `label` store this word as the name of function. Set the state to `functions` (could add comments here)
- if define state is `functions`, append the functions or immediates to a buffer
- `;` defines a new function, it's name is added to the dictionary and the functions are stored to the main function body. Exits the define mode.

Now I can test with:
```forth
: square dup * ;
4 square 16 == assert
```

So I have enough baseline functionality to lookup immediates and functions and to define new words.

Next steps are to add assembly instructions which can bootstrap this control loop onto special hardware.
Then test using a hardware sim.

I might pursue the same for risc-v for some flexibility in hardware targets as well.
