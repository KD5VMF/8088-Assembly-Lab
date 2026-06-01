# Build and Run

## 1. Hardware setup

Connect the 8088/8086 DOS machine to the Windows PC through a real serial/null-modem connection.

Minimum wiring:

```text
8088 TX  -> PC RX
8088 RX  <- PC TX
GND      -- GND
```

Start with:

```text
9600 baud
8 data bits
No parity
1 stop bit
No flow control
```

## 2. Build the 8088 DOS program

Copy this folder to the DOS machine:

```text
src/8088-dos-asm/
```

Build with TASM/TLINK:

```bat
TASM XTMAT1
TLINK XTMAT1
XTMAT1
```

or run:

```bat
BUILD_XT.BAT
```

## 3. Build the Windows C# host

Open a Windows Command Prompt in:

```text
src\pc-csharp
```

Preferred first build:

```bat
build_framework.bat
```

Then run:

```bat
run_COM3_9600.bat
```

Change COM3 to your adapter's real Windows COM port if needed.

## 4. Startup order

Recommended order:

1. Start the Windows C# host first.
2. Start the DOS/8088 program second.
3. Pick matching COM settings on both ends.
4. Watch the PC process matrix jobs while the XT displays returned results.

## 5. If nothing happens

Check:

- COM port numbers are correct on both machines.
- Baud rate matches.
- Cable is null-modem/crossed, not straight-through unless your adapter already crosses TX/RX.
- No other terminal program has the COM port open.
- Hardware flow control is disabled.
