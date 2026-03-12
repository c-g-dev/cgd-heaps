@echo off
setlocal EnableExtensions

for %%I in ("%~dp0..") do set "LIB_PATH=%%~fI"

if not exist "%LIB_PATH%\Run.hx" (
  echo Could not locate Run.hx at %LIB_PATH%. 1>&2
  exit /b 1
)

set "CGDHEAPS_RUN=1"
haxe --cwd "%LIB_PATH%" --run Run.hx %* "%CD%"
exit /b %ERRORLEVEL%
