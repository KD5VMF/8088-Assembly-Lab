@echo off
echo Building TimeSyncHost...
dotnet build -c Release
if errorlevel 1 goto bad
echo.
echo Done.
echo EXE: bin\Release\net8.0-windows\TimeSyncHost.exe
goto end
:bad
echo.
echo Build failed. Install .NET 8 SDK or restore the System.IO.Ports package.
:end
