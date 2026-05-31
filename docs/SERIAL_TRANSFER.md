# Serial transfer notes: Tera Term + MS-DOS Kermit

This is the workflow used for moving clean `.ASM`, `.BAT`, `.COM`, and support files to a real DOS/8088 machine over serial.

## Recommended terminal-side tools

- Tera Term official project page: https://teratermproject.github.io/index-en.html
- Tera Term GitHub organization: https://github.com/TeraTermProject
- Tera Term source repository: https://github.com/TeraTermProject/teraterm
- MS-DOS Kermit page: https://www.columbia.edu/kermit/new/mskermit.html
- The Kermit Project current versions page: https://www.kermitproject.org/current.html
- FreeDOS official site: https://www.freedos.org/
- DOSBox Staging official site: https://www.dosbox-staging.org/

## Recommended DOS-side tool

Use **MS-DOS Kermit** on the vintage PC. For a real 8088/XT-class system, Kermit is usually safer than plain pasted text because it checks packets and can survive slower serial links better.

## Basic DOS-side receive flow

```text
C:\> MD \8088LAB
C:\> CD \8088LAB
C:\8088LAB> KERMIT
MS-Kermit> SET PORT COM1
MS-Kermit> SET SPEED 9600
MS-Kermit> SET FILE TYPE BINARY
MS-Kermit> RECEIVE
```

Then send the file from the modern PC using Tera Term or another terminal that supports Kermit transfer.

## Tera Term send flow

Typical manual flow from the modern PC:

```text
Tera Term menu:
File -> Transfer -> Kermit -> Send...
```

Select the file to send, for example:

```text
Galaxy16.asm
BUILD.BAT
RUNME.TXT
Galaxy16.COM
```

## Simple auto-receive idea on the DOS machine

You can create a small DOS batch file so the vintage machine is ready to receive without typing all Kermit setup commands every time.

Example `RX.BAT`:

```bat
@ECHO OFF
KERMIT TAKE RX.KSC
```

Example `RX.KSC`:

```text
SET PORT COM1
SET SPEED 9600
SET FILE TYPE BINARY
RECEIVE
EXIT
```

Then run:

```bat
RX
```

When Kermit is waiting, send the file from Tera Term using Kermit Send.

## Suggested serial settings

Start conservative, then speed up later.

```text
Baud:       9600 first, then 19200 or 38400 if reliable
Data bits:  8
Parity:     None
Stop bits:  1
Flow:       None first; RTS/CTS if both sides support it
```

For COM2 on many PC-compatible serial cards, the common default IRQ is IRQ3. COM1 commonly uses IRQ4.

## Keeping source files clean

The `.gitattributes` file in this repository keeps `.asm`, `.bat`, and text docs DOS-friendly with CRLF line endings.

Before sending files to a real DOS system:

- Avoid smart quotes and non-ASCII symbols in `.ASM` and `.BAT` files.
- Prefer plain ASCII comments.
- Keep DOS filenames short if the target machine does not support long filenames.
- Use Kermit binary mode for `.COM`, `.EXE`, `.OBJ`, `.ZIP`, and tool files.
- Use Kermit binary mode for `.ASM` too if you want exact bytes preserved.

## Recommended target folder on DOS

```text
C:\8088LAB\PROJECTS\GALAXY16
```

On classic DOS, filenames are case-insensitive, so `Galaxy16.asm` may appear as `GALAXY16.ASM`.
