# XT Serial Matrix Co-Processor

8088/8086 DOS serial matrix co-processor project. The XT generates matrix job data, sends it over RS-232, a Windows C# host performs large deterministic matrix-multiplication work, and the XT displays clean green-on-black VGA results.

This is designed as a standalone project for an 8088/8086 DOS machine plus a modern PC connected by serial/null-modem cable or USB serial adapter.

## Project summary

The 8088 side acts like a retro control/display computer:

- lets you select COM port and baud rate
- generates a fresh random job every cycle
- sends the matrix job request to the PC
- receives calculated results back from the PC
- displays range/status/speed/result fields on a stable text dashboard
- keeps running with new data sets until you quit

The PC side acts like the math co-processor:

- opens the selected COM port
- receives matrix job requests
- expands 8088-generated seeds into deterministic 4096 x 4096 matrix data streams
- performs real matrix-multiplication fingerprint/sample calculations
- sends compact fixed-width results back to the XT
- uses a no-scroll console dashboard showing WAITING, RECEIVING, PROCESSING, and TRANSMITTING

## Why seed-stream mode?

A full 4096 x 4096 matrix contains 16,777,216 values. Two full matrices contain 33,554,432 values. Sending every value at 9600 baud would take many hours before the PC could even begin the calculation.

This project keeps the 8088 genuinely in charge while staying usable: the 8088 generates and sends the random seeds and matrix size, and the PC expands those seeds into deterministic matrix streams. Each new job is a new random data set, while the modern PC does the heavy math.

## Folder layout

```text
XT_SERIAL_MATRIX_COPRO/
├── README.md
├── LICENSE
├── CHANGELOG.md
├── PROJECT_DESCRIPTION.txt
├── GITHUB_UPLOAD_STEPS.txt
├── DROP_IN_TO_8088_ASSEMBLY_LAB.txt
├── .gitignore
├── docs/
│   ├── BUILD_AND_RUN.md
│   ├── PROTOCOL.md
│   ├── SERIAL_WIRING.md
│   └── DESIGN_NOTES.md
├── src/
│   ├── 8088-dos-asm/
│   │   ├── XTMAT1.ASM
│   │   ├── XT8088MAT_REV1.ASM
│   │   ├── BUILD_XT.BAT
│   │   └── RUN_XT.BAT
│   └── pc-csharp/
│       ├── SerialMatrixCoproc.cs
│       ├── SerialMatrixCoproc.csproj
│       ├── SerialMatrixCoproc.Framework.csproj
│       ├── SerialMatrixCoproc.DotNet8.csproj
│       └── build/run helper BAT files
└── release-package/
    └── XT_SERIAL_MATRIX_COPRO_REV1.zip
```

## Build the 8088 DOS side

Use the DOS 8.3 filename on the retro machine:

```bat
cd src\8088-dos-asm
TASM XTMAT1
TLINK XTMAT1
XTMAT1
```

or:

```bat
BUILD_XT.BAT
RUN_XT.BAT
```

## Build the Windows C# host

From a Windows Command Prompt:

```bat
cd src\pc-csharp
build_framework.bat
run_COM3_9600.bat
```

Use the COM port Windows assigns to your USB serial adapter. Common examples are `COM3`, `COM4`, or `COM5`.

You can also run interactively:

```bat
run_interactive.bat
```

## Serial defaults

```text
Format: 8N1
Flow control: none
Suggested baud: 9600 first
Cable: null-modem/crossed TX-RX plus GND
```

On the XT, choose the physical port your serial card uses, usually COM1. On the Windows PC, choose the COM port shown by Device Manager for your USB serial adapter.

## Protocol example

XT sends:

```text
MAT,00001,04096,12345,54321*XX
```

PC replies:

```text
RSP,00001,04096,12345,54321,SUMMOD,DIAGMOD,C00,CMID,CLAST,MS*XX
```

The `*XX` checksum is an XOR checksum over the text before the `*`.

## Runtime keys

8088 side:

```text
S     settings / reinitialize serial
R     reset seeds/job counter
Q     quit
ESC   quit
```

PC side:

```text
Q     quit
ESC   quit
C     clear PC-side counters
```

## Notes

The project intentionally avoids disk writes while the 8088 program is running. The 8088 program uses direct text-mode video output and polled serial I/O, keeping the code understandable for real DOS/XT hardware.
