@echo off
setlocal
cd /d "%~dp0"
echo Building SerialMatrixCoproc using MSBuild and .NET Framework project...
where msbuild >nul 2>nul
if errorlevel 1 goto no_msbuild
msbuild SerialMatrixCoproc.Framework.csproj /p:Configuration=Release /p:Platform=AnyCPU
if errorlevel 1 goto fail
copy /Y "bin\Release\SerialMatrixCoproc.exe" . >nul
if not exist "SerialMatrixCoproc.exe" goto fail
echo.
echo Build complete: %CD%\SerialMatrixCoproc.exe
exit /b 0
:no_msbuild
echo ERROR: MSBuild was not found in PATH.
echo Try build_framework.bat or build_dotnet.bat.
exit /b 1
:fail
echo BUILD FAILED.
pause
exit /b 1
