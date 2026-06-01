@echo off
setlocal
cd /d "%~dp0"
if not exist SerialMatrixCoproc.exe call build_framework.bat
if not exist SerialMatrixCoproc.exe goto fail
SerialMatrixCoproc.exe COM1 9600
goto done
:fail
echo SerialMatrixCoproc.exe was not built.
pause
:done
