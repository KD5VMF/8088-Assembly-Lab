@echo off
echo Building XTMAT1 with TASM/TLINK...
TASM XTMAT1
if errorlevel 1 goto fail
TLINK XTMAT1
if errorlevel 1 goto fail
echo.
echo Build complete: XTMAT1.EXE
goto done
:fail
echo.
echo BUILD FAILED.
:done
