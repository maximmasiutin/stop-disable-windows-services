@ECHO OFF
REM Capture this script's own directory before SETLOCAL/CALL can affect %~dp0
SET "SCRIPT_DIR=%~dp0"
SETLOCAL EnableDelayedExpansion

REM Wrapper defaults are intentionally conservative:
REM - audio/print disabled unless explicitly enabled by arguments
REM - workstation/brokers/startsearch enabled by default

REM Check for administrative privileges (registry check, no service dependency)
REG QUERY "HKU\S-1-5-19" >nul 2>&1
IF %ERRORLEVEL% NEQ 0 (
    ECHO ERROR: This script requires administrative privileges.
    ECHO Please run as Administrator.
    PAUSE
    EXIT /B 1
)

REM Initialize parameters with defaults
REM Note: these defaults differ from stop-services.ps1 defaults for audio/print.
SET AUDIO_FLAG=-audio:$false
SET PRINT_FLAG=-print:$false
SET PAUSE_FLAG=-pause:$false
SET WORKSTATION_FLAG=-workstation:$true
SET BROKERS_FLAG=-brokers:$true
SET STARTSEARCH_FLAG=-startsearch:$true
SET NOBOUNCE_FLAG=
SET WHATIF_FLAG=
SET FORCE_FLAG=

REM Parse command line arguments
:ParseArgs
IF "%~1"=="" GOTO :EndParse
IF /I "%~1"=="pause" SET PAUSE_FLAG=-pause:$true
IF /I "%~1"=="-pause" SET PAUSE_FLAG=-pause:$true
IF /I "%~1"=="audio" SET AUDIO_FLAG=-audio:$true
IF /I "%~1"=="-audio" SET AUDIO_FLAG=-audio:$true
IF /I "%~1"=="print" SET PRINT_FLAG=-print:$true
IF /I "%~1"=="-print" SET PRINT_FLAG=-print:$true
IF /I "%~1"=="noworkstation" SET WORKSTATION_FLAG=-workstation:$false
IF /I "%~1"=="-noworkstation" SET WORKSTATION_FLAG=-workstation:$false
IF /I "%~1"=="nobrokers" SET BROKERS_FLAG=-brokers:$false
IF /I "%~1"=="-nobrokers" SET BROKERS_FLAG=-brokers:$false
IF /I "%~1"=="startsearch" SET STARTSEARCH_FLAG=-startsearch:$true
IF /I "%~1"=="-startsearch" SET STARTSEARCH_FLAG=-startsearch:$true
IF /I "%~1"=="nostartsearch" SET STARTSEARCH_FLAG=-startsearch:$false
IF /I "%~1"=="-nostartsearch" SET STARTSEARCH_FLAG=-startsearch:$false
IF /I "%~1"=="nobounce" SET NOBOUNCE_FLAG=-NoBounce
IF /I "%~1"=="-nobounce" SET NOBOUNCE_FLAG=-NoBounce
IF /I "%~1"=="whatif" SET WHATIF_FLAG=-WhatIf
IF /I "%~1"=="-whatif" SET WHATIF_FLAG=-WhatIf
IF /I "%~1"=="force" SET FORCE_FLAG=-Force
IF /I "%~1"=="-force" SET FORCE_FLAG=-Force
IF /I "%~1"=="help" GOTO :ShowHelp
IF /I "%~1"=="-help" GOTO :ShowHelp
IF /I "%~1"=="?" GOTO :ShowHelp
IF /I "%~1"=="-?" GOTO :ShowHelp
SHIFT
GOTO :ParseArgs

:EndParse

REM Verify PowerShell script exists
IF NOT EXIST "%SCRIPT_DIR%stop-services.ps1" (
    ECHO ERROR: PowerShell script 'stop-services.ps1' not found in script directory.
    ECHO Expected location: %SCRIPT_DIR%stop-services.ps1
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
ECHO   Audio services: %AUDIO_FLAG:-audio:=%
ECHO   Print services: %PRINT_FLAG:-print:=%
ECHO   Workstation services: %WORKSTATION_FLAG:-workstation:=%
ECHO   Broker services: %BROKERS_FLAG:-brokers:=%
ECHO   Start/Search services: %STARTSEARCH_FLAG:-startsearch:=%
IF NOT "%NOBOUNCE_FLAG%"=="" ECHO   NoBounce mode: enabled ^(skips most immediate stop/start transitions; disabled services are still stopped^)
ECHO   Pause on completion: %PAUSE_FLAG:-pause:=%
IF NOT "%WHATIF_FLAG%"=="" ECHO   Mode: TEST MODE (WhatIf)
IF NOT "%WHATIF_FLAG%"=="" ECHO   NOTE: WhatIf does not apply service changes or post-run Start/Search repairs.
IF NOT "%FORCE_FLAG%"=="" ECHO   Confirmation prompt: skipped ^(Force^)
ECHO.

REM Execute PowerShell script with error handling
%POWERSHELLEXECUTABLE% -ExecutionPolicy Bypass -NoProfile -File "%SCRIPT_DIR%stop-services.ps1" %AUDIO_FLAG% %PRINT_FLAG% %WORKSTATION_FLAG% %BROKERS_FLAG% %STARTSEARCH_FLAG% %NOBOUNCE_FLAG% %PAUSE_FLAG% %WHATIF_FLAG% %FORCE_FLAG%

IF %ERRORLEVEL% NEQ 0 (
    SET SCRIPT_EXIT_CODE=%ERRORLEVEL%

    IF "!SCRIPT_EXIT_CODE!"=="2" (
        ECHO.
        ECHO WARNING: Script completed with partial failures ^(some services could not be changed^).
        ECHO This is common when specific services are missing, protected, or blocked by dependencies.
        ECHO Review PowerShell output or use -Verbose / -LogFile for details.
        ECHO.
        ECHO Script completed with warnings.
        GOTO :EOF
    )

    ECHO.
    ECHO ERROR: PowerShell script execution failed with error code !SCRIPT_EXIT_CODE!
    ECHO This may indicate insufficient permissions or script execution policy restrictions.
    ECHO Try running: Set-ExecutionPolicy RemoteSigned -Scope CurrentUser
    PAUSE
    EXIT /B !SCRIPT_EXIT_CODE!
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
ECHO   audio         - Enable audio services ^(default in CMD wrapper: audio disabled^)
ECHO   print         - Enable print services ^(default in CMD wrapper: print disabled^)
ECHO   noworkstation - Disable workstation services (default: workstation enabled)
ECHO   nobrokers     - Disable broker services (default: brokers enabled)
ECHO   nostartsearch - Disable Start/Search input services (default: start/search input devices enabled)
ECHO   nobounce      - Skip most immediate stop/start transitions; disabled services are still stopped
ECHO   whatif        - Show what would happen without making changes
ECHO   force         - Skip interactive security confirmation prompt
ECHO   help, ?       - Show this help message
ECHO.
ECHO Examples:
ECHO   %~nx0 pause
ECHO   %~nx0 audio print pause
ECHO   %~nx0 noworkstation nobrokers
ECHO   %~nx0 noworkstation audio nobounce
ECHO   %~nx0 nostartsearch
ECHO   %~nx0 -nostartsearch
ECHO   %~nx0 whatif
ECHO   %~nx0 force
ECHO   %~nx0 noworkstation audio nobounce force
ECHO.
ECHO Recovery note: if Start menu typing does not work after service changes,
ECHO run without 'nostartsearch' and restart explorer.exe or sign out/sign in.
ECHO.
ECHO This script requires Administrator privileges to modify Windows services.
PAUSE
EXIT /B 0

:EOF
