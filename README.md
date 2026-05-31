# 8088 Assembly Lab

Real-mode 8088/8087 DOS assembly projects for vintage PCs, XT-class systems, emulators, serial transfers, and green-screen math demos.

This repository is planned as a growing collection of small, understandable DOS `.COM` assembly projects. The first project is **Galaxy16**, a live monochrome-green galaxy math display that detects an 8087 and can switch between 8087 floating-point math and 8088-safe integer math.

## Repository description for GitHub

**Real-mode 8088/8087 DOS assembly projects for vintage PCs — TASM/TLINK builds, serial-transfer notes, and green-screen math demos.**

## Current projects

| Project | Folder | Description |
|---|---|---|
| Galaxy16 | `projects/Galaxy16/` | Live 8088/8087 galaxy-ring math monitor. Green text, direct video RAM, no disk writes while running. |

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

Manual build:

```bat
TASM Galaxy16.asm
TLINK /T Galaxy16.OBJ
Galaxy16
```

## Galaxy16 controls

```text
F      Force 8087 FPU math engine, if an 8087 is detected
I      Force 8088 integer fallback math engine
Q/ESC  Quit
```

## Important tool note

This repository does **not** include `TASM.EXE`, `TLINK.EXE`, Tera Term, or Kermit. Add your own legally obtained copies of tools locally. The docs explain the workflow and link to public tool pages where appropriate.

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
