@echo off
setlocal EnableExtensions

for %%I in ("%~dp0..") do set "LIB_PATH=%%~fI"

if not exist "%LIB_PATH%\cgdheaps.hl" (
  echo Could not locate cgdheaps.hl at %LIB_PATH%. 1>&2
  exit /b 1
)

set "CGDHEAPS_CWD=%CD%"
set "CGDHEAPS_LIB_ROOT=%LIB_PATH%"
hl "%LIB_PATH%\cgdheaps.hl" %*
exit /b %ERRORLEVEL%
