DOS side - DOSTIME REV8
=======================

Build:
  TASM DOSTIME
  TLINK DOSTIME

Or:
  BUILD

Run:
  DOSTIME

First run asks COM port and baud, then saves DOSTIME.CFG.
Press C while running to change setup and save again.
Press Q to quit.

REV8 uses BIOS INT 14h serial, 8N1.
Supported baud choices: 1200, 2400, 4800, 9600.
Start with 9600.

REV8 date/time behavior:
  - accepts TYYYYMMDDHHMMSS
  - accepts TYYYYMMDDHHMMSSD where D means daylight-saving active
  - accepts TYYYYMMDDHHMMSSS where S means standard time
  - sets DOS date and DOS time with INT 21h
  - also attempts AT BIOS RTC/CMOS date/time set with INT 1Ah
  - verifies the DOS date before sending AOK

If the status line says DATE SET/VERIFY FAILED, DOS rejected or did not retain the incoming date.


REV8 DATE NOTE:
If the time updates but DATE still looks wrong, run DOSTIME again and watch the STATUS field. REV8 only sends AOK after DOS accepts and verifies the incoming date. REV8 also writes the AT CMOS RTC directly for 286/386-style machines.


REV8 year parser fix: corrected the DOS-side 4-digit year parser so packets like T20260531150705 set year 2026, not 2000. Month/day had been parsing correctly; the bug was only in the 4-digit year combine step.

REV8 YEAR NOTE
--------------
REV8 splits the incoming four-digit year into century plus two-digit RTC year. For 2026, DOS receives 2026, CMOS year register 09h receives 26, and CMOS century register 32h receives 20 when supported.
