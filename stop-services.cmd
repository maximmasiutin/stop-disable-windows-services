@echo off
rem You should run this cript from the current directory

for %%X in (pwsh.exe) do (set FOUND=%%~$PATH:X)

if defined FOUND (
  set POWERSHELLEXECUTABLE="%FOUND%"
) else (
  set POWERSHELLEXECUTABLE="powershell.exe"
)

%POWERSHELLEXECUTABLE% -file "%~dp0%stop-services.ps1"
