@echo off
setlocal
cd /d "%~dp0"

echo Starting Zhitian Flutter client...
where flutter >nul 2>nul
if errorlevel 1 (
    echo Flutter was not found in PATH. Please install Flutter or add it to PATH.
    pause
    exit /b 1
)

flutter run -d windows
pause
