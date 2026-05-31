# 8088 Assembly Lab

Real-mode 8088/8087 DOS assembly projects for vintage PCs, XT-class systems, emulators, serial transfers, and green-screen math demos.

This repository is planned as a growing collection of small, understandable DOS `.EXE` assembly projects. The first project is **Galaxy20**, a live monochrome-green galaxy math display that detects an 8087 math coprocessor and can switch between 8087 floating-point math and 8088-safe integer math.

## Repository description for GitHub

**Real-mode 8088/8087 DOS assembly projects for vintage PCs — TASM/TLINK `.EXE` builds, serial-transfer notes, and green-screen math demos.**

## Current projects

| Project | Folder | Description |
|---|---|---|
| Galaxy20 | `projects/Galaxy20/` | Live 8088/8087 galaxy-ring math monitor. Green text, direct video RAM, no disk writes while running. Builds as a DOS `.EXE` program. |

## Folder layout

```text
8088-Assembly-Lab/
├── README.md
├── LICENSE
├── .gitignore
├── .gitattributes
├── PROJECT_IDEAS.md
├── docs/
│   ├── SERIAL_TRANSFER.md
│   ├── TASM_TLINK_SETUP.md
│   └── Galaxy20_NOTES.md
├── tools/
│   ├── README.md
│   ├── CLEAN.BAT
│   ├── RECEIVE.BAT
│   ├── RECVASM.INI
│   ├── TASM.zip
│   └── KERMIT.zip
└── projects/
    └── Galaxy20/
        ├── Galaxy20.asm
        ├── BUILD.BAT
        └── RUNME.TXT
```

## Quick build for Galaxy20

From DOS, FreeDOS, DOSBox, or a DOS-capable environment where `TASM.EXE` and `TLINK.EXE` are available:

```bat
CD PROJECTS\Galaxy20
BUILD
```

The build script assembles and links the program as a DOS `.EXE` file.

Expected output:

```text
Galaxy20.EXE
```

Run it with:

```bat
Galaxy20
```

or:

```bat
Galaxy20.EXE
```

## Manual build

The old TASM/TLINK workflow does not need file extensions on the command line. Use the base program name only.

For `Galaxy20.asm`, run:

```bat
TASM Galaxy20
TLINK Galaxy20
Galaxy20
```

TASM reads `Galaxy20.asm` and creates `Galaxy20.obj`.

TLINK reads `Galaxy20.obj` and creates `Galaxy20.exe` by default.

Important: do **not** use `TLINK /T` for this repository's normal build. The `/T` option is for tiny `.COM` output. This repository is documenting the plain `TASM programname` then `TLINK programname` workflow that produces a DOS `.EXE` file.

## Galaxy20 controls

```text
F      Force 8087 FPU math engine, if an 8087 is detected
I      Force 8088 integer fallback math engine
Q/ESC  Quit
```

## Galaxy20 rate display

Galaxy20 shows a dynamic `RATE:` field instead of a raw frame-loop counter. The value is estimated from completed ring-calculation steps during one BIOS timer interval and scaled to a per-second rate.

The unit changes automatically so the display makes sense on slow and fast DOS systems:

```text
OPS    operations per second
KOPS   thousands of operations per second
MOPS   millions of operations per second
```

For example, a slow XT-class system may show `RATE:528 OPS`, while a faster DOS PC or emulator may show `RATE:12 KOPS` or higher. The small spinner/art marker is kept close to the rate unit so the status line looks tighter.

## Galaxy20 randomized galaxy values

Galaxy20 creates a slightly different galaxy every run, and now refreshes the live mass inputs every 25 main display iterations. Each ring receives independent randomized mass-style values:

```text
BAR   random 1 to 100
DRK   random 1 to 100
GAS   random 1 to 10
```

`BAR` and `DRK` are generated separately, so they are not tied to each other. `GAS` is also generated separately using its own 1-to-10 range. The first set is initialized when the program starts, then BAR/DRK/GAS are regenerated after every 25 main display iterations so slower and faster DOS PCs both show a live-changing galaxy input set.

## Included tool archives

The `tools/` folder currently includes user-supplied convenience archives:

```text
tools/TASM.zip     Old TASM/TLINK tool archive
tools/KERMIT.zip   MS-DOS Kermit archive for serial transfer work
```

`TASM.zip` contains the old `TASM.EXE` and `TLINK.EXE` tools used by the build examples.

`KERMIT.zip` contains MS-DOS Kermit files for moving source, batch, executable, and support files to a vintage DOS machine over serial.

Before publicly redistributing third-party tool archives, make sure you have the right to include them. The original assembly source, notes, and project files in this repository are separate from any external assembler, linker, terminal, or file-transfer programs.

## About `.BAT` and `.INI` files

This repository includes helper `.BAT` and `.INI` files.

`.BAT` files are DOS/Windows batch files. They automate common steps such as building a project, cleaning build outputs, or starting a receive workflow.

`.INI` files are plain-text configuration files. In this repo, `RECVASM.INI` is used as a simple MS-DOS Kermit receive configuration.

Useful examples:

```text
projects/Galaxy20/BUILD.BAT   Builds Galaxy20.EXE
tools/CLEAN.BAT               Deletes local build outputs in the current folder
tools/RECEIVE.BAT             Starts Kermit receive mode using RECVASM.INI
tools/RECVASM.INI             Kermit receive settings
```

Both `.BAT` and `.INI` files are meant to be opened, inspected, and edited with a normal text editor.

Generated files such as `.OBJ`, `.MAP`, `.EXE`, and `.COM` are build outputs and are excluded by `.gitignore`.

## Suggested future project folders

```text
projects/
├── Galaxy20/
├── CLOCK88/
├── BENCH88/
├── SERIALDIAG88/
├── PRIME88/
└── VIDRAM88/
```

## License

The project source files, notes, and original project files in this repository are released under the MIT License unless a future project folder states otherwise.

Third-party tools, if included or added locally, remain under their own original licenses.
