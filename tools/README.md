# Tools folder

This folder contains helper notes, batch files, transfer settings, and user-supplied tool archives for the 8088 Assembly Lab workflow.

## Included files

```text
README.md      This file
CLEAN.BAT      Simple cleanup helper for local build outputs
RECEIVE.BAT    Starts MS-DOS Kermit receive mode using RECVASM.INI
RECVASM.INI    Example MS-DOS Kermit receive settings
TASM.zip       User-supplied old TASM/TLINK archive
KERMIT.zip     User-supplied MS-DOS Kermit archive
```

## TASM/TLINK archive

`TASM.zip` contains the old TASM/TLINK tools used by the project build examples, including:

```text
TASM.EXE
TLINK.EXE
```

The normal build pattern is:

```bat
TASM programname
TLINK programname
programname
```

Example:

```bat
TASM Galaxy16
TLINK Galaxy16
Galaxy16
```

That produces `Galaxy16.EXE`.

Do not use `TLINK /T` for the normal repo build. `/T` is for tiny `.COM` output.

## Kermit archive

`KERMIT.zip` contains MS-DOS Kermit files for moving files over serial to a vintage DOS/8088 machine.

`RECEIVE.BAT` and `RECVASM.INI` are simple starter helpers for receive mode. Edit `RECVASM.INI` if your serial port or baud rate is different.

Default settings:

```text
Port:  COM1
Speed: 9600
Type:  Binary
```

## Publishing note

Before publicly redistributing third-party tool archives, make sure you have the right to include them. The original source files and documentation in this repository are separate from any external assembler, linker, terminal, or transfer program.

If you only want to publish the original source/documentation, remove `TASM.zip` and `KERMIT.zip` before pushing the repository.
