@echo off
setlocal
cd /d "%~dp0"
echo Building SerialMatrixCoproc with dotnet SDK...
echo This uses the NuGet System.IO.Ports package.
dotnet restore SerialMatrixCoproc.csproj
if errorlevel 1 goto fail
dotnet build SerialMatrixCoproc.csproj -c Release -p:Platform=AnyCPU
if errorlevel 1 goto fail
if exist "bin\Release\AnyCPU\SerialMatrixCoproc.exe" copy /Y "bin\Release\AnyCPU\SerialMatrixCoproc.exe" . >nul
if exist "bin\Release\net8.0\SerialMatrixCoproc.exe" copy /Y "bin\Release\net8.0\SerialMatrixCoproc.exe" . >nul
if not exist "SerialMatrixCoproc.exe" goto fail
echo.
echo Build complete: %CD%\SerialMatrixCoproc.exe
exit /b 0
:fail
echo.
echo BUILD FAILED.
echo If this PC has no internet for NuGet restore, try build_framework.bat instead.
pause
exit /b 1
