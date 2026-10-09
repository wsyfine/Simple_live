@echo off
chcp 65001 >nul
setlocal enabledelayedexpansion

rem ===========================================================================
rem  Simple Live - Windows installer build script
rem  Usage:
rem     build_installer.bat               (build app + installer)
rem     build_installer.bat --skip-build  (only package existing build output)
rem ===========================================================================

cd /d "%~dp0"

rem ---- locate ISCC.exe ------------------------------------------------------
set "ISCC="
for %%P in (
  "%LOCALAPPDATA%\Programs\Inno Setup 6\ISCC.exe"
  "%ProgramFiles(x86)%\Inno Setup 6\ISCC.exe"
  "%ProgramFiles%\Inno Setup 6\ISCC.exe"
) do (
  if not defined ISCC if exist %%P set "ISCC=%%~P"
)

if not defined ISCC (
  for /f "tokens=2,*" %%A in ('reg query "HKLM\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\Inno Setup 6_is1" /v InstallLocation 2^>nul ^| find "InstallLocation"') do (
    if exist "%%B\ISCC.exe" set "ISCC=%%B\ISCC.exe"
  )
)

if not defined ISCC (
  echo [ERROR] ISCC.exe not found.
  echo         Install Inno Setup 6 first:  winget install JRSoftware.InnoSetup
  echo         Or edit this script and set ISCC manually.
  exit /b 1
)

echo [INFO] ISCC: !ISCC!

rem ---- step 1: build the Flutter release bundle -----------------------------
if /I "%~1"=="--skip-build" (
  echo [1/3] Skip flutter build ^(--skip-build^)
) else (
  echo [1/3] flutter build windows --release
  call flutter build windows --release
  if errorlevel 1 (
    echo [ERROR] flutter build failed.
    exit /b 1
  )
)

rem ---- step 2: app-local VC++ runtime ----------------------------------------
rem  Flutter Windows does not statically link the CRT, so the exe and 15 plugin
rem  dlls need MSVCP140 / VCRUNTIME140 / VCRUNTIME140_1 next to the exe.
rem  Copying them in is far smaller than bundling vc_redist.x64.exe (25 MB) and
rem  needs no admin rights. Must run AFTER flutter build, which refreshes Release.
echo [2/3] deploying VC++ runtime (app-local) ...
rem  Prefer PowerShell 7 (pwsh): it always reads UTF-8, while Windows PowerShell
rem  5.1 decodes .ps1 as ANSI/GBK unless the file carries a UTF-8 BOM.
set "PSH=powershell"
where pwsh >nul 2>&1 && set "PSH=pwsh"
%PSH% -NoProfile -ExecutionPolicy Bypass -File "%~dp0deploy_vc_runtime.ps1"
if errorlevel 1 (
  echo [ERROR] VC++ runtime deployment failed.
  exit /b 1
)

rem ---- step 3: compile the installer ----------------------------------------
echo [3/3] compiling installer ...
"!ISCC!" "%~dp0simple_live.iss"
if errorlevel 1 (
  echo [ERROR] ISCC failed.
  exit /b 1
)

echo.
echo [OK] Done. Output:
dir /b /o-d "%~dp0output\*.exe"
exit /b 0
