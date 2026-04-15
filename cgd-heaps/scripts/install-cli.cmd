@echo off
setlocal EnableExtensions

for %%I in ("%~dp0..") do set "LIB_PATH=%%~fI"
if not exist "%LIB_PATH%\cgdheaps.hl" (
  echo Could not locate cgdheaps.hl at %LIB_PATH%.
  exit /b 1
)

if "%CGDHEAPS_BIN_DIR%"=="" (
  set "INSTALL_DIR=%USERPROFILE%\bin"
) else (
  set "INSTALL_DIR=%CGDHEAPS_BIN_DIR%"
)

if not exist "%INSTALL_DIR%" mkdir "%INSTALL_DIR%"
if not exist "%INSTALL_DIR%" (
  echo Could not create install directory: %INSTALL_DIR%
  exit /b 1
)

set "TARGET=%INSTALL_DIR%\cgdheaps.cmd"
> "%TARGET%" (
  echo @echo off
  echo setlocal EnableExtensions
  echo set "LIB_PATH=%LIB_PATH%"
  echo if not exist "%%LIB_PATH%%\cgdheaps.hl" ^(
  echo   echo Could not locate cgdheaps.hl at %%LIB_PATH%%.
  echo   exit /b 1
  echo ^)
  echo set "CGDHEAPS_CWD=%%CD%%"
  echo set "CGDHEAPS_LIB_ROOT=%%LIB_PATH%%"
  echo hl "%%LIB_PATH%%\cgdheaps.hl" %%*
  echo exit /b %%ERRORLEVEL%%
)

echo Installed cgdheaps launcher to %TARGET%

set "USER_PATH="
for /f "tokens=2,*" %%A in ('reg query HKCU\Environment /v Path 2^>nul ^| findstr /R /C:"\<Path\>"') do set "USER_PATH=%%B"

set "NEED_PATH=1"
if defined USER_PATH (
  echo ;%USER_PATH%; | find /I ";%INSTALL_DIR%;" >nul
  if not errorlevel 1 set "NEED_PATH=0"
)

if "%NEED_PATH%"=="1" (
  if defined USER_PATH (
    set "NEW_USER_PATH=%USER_PATH%;%INSTALL_DIR%"
  ) else (
    set "NEW_USER_PATH=%INSTALL_DIR%"
  )
  reg add HKCU\Environment /v Path /t REG_EXPAND_SZ /d "%NEW_USER_PATH%" /f >nul
  echo Added %INSTALL_DIR% to your user PATH.
) else (
  echo User PATH already includes %INSTALL_DIR%.
)

echo Open a new terminal to use cgdheaps.
