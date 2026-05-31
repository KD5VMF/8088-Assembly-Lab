# DOS TimeSync88 REV8

Serial clock-sync project for an old DOS machine and a Windows PC.

REV8 fixes the date/DST side of the project:

- Windows sends local Windows time, which is already daylight-saving-time aware.
- Windows adds a trailing DST flag to correction packets: `D` for daylight-saving active, `S` for standard time.
- DOS accepts `TYYYYMMDDHHMMSS`, `TYYYYMMDDHHMMSSD`, or `TYYYYMMDDHHMMSSS`.
- DOS sets DOS date and DOS time through `INT 21h`.
- DOS also attempts to set the AT-class BIOS/CMOS RTC through `INT 1Ah` using packed BCD.
- DOS verifies that the DOS date actually changed before sending `AOK`.
- Windows still sends correction packets 3 times and waits for `AOK` confirmation.

## DOS build

```dos
TASM DOSTIME
TLINK DOSTIME
DOSTIME
```

Or:

```dos
BUILD
```

## Windows build

```bat
build.bat
```

## Windows run examples

```bat
list_ports.bat
run_COM13_9600.bat
run_SETUP.bat
```

Manual:

```bat
TimeSyncHost.exe --port COM13 --baud 9600 --threshold 2
```

## Normal expected behavior

DOS sends once per second:

```text
DYYYYMMDDHHMMSS
```

Windows sends correction only when daily sync is due or DOS is off by the threshold:

```text
TYYYYMMDDHHMMSSD
```

or:

```text
TYYYYMMDDHHMMSSS
```

The final `D` means Windows local time is currently daylight-saving time. The final `S` means standard time.

DOS replies after successful date/time set and verification:

```text
AOK
```

## Daylight saving behavior

DOS itself does not calculate daylight-saving rules. The Windows host does that automatically by using `DateTime.Now` from Windows local time. So make sure the Windows PC time zone is correct, for example Central Time for your area. When Windows changes between CST and CDT, the DOS machine receives the already-correct local time.

If Windows shows `DST now : YES`, it will send a packet ending in `D`. If it shows `DST now : NO`, it will send a packet ending in `S`.

## If date still does not change

Watch the DOS status line:

- `TIME SET OK` means DOS accepted and verified the date.
- `DATE SET/VERIFY FAILED` means DOS did not accept or did not retain the incoming date.

If date verification fails on a very unusual DOS/BIOS setup, test manually with the DOS `DATE` command to confirm the DOS environment allows changing the date.


REV8 year parser fix: corrected the DOS-side 4-digit year parser so packets like T20260531150705 set year 2026, not 2000. Month/day had been parsing correctly; the bug was only in the 4-digit year combine step.


## REV8 two-digit RTC year fix

REV8 parses the incoming `TYYYYMMDDHHMMSS` packet as separate `CC` + `YY` values. DOS is set with the full four-digit year, while the AT/CMOS RTC is written with the two-digit year register plus the century register when available. This fixes machines that set month/day correctly but keep the wrong year.
