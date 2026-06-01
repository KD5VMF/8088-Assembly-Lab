@echo off
setlocal
cd /d "%~dp0"
set CSC=%WINDIR%\Microsoft.NET\Framework\v4.0.30319\csc.exe
if not exist "%CSC%" set CSC=%WINDIR%\Microsoft.NET\Framework64\v4.0.30319\csc.exe
if not exist "%CSC%" goto no_csc
echo Building SerialMatrixCoproc.exe using .NET Framework csc...
"%CSC%" /nologo /optimize+ /target:exe /out:SerialMatrixCoproc.exe SerialMatrixCoproc.cs
if errorlevel 1 goto fail
echo.
echo Build complete: %CD%\SerialMatrixCoproc.exe
exit /b 0
:no_csc
echo ERROR: Could not find .NET Framework csc.exe.
echo Try build_dotnet.bat if .NET SDK is installed.
exit /b 1
:fail
echo BUILD FAILED.
pause
exit /b 1
