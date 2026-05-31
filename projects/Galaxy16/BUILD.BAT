@ECHO OFF
REM Build Galaxy16.EXE with Borland/Turbo Assembler and TLINK.
REM Requires TASM.EXE and TLINK.EXE to be in PATH or in this directory.
REM Normal old-tool workflow: TASM programname, then TLINK programname.

IF EXIST Galaxy16.OBJ DEL Galaxy16.OBJ
IF EXIST Galaxy16.MAP DEL Galaxy16.MAP
IF EXIST Galaxy16.EXE DEL Galaxy16.EXE

TASM Galaxy16
IF ERRORLEVEL 1 GOTO FAIL

TLINK Galaxy16
IF ERRORLEVEL 1 GOTO FAIL

ECHO.
ECHO Build complete: Galaxy16.EXE
GOTO END

:FAIL
ECHO.
ECHO Build failed. Check TASM/TLINK error messages above.

:END
