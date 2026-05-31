# Future 8088 Assembly Lab project ideas

This repository is set up for many small DOS `.EXE` assembly project folders.

```text
projects/
├── Galaxy16/       Live galaxy math display with 8087 support
├── CLOCK88/        High-resolution text/graphics clock experiments
├── BENCH88/        8088/8087 benchmark and stress tests
├── SERIALDIAG88/   COM port and transfer diagnostics
├── PRIME88/        Prime-number calculators and displays
├── VIDRAM88/       Direct B800h text-mode video RAM demos
└── FPUDEMO88/      8087 detection and floating-point examples
```

Keep each project self-contained with:

```text
PROJECTNAME.ASM
BUILD.BAT
RUNME.TXT
```

Use the same old TASM/TLINK command pattern unless a specific project says otherwise:

```bat
TASM PROJECTNAME
TLINK PROJECTNAME
PROJECTNAME
```

That plain `TLINK PROJECTNAME` step creates `PROJECTNAME.EXE` by default. Do not use `TLINK /T` unless a future project is intentionally meant to be a `.COM` program.
