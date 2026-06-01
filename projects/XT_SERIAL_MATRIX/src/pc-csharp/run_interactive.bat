@echo off
setlocal
cd /d "%~dp0"
if not exist SerialMatrixCoproc.exe call build_framework.bat
if not exist SerialMatrixCoproc.exe goto fail
SerialMatrixCoproc.exe
goto done
:fail
echo SerialMatrixCoproc.exe was not built.
pause
:done
