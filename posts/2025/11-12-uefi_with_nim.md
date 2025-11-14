%{
    title: "UEFI Support with Nim",
    author: "Annabelle Adelaide",
    tags: ~w(nim,os,uefi),
    description: "Building a PE32+ application with nim/nostd"
}
---

# Getting UEFI support

This is the start of doing some OS work with nim. I'm using the really great documentation of [fusion os](https://0xc0ffee.netlify.app/osdev/) as a starting point.

## Getting UEFI with C

Since I'm interested in going through some of the work with Fusion OS, I am running an OS that has UEFI support. UEFI offers a unified interface for bootstrapping an OS.

UEFI expected a PE32+ (portable executable with 64-bit extension). This is a format used by windows, but adopted by UEFI, so it's something my OS has to follow. 

Fusion OS has a good overview of how to do this in C. A basic C program can be recognized as an PE32+ application. The clang command:

```bash
$ clang \
    -target x86_64-unknown-windows \
    -fuse-ld=lld-link \
    -nostdlib \
    -Wl,-entry:main \
    -Wl,-subsystem:efi_application \
    -o build/main.exe \
    build/main.o
```

This has the `no-std flag`, explicitly sets the main entry and acts the compiler to make it a UEFI application.

To check the file format:
```
file build/main.exe
```

## UEFI with nim

I start with a minimal nim function:

```nim
proc main(): int {.exportc.} =
    return 0
```

`{.exportc.}` is a pragma which tells nim explicitly not to mangle the function name.

The nim build command:

```bash
$ nim c \
    --nimcache:build \
    --cpu:amd64 \
    --os:any \
    --cc:clang \
    --passc:"-target x86_64-unknown-windows" \
    --passc:"-ffreestanding" \
    --passl:"-fuse-ld=lld-link" \
    --passl:"-nostdlib" \
    --passl:"-Wl,-entry:main" \
    --passl:"-Wl,-subsystem:efi_application" \
    --out:build/main.exe \
    src/main.nim
```

This uses a few flags to correclty route nim how we want. The cpu is set as `amd64`, the os needs to be set as `any` so that is not built as a linux application. `clang` is set as the the compiler, which can do uefi instead of `gcc`.

As pointed out in the Fusion OS documentation, this gives a memory error. Essentially nim doesn't know what the `malloc` function is if there's no OS specified.

I have to give nim the explicit memory management functions.

```nim
# malloc.nim

{.used.}

var
  heap*: array[1*1024*1024, byte] # 1 MiB heap
  heapBumpPtr*: int = cast[int](addr heap)
  heapMaxPtr*: int = cast[int](addr heap) + heap.high

proc malloc*(size: csize_t): pointer {.exportc.} =
  if heapBumpPtr + size.int > heapMaxPtr:
    return nil

  result = cast[pointer](heapBumpPtr)
  inc heapBumpPtr, size.int

proc calloc*(num: csize_t, size: csize_t): pointer {.exportc.} =
  result = malloc(size * num)
  
proc free*(p: pointer) {.exportc.} =
  discard

proc realloc*(p: pointer, new_size: csize_t): pointer {.exportc.} =
  result = malloc(new_size)
  copyMem(result, p, new_size)
  free(p)
```

The `{.used.}` pragma tells nim that this code is relevant. Otherwise it would be thrown out since the functions are not explicitly called.

Aside: I had to rearrange the function declarations, to put `free` up so that it is declared before the definition of `realloc`. I'm not sure if this is some quirk, or if nim does have required order (it really feels like a language that wouldn't).

I then needed to link clang to system libraries for some build tools by adding `--passc:"-I/usr/include" \` to the nim flags. I then got an error showing that `<bits/libc-header-start.h>` was missing. I used `$ dpkg -S /usr/include/bits` to find the missing package which was `libc6-dev-i386`.

The next error is nim finding a conflicing main function. This is solved by adding the `--noMain:on` flag, and adding a `proc NimMain()` to the main proc. My main file is now:

```nim
import malloc

proc NimMain() {.importc.}

proc main(): int{.exportc.} =
    NimMain()
    return 0
```

Now we get a series of errors which are asking for definitions of POSIX functions. Since I'm learning through how Fusion OS set this up, I am going to ignore some of these, but want to bookmark this step, since I may return to add some form of POSIX utility.

## Filling in missing functions

Nim still needs a few functions to be explicitly defined. `fwrite`, `fflush`, `stdout` and `exit`.

`fwrite` writes to a function, we can define a template (in `src/libc.nim`):

```
type
    const_pointer {.importc: "const void *".} = pointer
    
proc fwrite*(ptr: const_pointer, size: csize_t, count: csize_t, stream: File):
    csize_t {.exportc.} =
    return count
```

This is a nice example of nim's ability to do metaprogramming, nim does not define `const void *` which is needed by the function template, but we can simply give it the needed C definition and it will keep rolling. One thing that I notice here, is I'm following someone else's notes, so I know that `File` is defined, but I wouldn't have that off the top of my head. nim's documentation is not so amazing that I'd know what I didn't know in that regard.

Also still being used is the `.exportc.` macro which is preventing mangling.

The other function templates:

```
# fflush: flushes the stream
proc fflush*(stream: File): cint {.exportc.} =
  return 0.cint
  
# stdout and stderr
# global variables with the file struct
var
	stdout* {.exportc.}: File
	stderr* {.exportc.}: File
	
# exit function
proc exit*(status: cint) {.exportc, asmNoStackFrame.} =
	asm """
	.loop:
		cli
		hlt
		jmp .loop
	"""
```

The exit function is done with inline assembly, since the exit function can't return to any OS program. My libc can be imported in my main function, although it also requires the `{.used.}` pragma, since the functions aren't called.

The `{.asmNoStackFrame.}` tells the compiler not to put a stack frame around the asm code. I have only ever written just pure assembly, or flippantly was adding asm to C code every once in a while, so this is the most I've thought of how exaclty C handles inline asm. Dusk OS uses reserved registers in a similar way, which is a nice connection to make.

With this all together, I can at least compile to a PE32+ executable. I'm going to take a break for now, but next will be getting a UEFI bootloader.s
