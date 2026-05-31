# 8088 Assembly Lab

Real-mode 8088/8087 DOS assembly projects for vintage PCs, XT-class systems, emulators, serial transfers, and green-screen math demos.

This repository is planned as a growing collection of small, understandable DOS `.EXE` assembly projects. The first project is **Galaxy16**, a live monochrome-green galaxy math display that detects an 8087 math coprocessor and can switch between 8087 floating-point math and 8088-safe integer math.

## Repository description for GitHub

**Real-mode 8088/8087 DOS assembly projects for vintage PCs — TASM/TLINK `.EXE` builds, serial-transfer notes, and green-screen math demos.**

## Current projects

| Project  | Folder               | Description                                                                                                                          |
| -------- | -------------------- | ------------------------------------------------------------------------------------------------------------------------------------ |
| Galaxy16 | `projects/Galaxy16/` | Live 8088/8087 galaxy-ring math monitor. Green text, direct video RAM, no disk writes while running. Builds as a DOS `.EXE` program. |

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
│   └── Galaxy16_NOTES.md
├── tools/
│   └── README.md
└── projects/
    └── Galaxy16/
        ├── Galaxy16.asm
        ├── BUILD.BAT
        └── RUNME.TXT
```

## Quick build for Galaxy16

From DOS, FreeDOS, or a DOS-capable environment where `TASM.EXE` and `TLINK.EXE` are available:

```bat
CD PROJECTS\Galaxy16
BUILD
```

The build script assembles and links the program as a DOS `.EXE` file.

Expected output:

```text
Galaxy16.EXE
```

Run it with:

```bat
Galaxy16
```

or:

```bat
Galaxy16.EXE
```

## Manual build

To manually build Galaxy16:

```bat
TASM Galaxy16.asm
TLINK Galaxy16.OBJ
Galaxy16
```

Important: do **not** use `TLINK /T` for this project. The `/T` option creates a tiny `.COM`-style output. Galaxy16 is intended to build as a normal DOS `.EXE` program.

## Galaxy16 controls

```text
F      Force 8087 FPU math engine, if an 8087 is detected
I      Force 8088 integer fallback math engine
Q/ESC  Quit
```

## Important tool note

This repository does **not** include `TASM.EXE`, `TLINK.EXE`, Tera Term, Kermit, or other commercial/third-party transfer tools. Add your own legally obtained copies of tools locally.

The documentation explains the workflow and may reference public tool pages where appropriate.

## About `.BAT` and `.INI` files

This repository may include helper `.BAT` and `.INI` files.

`.BAT` files are DOS/Windows batch files used to make building, running, or transferring projects easier. For example, `BUILD.BAT` may assemble and link a project automatically.

`.INI` files are plain-text configuration files used by some tools or workflows. They may store serial settings, transfer settings, emulator settings, or project options.

Both `.BAT` and `.INI` files are meant to be opened, inspected, and edited with a normal text editor.

Generated files such as `.OBJ`, `.MAP`, and `.EXE` are build outputs and may be excluded from the repository depending on the `.gitignore` settings.

## Suggested future project folders

```text
projects/
├── Galaxy16/
├── CLOCK88/
├── BENCH88/
├── SERIALDIAG88/
├── PRIME88/
└── VIDRAM88/
```

## License

The project files in this repository are released under the MIT License unless a future project folder states otherwise.
