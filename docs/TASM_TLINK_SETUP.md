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
C:\8088LAB\PROJECTS\GALAXY16\GALAXY16.ASM
```

## PATH setup

Add the assembler folder to `AUTOEXEC.BAT`:

```bat
PATH C:\DOS;C:\TASM;%PATH%
```

Then reboot or run the PATH command manually.

## Build Galaxy16

```bat
CD \8088LAB\PROJECTS\GALAXY16
TASM GALAXY16.ASM
TLINK /T GALAXY16.OBJ
GALAXY16
```

The `/T` option tells TLINK to create a DOS `.COM` program instead of an `.EXE`.

## Clean rebuild

```bat
DEL GALAXY16.OBJ
DEL GALAXY16.COM
TASM GALAXY16.ASM
TLINK /T GALAXY16.OBJ
GALAXY16
```
