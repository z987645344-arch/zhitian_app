@echo off
rem [说明] 仅启动Flutter Windows调试客户端，不启动Compose。
rem Compose用http://localhost；:8000仅用于本机非容器后端调试。
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
