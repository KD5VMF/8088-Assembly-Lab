@ECHO OFF
REM Build Galaxy16.COM with Borland Turbo Assembler and TLINK.
REM Requires TASM.EXE and TLINK.EXE to be in PATH or in this directory.

IF EXIST Galaxy16.OBJ DEL Galaxy16.OBJ
IF EXIST Galaxy16.COM DEL Galaxy16.COM
IF EXIST Galaxy16.MAP DEL Galaxy16.MAP

TASM Galaxy16.asm
IF ERRORLEVEL 1 GOTO FAIL

TLINK /T Galaxy16.OBJ
IF ERRORLEVEL 1 GOTO FAIL

ECHO.
ECHO Build complete: Galaxy16.COM
GOTO END

:FAIL
ECHO.
ECHO Build failed. Check TASM/TLINK error messages above.

:END
