@echo off
setlocal
cd /d "%~dp0"
if not exist SerialMatrixCoproc.exe call build_framework.bat
if exist SerialMatrixCoproc.exe SerialMatrixCoproc.exe --selftest
pause
