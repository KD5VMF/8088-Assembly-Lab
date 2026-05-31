# TASM/TLINK setup notes

This repository assumes Borland/Turbo Assembler style tools:

```text
TASM.EXE
TLINK.EXE
```

These tools are not included in this repository. Use your own legally obtained copies.

## Typical folder layout on DOS

```text
C:\TASM\TASM.EXE
C:\TASM\TLINK.EXE
C:\8088LAB\PROJECTS\GALMATH16\GALMATH16.ASM
```

## PATH setup

Add the assembler folder to `AUTOEXEC.BAT`:

```bat
PATH C:\DOS;C:\TASM;%PATH%
```

Then reboot or run the PATH command manually.

## Build GALMATH16

```bat
CD \8088LAB\PROJECTS\GALMATH16
TASM GALMATH16.ASM
TLINK /T GALMATH16.OBJ
GALMATH16
```

The `/T` option tells TLINK to create a DOS `.COM` program instead of an `.EXE`.

## Clean rebuild

```bat
DEL GALMATH16.OBJ
DEL GALMATH16.COM
TASM GALMATH16.ASM
TLINK /T GALMATH16.OBJ
```

## Troubleshooting

### Relative jump out of range

Older x86 short jumps are limited. The project avoids most risky short-jump patterns by using near `JMP` chains in places that grew large during development.

### Program displays oddly

GALMATH16 does not change video mode. Before running it, make sure the DOS screen is already in an 80-column color text mode. If needed, run:

```bat
MODE CO80
```

### No green screen / wrong screen memory

GALMATH16 writes directly to color text video memory at `B800h`. It expects CGA/EGA/VGA/SVGA-compatible color text memory.
