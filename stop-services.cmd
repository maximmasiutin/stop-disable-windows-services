@ECHO OFF

REM Check if 'pause' parameter is present
SET PAUSE_FLAG="$False"
FOR %%I IN (%*) DO (
    IF /I "%%I"=="pause" (
        SET PAUSE_FLAG="$True"
    )
)

REM Find PowerShell executable
FOR %%X IN (pwsh.exe) DO (
    SET FOUND=%%~$PATH:X
)
IF DEFINED FOUND (
    SET POWERSHELLEXECUTABLE="%FOUND%"
) ELSE (
    SET POWERSHELLEXECUTABLE="powershell.exe"
)

%POWERSHELLEXECUTABLE% -Command "%~dp0stop-services.ps1 -audio $False -print $False -pause %PAUSE_FLAG%"
