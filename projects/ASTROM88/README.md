# ASTROM88 REV1 - 8088 / 8087 Astrophysics Data Simulator

`ASTROM88` is a real-mode DOS text-only astrophysics math monitor for XT-class and later PCs.
It keeps the same green data-screen idea as the Galaxy16 project, but changes the math into a more scientifically grounded orbital mechanics simulator.

It does **not** draw graphics. It shows live math only.

## Files

| File | Purpose |
|---|---|
| `ASTROM88.ASM` | Main version. Detects 8087 and starts in FPU mode when available. |
| `ASTRO88I.ASM` | Integer-only safety version. Does not probe or use the 8087. Best for 286/386 machines with no x87 coprocessor. |
| `BUILD.BAT` | Builds both versions using TASM and TLINK. |

## Build

You said your normal workflow is simply:

```dos
TASM PROGRAMNAME
TLINK PROGRAMNAME
```

So for the main version:

```dos
TASM ASTROM88
TLINK ASTROM88
ASTROM88
```

For the integer-only safety version:

```dos
TASM ASTRO88I
TLINK ASTRO88I
ASTRO88I
```

Or build both:

```dos
BUILD
```

## Keys

| Key | Action |
|---|---|
| `F` | Force FPU mode, if an 8087/80287/80387 is detected. |
| `I` | Force integer mode. |
| `Q` or `ESC` | Quit. |

## What the screen shows

The program displays 8 visible rows sampled from 16 internal orbit bodies:

- Mercury
- Venus
- Earth
- Mars
- Jupiter
- Saturn
- Uranus
- Neptune
- plus Ceres, asteroids, comet/KBO-style rows internally

Columns:

| Column | Meaning |
|---|---|
| `M.E` | Body mass in Earth masses. Display only in REV1. |
| `R.AU` | Orbital radius in astronomical units. |
| `VEL` | Circular orbital velocity in km/s. |
| `ESC` | Escape speed in km/s. |
| `PERIOD` | Orbital period in Earth years. |
| `GIDX` | Simplified gravity index. |
| `STATE` | Bound/escape classification. |
| `TH` | Phase angle in degrees. |

## Science formulas used

REV1 uses simple circular-orbit astrophysics around a 1.000 solar-mass central body:

```text
V = 29.78 * SQRT(M / R)
ESC = 42.10 * SQRT(M / R)
PERIOD = 2980 * R / V
```

Where:

```text
M = central mass in solar masses
R = orbital radius in AU
V = circular orbital speed in km/s
ESC = escape speed in km/s
PERIOD = Earth years
```

Earth at 1.00 AU around 1.000 solar mass should show close to:

```text
VEL    = 29.78 km/s
ESC    = 42.10 km/s
PERIOD = 1.00 year
STATE  = BOUND
```

## 8088 versus 8087 use

In integer mode, the 8088 does all math using fixed-point integer operations and an integer square-root routine.

In FPU mode, the 8087 performs the main floating-point orbit calculations using x87 instructions such as:

```asm
FILD
FIMUL
FIDIV
FSQRT
FISTP
```

The 8088 still drives the program, screen writes, keyboard, loops, counters, and data movement.
The 8087 is the math coprocessor, not a replacement CPU.

## Compatibility notes

`ASTROM88.ASM` uses a simple 8087 probe like the Galaxy16 code style. That is good for XT/8088 + 8087 style systems.

On some real 286/386 systems without an x87 coprocessor, probing the FPU can fault. For those machines, use:

```dos
ASTRO88I
```

The integer-only version does not execute x87 probe instructions and should be safer on a plain 386 with DOS 6.22 and no 80387.

## Design goals

- Real-mode DOS
- TASM/TLINK build
- Green-on-black style
- No graphics
- No disk writes while running
- Direct B800h text updates
- Live math only
- 8088-safe integer fallback
- 8087 FPU math path in the main build

## What this is and is not

This is a real orbital-math data simulator / benchmark-style display.
It is not a full N-body astrophysics engine yet.

Good next upgrades:

- true two-body elliptical orbit data
- eccentricity/perihelion/aphelion columns
- binary star central mass mode
- adjustable body count
- optional comet mode
- optional full N-body calculation for a small number of bodies
