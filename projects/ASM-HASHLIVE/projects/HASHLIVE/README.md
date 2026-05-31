# HASHLIVE

`HASHLIVE.ASM` is a live 8088/8086 DOS hash benchmark demo for the 8088 Assembly Lab repository.

It runs a custom 32-bit rolling `HASH32` mixer over a 256-byte internal data block and displays live benchmark statistics in a green-on-black text interface.

This is not MD5, SHA-1, SHA-256, or a cryptographic hash. It is a CPU-workload hash-style benchmark designed for vintage DOS systems, XT-class machines, emulators, and real 8088/8086-compatible hardware.

## Features

- 8088/8086-safe real-mode assembly
- Builds with classic Borland/Turbo Assembler tools
- Direct text output to `B800h`
- Green-on-black retro display
- No disk writes while running
- Live hashes per second
- Live bytes per second
- Total hashes
- Total bytes processed
- Elapsed seconds
- Continuously changing 32-bit hash value
- Live activity bar
- Keyboard reset and quit controls

## Build

From this folder:

```bat
tasm HASHLIVE
tlink HASHLIVE
```

The commands intentionally omit file extensions because the expected old DOS workflow is:

```bat
tasm programname
tlink programname
```

That produces:

```text
HASHLIVE.EXE
```

## Run

```bat
HASHLIVE
```

## Controls

| Key | Action |
|---|---|
| `R` | Reset benchmark counters |
| `Q` | Quit |
| `ESC` | Quit |

## Display fields

| Field | Meaning |
|---|---|
| `HASHES / SECOND` | Number of 256-byte hash blocks completed during the last timer period |
| `BYTES / SECOND` | Hashes per second multiplied by 256 bytes |
| `TOTAL HASHES` | Total 256-byte hash operations since start or reset |
| `TOTAL BYTES` | Total bytes processed since start or reset |
| `LIVE HASH32` | Current changing 32-bit rolling hash state |
| `ELAPSED SECONDS` | Approximate elapsed seconds since start or reset |

## Technical notes

The benchmark uses BIOS timer interrupt `INT 1Ah` to update the display about once per second. The hash work itself is done in a tight loop using 8088-safe integer operations: loads, adds, XORs, shifts, rotates-through-carry, and 16-bit counter updates.

The screen is updated through direct writes to VGA/color text memory at `B800h`, avoiding DOS printing overhead during the live display.

## Source file

```text
HASHLIVE.ASM
```
