@echo off
echo ================================================================
echo  ASTROM88 REV1 BUILD
echo ================================================================
echo.
echo Building ASTROM88.EXE, auto 8087/FPU detect version...
TASM ASTROM88
if errorlevel 1 goto fail
TLINK ASTROM88
if errorlevel 1 goto fail

echo.
echo Building ASTRO88I.EXE, integer-only safe version...
TASM ASTRO88I
if errorlevel 1 goto fail
TLINK ASTRO88I
if errorlevel 1 goto fail

echo.
echo Build complete.
echo Run ASTROM88.EXE if you have/want 8087 detection.
echo Run ASTRO88I.EXE for integer-only safe mode.
goto done

:fail
echo.
echo Build failed. Check the TASM/TLINK error above.

:done
