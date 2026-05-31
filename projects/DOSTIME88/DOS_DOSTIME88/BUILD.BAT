@echo off
echo Building DOSTIME.EXE with TASM/TLINK...
TASM DOSTIME
if errorlevel 1 goto bad
TLINK DOSTIME
if errorlevel 1 goto bad
echo.
echo Done. Run DOSTIME
if exist DOSTIME.OBJ del DOSTIME.OBJ
goto end
:bad
echo.
echo Build failed.
:end
