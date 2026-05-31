@echo off
rem Build HASHLIVE with classic TASM/TLINK.
rem Expected workflow: tasm programname, then tlink programname.

echo Building HASHLIVE...
tasm HASHLIVE
if errorlevel 1 goto bad

tlink HASHLIVE
if errorlevel 1 goto bad

echo.
echo Build complete: HASHLIVE.EXE
goto done

:bad
echo.
echo Build failed.

:done
