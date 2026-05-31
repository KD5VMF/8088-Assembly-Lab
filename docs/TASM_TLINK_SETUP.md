# TASM/TLINK setup notes

This repository uses the old Borland/Turbo Assembler style workflow:

```text
TASM.EXE
TLINK.EXE
```

The normal command pattern is:

```bat
TASM programname
TLINK programname
programname
```

No file extensions are needed on the command line.

For example, if the source file is:

```text
Galaxy16.asm
```

then build and run it with:

```bat
TASM Galaxy16
TLINK Galaxy16
Galaxy16
```

TASM reads `Galaxy16.asm` and creates `Galaxy16.obj`.

TLINK reads `Galaxy16.obj` and creates `Galaxy16.exe` by default.

## Important `.EXE` note

Do **not** use `TLINK /T` for the normal Galaxy16 build.

`TLINK /T` is the tiny-model option normally used when intentionally creating `.COM` output. The documented workflow for this repository is the plain two-command build that produces a DOS `.EXE` file:

```bat
TASM Galaxy16
TLINK Galaxy16
```

## Tools included in this repo

The `tools/` folder includes a user-supplied `TASM.zip` archive. It contains the old TASM/TLINK programs used by the examples.

A common setup is to extract that archive so the tools are available in a folder such as:

```text
C:\TASM\TASM.EXE
C:\TASM\TLINK.EXE
```

Then add the tool folder to `AUTOEXEC.BAT`:

```bat
PATH C:\DOS;C:\TASM;%PATH%
```

After that, reboot or run the PATH command manually.

## Typical DOS project layout

```text
C:\TASM\TASM.EXE
C:\TASM\TLINK.EXE
C:\8088LAB\PROJECTS\GALAXY16\GALAXY16.ASM
```

## Build Galaxy16

```bat
CD \8088LAB\PROJECTS\GALAXY16
TASM GALAXY16
TLINK GALAXY16
GALAXY16
```

Expected build products:

```text
GALAXY16.OBJ
GALAXY16.MAP
GALAXY16.EXE
```

## Clean rebuild

```bat
DEL GALAXY16.OBJ
DEL GALAXY16.MAP
DEL GALAXY16.EXE
TASM GALAXY16
TLINK GALAXY16
GALAXY16
```
