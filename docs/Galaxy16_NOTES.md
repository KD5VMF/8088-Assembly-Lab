# Galaxy16 notes

Galaxy16 is a live text-mode galaxy-ring math display for DOS on 8088-class machines.

## Design goals

- 8088-compatible real-mode assembly.
- Builds with the old TASM/TLINK workflow.
- Normal build output is `Galaxy16.EXE`.
- Optional 8087 floating-point math if detected.
- Integer fallback mode for 8088-only systems.
- Monochrome green-on-black look.
- Direct B800h video RAM updates to reduce flicker.
- No disk writes while running.
- No growing display fields that expand during long runs.
- Fixed-width status fields for long-run stability.

## Build

From the `projects/Galaxy16/` folder:

```bat
TASM Galaxy16
TLINK Galaxy16
Galaxy16
```

No file extensions are needed on the TASM/TLINK command line.

`TASM Galaxy16` reads `Galaxy16.asm` and creates `Galaxy16.obj`.

`TLINK Galaxy16` reads `Galaxy16.obj` and creates `Galaxy16.exe`.

Do **not** use `TLINK /T` for the normal repo build. `/T` is for tiny `.COM` output, while this repo is documenting the plain `.EXE` build workflow.

## Runtime keys

```text
F      Force 8087 FPU mode
I      Force 8088 integer mode
Q/ESC  Quit
```

## Display fields

```text
8087:YES    8087 detected
ENG:FPU     Current math engine: FPU or INT
LAST:F      Last accepted key
ACT:READY   Current action/status
FREE:639    Free conventional memory estimate in KB
RINGS:128   Internal ring workload chosen from free RAM
HID:006     Current hidden/background ring index
RATE:528 OPS  Estimated ring-calculation rate per second. Unit changes dynamically: OPS, KOPS, or MOPS. The spinner/art marker sits close to the unit text.
```

## Table fields

```text
RG      Ring number
R.kpc   Simulated radius in kiloparsecs
BAR     Simplified baryonic mass component
DRK     Simplified dark-matter component
GAS     Simplified gas mass component
M/R     Mass/radius ratio monitor
ROOT    Square-root monitor
VCIR    Circular velocity estimate
VESC    Escape velocity estimate
PERIOD  Orbital period estimate
ENERGY  Internal energy-style calculation
TH      Wrapped phase/theta angle
```

## Math engine

At startup, Galaxy16 checks for an 8087. If found, it starts in FPU mode. If not found, it starts in integer mode.

Press `F` to force FPU mode. Press `I` to force integer mode.

The simulation uses internal time and hidden ring calculations in the background, but the display avoids unbounded counters so it can run for long periods without layout creep.

The `RATE:` field is calculated from completed ring-calculation steps during one BIOS timer interval. The BIOS timer is approximately 18.2 ticks per second, so the program scales the internal count into an estimated per-second rate. Slow systems display `OPS`; faster systems display `KOPS`; very fast systems or emulators display `MOPS`.
