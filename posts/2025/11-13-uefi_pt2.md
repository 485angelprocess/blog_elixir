%{
  title: "UEFI bootloader with nim pt 2",
  author: "Annabelle Adelaide",
  tags: ~w(nim,os,uefi),
  description: "Getting a minimal uefi bootloader up using nim"
}
---
# UEFI Bootloader using nim

This is mostly following (Fusion OS)[https://0xc0ffee.netlify.app/osdev]. I'm interested in going through
to pick up both some os ideas and learn nim in a deeper way.

## Entry point

We need a nim function which matches the UEFI specification's entry point.
This can be done using the following nim code:

```nim
import libc
import malloc

type
  EfiStatus = uint
  EfiHandle = pointer
  EFiSystemTable = object  # to be defined later

const
  EfiSuccess = 0

proc NimMain() {.importc.}

proc EfiMain(imgHandle: EfiHandle, sysTable: ptr EFiSystemTable): EfiStatus {.exportc.} =
  NimMain()
  return EfiSuccess
```

This reuses `libc` and `malloc`, from the previous post. The types here match the UEFI specification.
`NimMain` is also used to get the nim definitions.


## UEFI firmware

QEMU defaults to a legacy BIOS, `ovmf` on ubuntu should cover it.

For my machine I could run QEMU using ovmf:

```bash
qemu-system-x86_64 \
  -machine q35 \
  -drive if=pflash,format=raw,readonly=on,file=/usr/share/ovmf/OVMF.fd \
  -drive format=raw,file=fat:rw:diskimg \
  -net none
```

This launches qemu with the q35 chipsets, and loads the firmware from ovmf. Older tutorials have separate
OVMF_VARS and OVMF_CODE, but for at least my setup those seem to be merged.
Qemu automatically looks in the `diskimg/efi/boot` folder for bootable programs.

This runs correctly, opening a boot screen if my bootloader returns success, and crashes if it returns failure.

## System Table

The system table was left as a stub, but I needed to define the whole structure, so now in `src/bootx64.nim`:

```nim
type
  EfiStatus = uint

  EfiHandle = pointer

  EfiTableHeader = object
    signature: uint64
    revision: uint32
    headerSize: uint32
    crc32: uint32
    reserved: uint32

  EfiSystemTable = object
    header: EfiTableHeader
    firmwareVendor: WideCString
    firmwareRevision: uint32
    consoleInHandle: EfiHandle
    conIn: pointer
    consoleOutHandle: EfiHandle
    conOut: ptr SimpleTextOutputProtocol
    standardErrorHandle: EfiHandle
    stdErr: ptr SimpleTextOutputProtocol
    runtimeServices: pointer
    bootServices: pointer
    numTableEntries: uint
    configTable: pointer
  
  SimpleTextOutputProtocol = object
    reset: pointer
    outputString: proc (this: ptr SimpleTextOutputProtocol, str: WideCString): EfiStatus {.cdecl.}
    testString: pointer
    queryMode: pointer
    setMode: pointer
    setAttribute: pointer
    clearScreen: proc (this: ptr SimpleTextOutputProtocol): EfiStatus {.cdecl.}
    setCursorPos: pointer
    enableCursor: pointer
    mode: ptr pointer

const
  EfiSuccess = 0
  EfiLoadError = 1
```

This gives us access to the fields to get console in/out

## Console out

Now in our main program we can manipulate the console. A good start is clearing the screen.

```nim
proc EfiMain(imgHandle: EfiHandle, sysTable: ptr EfiSystemTable): EfiStatus {.exportc.} =
  NimMain()
  discard sysTable.conOut.clearScreen(sysTable.conOut)
  quit()
```

`quit` halts the CPU so that out program does not exit. This clears the screen correctly in qemu.


Next I can add output:

```nim
proc W*(str: string): WideCString =
  newWideCString(str).toWideCString

proc EfiMain(imgHandle: EfiHandle, sysTable: ptr EfiSystemTable): EfiStatus {.exportc.} = 
  NimMain()

  discard sysTable.conOut.clearScreen(sysTable.conOut)
  discard sysTable.conOut.outputString(sysTable.conOut, W"hi :) welcome\n")
  quit()
```

The Fusion OS post mentions needing to explicitly set the `nimv2` flag. This is no longer neccessary, I'm running
nim verions 2.2.4.

Next I moved the uefi structures to a separate file, and set the fields to public (`*` after a declaration sets it to public in nim).

I added a variable `sysTable` which holds the uefi table. Then I added a few simple console commands:

```nim
proc consoleClear*() =
  assert not sysTable.isNil
  discard sysTable.conOut.clearScreen(sysTable.conOut)

proc consoleOut*(str: string) =
  assert not sysTable.isNil
  discard sysTable.conOut.outputString(sysTable.conOut, W(str))

proc consoleError*(str: string) =
  assert not sysTable.isNil
  discard sysTable.stdErr.outputString(sysTable.stdErr, W(str))
```

Back in `libc.nim` I added a bit to `fwrite` so that it now works as expected (well until there are multiline outputs).

```nim
proc fwrite*(buf: const_pointer, size: csize_t, count: csize_t, stream: File): csize_t {.exportc.} =
  let output = $cast[cstring](buf)
  consoleOut(output)
  return count
```

The main function is now:

```nim
proc EfiMain(imgHandle: EfiHandle, sysTable: ptr EFiSystemTable): EfiStatus {.exportc.} =
  NimMain()
  uefi.sysTable = sysTable

  consoleClear()
  echo "Hi welcome!"

  quit()
```

This prints out nicely to the console :)

