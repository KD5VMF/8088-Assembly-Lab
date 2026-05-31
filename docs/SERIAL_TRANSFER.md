# Serial transfer notes: Tera Term + MS-DOS Kermit

This is the workflow used for moving clean `.ASM`, `.BAT`, `.COM`, and support files to a real DOS/8088 machine over serial.

## Recommended terminal-side tools

- Tera Term official project page: https://teratermproject.github.io/index-en.html
- Tera Term GitHub organization: https://github.com/TeraTermProject
- Tera Term source repository: https://github.com/TeraTermProject/teraterm
- MS-DOS Kermit page: https://www.columbia.edu/kermit/mskermit.html
- The Kermit Project page: https://www.columbia.edu/kermit/
- Current Kermit versions page: https://www.kermitproject.org/current.html

## Recommended DOS-side tool

Use **MS-DOS Kermit** on the vintage PC. For a real 8088/XT-class system, Kermit is usually safer than plain pasted text because it checks packets and can survive slower serial links better.

Typical DOS-side receive flow:

```text
A:\> CD \8088LAB
A:\8088LAB> KERMIT
MS-Kermit> SET PORT COM1
MS-Kermit> SET SPEED 9600
MS-Kermit> SET FILE TYPE BINARY
MS-Kermit> RECEIVE
```

Then send the file from the modern PC using Tera Term or another terminal that supports Kermit transfer.

## Suggested serial settings

Start conservative, then speed up later.

```text
Baud:       9600 first, then 19200 or 38400 if reliable
Data bits:  8
Parity:     None
Stop bits:  1
Flow:       None first; RTS/CTS if both sides support it
```

## Clean text-file transfer rules

Assembly files are sensitive to damaged characters, pasted wrapping, and hidden encoding issues. For `.ASM` source files:

1. Keep files as plain ASCII text when possible.
2. Use CR/LF line endings for DOS tools.
3. Avoid smart quotes and Unicode symbols.
4. Do not paste long source files directly into DOS unless you must.
5. Prefer Kermit packet transfer for source and binary files.

## Auto receive idea

On the DOS machine, keep a small batch file such as `RX.BAT`:

```bat
@ECHO OFF
CD \8088LAB
KERMIT -C "SET PORT COM1, SET SPEED 9600, SET FILE TYPE BINARY, RECEIVE, EXIT"
```

If your MS-DOS Kermit version does not accept the one-line `-C` command syntax, use normal interactive commands instead:

```text
KERMIT
SET PORT COM1
SET SPEED 9600
SET FILE TYPE BINARY
RECEIVE
```

## Good transfer pattern for this repository

1. Build or edit files on the modern PC.
2. Send `.ASM`, `.BAT`, and `.TXT` with Kermit.
3. Build on the DOS machine using `TASM` and `TLINK`.
4. Send `.COM` directly only when you trust the serial link and the target filesystem.
5. Keep the CF card safe by avoiding programs that write repeatedly while running.

GALMATH16 itself does not write to disk while running.
