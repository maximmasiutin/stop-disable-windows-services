@ECHO OFF
SETLOCAL EnableDelayedExpansion

REM Check for administrative privileges
NET SESSION >nul 2>&1
IF %ERRORLEVEL% NEQ 0 (
    ECHO ERROR: This script requires administrative privileges.
    ECHO Please run as Administrator.
    PAUSE
    EXIT /B 1
)

REM Initialize parameters with defaults
SET AUDIO_FLAG="$False"
SET PRINT_FLAG="$False"
SET PAUSE_FLAG="$False"
SET WORKSTATION_FLAG="$True"
SET BROKERS_FLAG="$True"

REM Parse command line arguments
:ParseArgs
IF "%~1"=="" GOTO :EndParse
IF /I "%~1"=="pause" SET PAUSE_FLAG="$True"
IF /I "%~1"=="-pause" SET PAUSE_FLAG="$True"
IF /I "%~1"=="audio" SET AUDIO_FLAG="$True"
IF /I "%~1"=="-audio" SET AUDIO_FLAG="$True"
IF /I "%~1"=="print" SET PRINT_FLAG="$True"
IF /I "%~1"=="-print" SET PRINT_FLAG="$True"
IF /I "%~1"=="noworkstation" SET WORKSTATION_FLAG="$False"
IF /I "%~1"=="-noworkstation" SET WORKSTATION_FLAG="$False"
IF /I "%~1"=="nobrokers" SET BROKERS_FLAG="$False"
IF /I "%~1"=="-nobrokers" SET BROKERS_FLAG="$False"
IF /I "%~1"=="help" GOTO :ShowHelp
IF /I "%~1"=="-help" GOTO :ShowHelp
IF /I "%~1"=="?" GOTO :ShowHelp
IF /I "%~1"=="-?" GOTO :ShowHelp
SHIFT
GOTO :ParseArgs

:EndParse

REM Verify PowerShell script exists
IF NOT EXIST "%~dp0stop-services.ps1" (
    ECHO ERROR: PowerShell script 'stop-services.ps1' not found in script directory.
    ECHO Expected location: %~dp0stop-services.ps1
    PAUSE
    EXIT /B 2
)

REM Find PowerShell executable (prefer PowerShell Core)
SET POWERSHELLEXECUTABLE=""
FOR %%X IN (pwsh.exe) DO (
    SET FOUND=%%~$PATH:X
    IF DEFINED FOUND (
        SET POWERSHELLEXECUTABLE="!FOUND!"
        GOTO :PSFound
    )
)

REM Fall back to Windows PowerShell
FOR %%X IN (powershell.exe) DO (
    SET FOUND=%%~$PATH:X
    IF DEFINED FOUND (
        SET POWERSHELLEXECUTABLE="!FOUND!"
        GOTO :PSFound
    )
)

:PSFound
IF %POWERSHELLEXECUTABLE%=="" (
    ECHO ERROR: PowerShell not found in system PATH.
    ECHO Please ensure PowerShell is installed and accessible.
    PAUSE
    EXIT /B 3
)

ECHO Using PowerShell executable: %POWERSHELLEXECUTABLE%
ECHO.
ECHO Starting service management with parameters:
ECHO   Audio services: %AUDIO_FLAG%
ECHO   Print services: %PRINT_FLAG%
ECHO   Workstation services: %WORKSTATION_FLAG%
ECHO   Broker services: %BROKERS_FLAG%
ECHO   Pause on completion: %PAUSE_FLAG%
ECHO.

REM Execute PowerShell script with error handling
%POWERSHELLEXECUTABLE% -ExecutionPolicy Bypass -NoProfile -Command "& '%~dp0stop-services.ps1' -audio %AUDIO_FLAG% -print %PRINT_FLAG% -workstation %WORKSTATION_FLAG% -brokers %BROKERS_FLAG% -pause %PAUSE_FLAG%"

IF %ERRORLEVEL% NEQ 0 (
    ECHO.
    ECHO ERROR: PowerShell script execution failed with error code %ERRORLEVEL%
    ECHO This may indicate insufficient permissions or script execution policy restrictions.
    ECHO Try running: Set-ExecutionPolicy RemoteSigned -Scope CurrentUser
    PAUSE
    EXIT /B %ERRORLEVEL%
)

ECHO.
ECHO Script completed successfully.
GOTO :EOF

:ShowHelp
ECHO Stop and Disable Windows Services - CMD Wrapper
ECHO.
ECHO Usage: %~nx0 [options]
ECHO.
ECHO Options:
ECHO   pause         - Pause before script exits
ECHO   audio         - Enable audio services (default: disabled)
ECHO   print         - Enable print services (default: disabled)
ECHO   noworkstation - Disable workstation services (default: enabled)
ECHO   nobrokers     - Disable broker services (default: enabled)
ECHO   help, ?       - Show this help message
ECHO.
ECHO Examples:
ECHO   %~nx0 pause
ECHO   %~nx0 audio print pause
ECHO   %~nx0 noworkstation nobrokers
ECHO.
ECHO This script requires Administrator privileges to modify Windows services.
PAUSE
EXIT /B 0

:EOF
