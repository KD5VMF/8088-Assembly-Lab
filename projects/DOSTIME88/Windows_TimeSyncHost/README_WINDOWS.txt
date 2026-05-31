Windows side - TimeSyncHost REV8
================================

Build:
  build.bat

First setup / change setup:
  run_SETUP.bat

List Windows serial ports:
  list_ports.bat

Run examples:
  run_COM1_9600.bat
  run_COM13_9600.bat

Manual run:
  dotnet run -c Release -- --port COM13 --baud 9600 --threshold 2

Important COM fix:
  If you type 13 at the COM prompt, REV8 automatically converts it to COM13.
  Old bad configs containing Port=13 are also repaired to Port=COM13.

Important DST behavior:
  REV8 uses Windows local time with automatic daylight-saving handling.
  It prints the Windows time zone and whether DST is active now.

Behavior:
  Reads DOS packets:     DYYYYMMDDHHMMSS
  Sends correction:      TYYYYMMDDHHMMSSD or TYYYYMMDDHHMMSSS

The final D means daylight-saving time is active on Windows.
The final S means standard time is active on Windows.

It sends only:
  - once per local calendar day, or
  - if DOS differs from Windows by threshold seconds or more.

Default threshold is 2 seconds.

Saved config:
  TimeSyncHost.cfg

Normal later run:
  TimeSyncHost.exe

Use --setup only when you want to change saved settings.

This project uses System.IO.Ports through NuGet for .NET 8.


REV8 year parser fix: corrected the DOS-side 4-digit year parser so packets like T20260531150705 set year 2026, not 2000. Month/day had been parsing correctly; the bug was only in the 4-digit year combine step.
