# GALMATH16 notes

GALMATH16 is a live text-mode galaxy-ring math display for DOS on 8088-class machines.

## Design goals

- 8088-compatible real-mode assembly.
- Optional 8087 floating-point math if detected.
- Integer fallback mode for 8088-only systems.
- Monochrome green-on-black look.
- Direct B800h video RAM updates to reduce flicker.
- No disk writes while running.
- No growing display fields that expand during long runs.
- Fixed-width status fields for long-run stability.

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
OPS:00030   Operations per visible frame interval, fixed width
```

## Table fields

```text
RG      Ring number
R.kpc   Radius in kiloparsecs
BAR     Bar/bulge mass bucket
DRK     Dark matter mass bucket
GAS     Gas mass bucket
M/R     Mass/radius ratio
ROOT    Square-root term used in velocity calculation
VCIR    Circular velocity
VESC    Escape velocity
PERIOD  Ring orbital period estimate
ENERGY  Internal energy/resonance calculation
TH      Angular phase/theta
```

## Formula line

```text
V=207.4*SQRT((BAR+DRK+GAS)/R)   VESC=1.41*V   P=6148*R/V
```

This is an educational/visual workload, not an astrophysics research-grade model. It is built to be fun, readable, and impressive on a vintage system while still doing real calculations continuously.
