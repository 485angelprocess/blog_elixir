%{
  title: "Using my bootloader to load a program",
  author: "Annabelle Adelaide",
  tags: ~w(nim,os,uefi),
  description: "Loading a minimal program from a UEFI bootloader"
}
---

# Booting into a program

The bootloader is running enough to create some framework for the kernel. After reorganizing some files,
my directory tree is looking like this:

```
.
├── justfile
├── nim.cfg
└── src
    ├── boot
    │   ├── bootx64.nim
    │   └── nim.cfg
    ├── common
    │   ├── libc.nim
    │   ├── malloc.nim
    │   └── uefi.nim
    ├── debugcon.nim
    └── kernel
        ├── main.nim
        └── nim.cfg
```

The nim configurations are split for their target. This is a nice feature of nim for organizing projects.
I added a kernel target for the `justfile` to create a binary:

```just
nimflags := "--os:any"

bootloader:
  nim c {{nimflags}} --out:build/bootx64.efi src/boot/bootx64.nim

kernel:
  nim c {{nimflags}} --out:build/kernel.bin src/kernel/main.nim

run: bootloader
  mkdir -p diskimg/efi/boot
  cp build/bootx64.efi diskimg/efi/boot/bootx64.efi
  qemu-system-x86_64 \
      -machine q35 \
      -drive if=pflash,format=raw,readonly=on,file=/usr/share/ovmf/OVMF.fd \
      -drive format=raw,file=fat:rw:diskimg \
      -net none
```

`debugcon.nim` is an interface for the qemu debug console. Once the bootloader finishes, there is no
longer access to the uefi console, and it would be more complex to write a serial driver to start. Qemu
offers an easy debug port which can be written to through memory:

```nim
const
  DebugConPort = 0xE9

proc portOut8(port: uint16, data: uint8) =
  asm """
    out %0, %1
    :
    :"Nd"(`port`), "a"(`data`)
  """

proc debug*(msgs: varargs[string]) =
  ## Send messages to the debug console.
  for msg in msgs:
    for ch in msg:
      portOut8(DebugConPort, ch.uint8)

proc debugln*(msgs: varargs[string]) =
  ## Send messages to the debug console. A newline is appended at the end.
  debug(msgs)
  debug("\r\n")
```

Note that nim initially complains about the assembly, saying that the there is an unkown mnemonic.
I added `--passc:"-masm=intel"` to interpret assembly in the intel syntax, which fixed the issue.

I added some additional flags to `src/kernel/nim.cfg`. First turning off special registers with the `-mgeneral-regs-only` switch,
and then disabling an automatic stack frame with `-mno-red-zone`.
The red zone is a scratch space made by the compiler when a function doesn't call anything.
The CPU will reuse this space in kernel mode, causing two sets of overlapping data in the memory space.

The `nim.cfg` looks like this:

```
amd64.any.clang.linkerexe="ld.lld"
--passc:"-mgeneral-regs-only"
--passc:"-mno-red-zone"
--passc:"-target x86_64-unknown-elf"
--passc:"-masm=intel"
--passc:"-ffreestanding"
--passl:"-nostdlib"
--passl:"-Map=build/kernel.map"
--passl:"-entry KernelMain"
```

Running `just kernel` produces a binary file. The elf information can be shown with `llvm-readelf --headers`. 
This elf file isn't quite right. The compiler needs some additional linking information, so that it loads
in the right location.

I can add a linker file in `src/kernel/kernel.ld`

```
SECTIONS
{
  . = 0x100000
  .text : { *(.text) }
  .rodata : { *(.rodata*) }
  .data : { *(.data) }
  .bss : { *(.bss) }

  /DISCARD/ : { *(*) }
}
```

Adding this and the `-passl:"-T src/kernel/kernel.ld"` argument creates an elf file which has an entry point
of `0x10B800`. Which is closer, but the linker is putting the `.text` section before the code we want to start into.
I have to find the kernel object and then throw it ahead of `.text`:

```
SECTIONS
{
  . = 0x100000;
  .text     : { *main*.o(.text) *(.text) }
  .rodata   : { *(.rodata*) }
  .data     : { *(.data) }
  .bss      : { *(.bss) }
  .shstrtab : { *(.shstrtab) }

  /DISCARD/ : { *(*) }
}
```

From what I can infer I want to match based on the name of my nim file (which is here `main`). This seems a little fraught,
as it would be easy to have a hanging object file with a similar name, which would cause problems.
But it's also not quite easy to guess how the compiler creates the object file.

I can check that this maps to the start of binary file:

```bash
$ head -n 10 build/kernel.map
    VMA              LMA     Size Align Out     In      Symbol
        0                0   100000     1 . = 0x100000
   100000           100000     b3e2    16 .text
   100000           100000      270    16         /home/anne/Documents/os/m os/build/@mmain.nim.c.o:(.text)
   100000           100000       89     1                 KernelMain
   100090           100090       86     1                 nimFrame
   100120           100120       17     1                 nimErrorFlag
   100140           100140       a9     1                 quit__system_u6454
   1001f0           1001f0       17     1                 popFrame
   100210           100210        6     1                 NimDestroyGlobals
```

I got a lot of the format working for the binary, but was having trouble getting the linker to recognize the `.bss`
section, or specifically to allocate the empty heap.

I tried a few options like moving `.bss` into the `.data` section, and adding a dummy section with a defined size after `.bss`.
But nothing was working. Turns out I had `-oformat=binary` instead of `--oformat-binary`, in the `nim.cfg`.

```
{
  . = 0x100000;
  .text     : {
    *main*.o(.text.KernelMain)
    *main*.o(.text.*)
    *(.text.*)
  }
  .rodata   : { *(.rodata*) }
  .data     : { *(.data) *(.bss) }
  .shstrtab : { *(.shstrtab) }

  /DISCARD/ : { *(*) }
}
```

This starts data at `0x100000`, finds the entry point, and then defines the sections. The binary output
file is now the correct size:

```bash
$ wc -c build/kernel.bin
1099760 build/kernel.bin
```

Now that I have a binary format I can use, I can start putting some real kernel operations in.
