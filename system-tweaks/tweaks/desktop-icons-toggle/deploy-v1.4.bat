@echo off
rem 双击运行 -> 自动请求管理员权限 -> 执行 deploy-v1.4.ps1
net session >nul 2>&1
if %errorlevel% neq 0 (
    powershell -NoProfile -Command "Start-Process -FilePath '%~f0' -Verb RunAs"
    exit /b
)
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0deploy-v1.4.ps1" %*
echo.
pause
