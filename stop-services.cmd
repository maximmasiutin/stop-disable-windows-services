@ECHO OFF
REM Capture this script's own directory before SETLOCAL/CALL can affect %~dp0
SET "SCRIPT_DIR=%~dp0"
SETLOCAL EnableDelayedExpansion

REM Wrapper defaults are intentionally conservative:
REM - audio/print enabled (true) unless explicitly disabled by arguments (matching .ps1)
REM - both LanmanServer and LanmanWorkstation default to Manual+stopped
REM - brokers/startsearch enabled by default


REM Check for administrative privileges (registry check, no service dependency)
REG QUERY "HKU\S-1-5-19" >nul 2>&1
IF %ERRORLEVEL% NEQ 0 (
    ECHO ERROR: This script requires administrative privileges.
    ECHO Please run as Administrator.
    PAUSE
    EXIT /B 1
)

REM Initialize parameters with defaults
REM Both server and workstation default to Manual+stopped (server:$false, workstation:$false)
SET AUDIO_FLAG=-audio:$true
SET PRINT_FLAG=-print:$true

SET PAUSE_FLAG=-pause:$false
SET SERVER_FLAG=-server:$false
SET WORKSTATION_FLAG=-workstation:$false
SET BROKERS_FLAG=-brokers:$true
SET STARTSEARCH_FLAG=-startsearch:$true
SET NOBOUNCE_FLAG=
SET NORESTARTEXPLORER_FLAG=
SET WHATIF_FLAG=
SET FORCE_FLAG=
SET DISABLESERVER_FLAG=
SET DISABLEWORKSTATION_FLAG=
SET MANUALSERVER=
SET MANUALWORKSTATION=
SET AUTOSERVER=
SET AUTOWORKSTATION=

REM Parse command line arguments
:ParseArgs
IF "%~1"=="" GOTO :EndParse
IF /I "%~1"=="pause" SET PAUSE_FLAG=-pause:$true
IF /I "%~1"=="-pause" SET PAUSE_FLAG=-pause:$true
IF /I "%~1"=="audio" SET AUDIO_FLAG=-audio:$true
IF /I "%~1"=="-audio" SET AUDIO_FLAG=-audio:$true
IF /I "%~1"=="noaudio" SET AUDIO_FLAG=-audio:$false
IF /I "%~1"=="-noaudio" SET AUDIO_FLAG=-audio:$false
IF /I "%~1"=="print" SET PRINT_FLAG=-print:$true
IF /I "%~1"=="-print" SET PRINT_FLAG=-print:$true
IF /I "%~1"=="noprint" SET PRINT_FLAG=-print:$false
IF /I "%~1"=="-noprint" SET PRINT_FLAG=-print:$false

IF /I "%~1"=="manualserver" SET MANUALSERVER=1
IF /I "%~1"=="-manualserver" SET MANUALSERVER=1
IF /I "%~1"=="manualworkstation" SET MANUALWORKSTATION=1
IF /I "%~1"=="-manualworkstation" SET MANUALWORKSTATION=1
IF /I "%~1"=="autoserver" SET AUTOSERVER=1& SET SERVER_FLAG=-server:$true
IF /I "%~1"=="-autoserver" SET AUTOSERVER=1& SET SERVER_FLAG=-server:$true
IF /I "%~1"=="autoworkstation" SET AUTOWORKSTATION=1& SET WORKSTATION_FLAG=-workstation:$true
IF /I "%~1"=="-autoworkstation" SET AUTOWORKSTATION=1& SET WORKSTATION_FLAG=-workstation:$true
IF /I "%~1"=="disableserver" SET DISABLESERVER_FLAG=-DisableServer
IF /I "%~1"=="-disableserver" SET DISABLESERVER_FLAG=-DisableServer
IF /I "%~1"=="disableworkstation" SET DISABLEWORKSTATION_FLAG=-DisableWorkstation
IF /I "%~1"=="-disableworkstation" SET DISABLEWORKSTATION_FLAG=-DisableWorkstation
IF /I "%~1"=="nobrokers" SET BROKERS_FLAG=-brokers:$false
IF /I "%~1"=="-nobrokers" SET BROKERS_FLAG=-brokers:$false
IF /I "%~1"=="startsearch" SET STARTSEARCH_FLAG=-startsearch:$true
IF /I "%~1"=="-startsearch" SET STARTSEARCH_FLAG=-startsearch:$true
IF /I "%~1"=="nostartsearch" SET STARTSEARCH_FLAG=-startsearch:$false
IF /I "%~1"=="-nostartsearch" SET STARTSEARCH_FLAG=-startsearch:$false
IF /I "%~1"=="nobounce" SET NOBOUNCE_FLAG=-NoBounce
IF /I "%~1"=="-nobounce" SET NOBOUNCE_FLAG=-NoBounce
IF /I "%~1"=="norestartexplorer" SET NORESTARTEXPLORER_FLAG=-NoRestartExplorer
IF /I "%~1"=="-norestartexplorer" SET NORESTARTEXPLORER_FLAG=-NoRestartExplorer
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

REM Validate mutual exclusivity for LanmanServer: only one of manual/auto/disable
IF NOT "%DISABLESERVER_FLAG%"=="" IF DEFINED MANUALSERVER (
    ECHO ERROR: disableserver and manualserver are mutually exclusive.
    EXIT /B 4
)
IF NOT "%DISABLESERVER_FLAG%"=="" IF DEFINED AUTOSERVER (
    ECHO ERROR: disableserver and autoserver are mutually exclusive.
    EXIT /B 4
)
IF DEFINED MANUALSERVER IF DEFINED AUTOSERVER (
    ECHO ERROR: manualserver and autoserver are mutually exclusive.
    EXIT /B 4
)

REM Validate mutual exclusivity for LanmanWorkstation: only one of manual/auto/disable
IF NOT "%DISABLEWORKSTATION_FLAG%"=="" IF DEFINED MANUALWORKSTATION (
    ECHO ERROR: disableworkstation and manualworkstation are mutually exclusive.
    EXIT /B 4
)
IF NOT "%DISABLEWORKSTATION_FLAG%"=="" IF DEFINED AUTOWORKSTATION (
    ECHO ERROR: disableworkstation and autoworkstation are mutually exclusive.
    EXIT /B 4
)
IF DEFINED MANUALWORKSTATION IF DEFINED AUTOWORKSTATION (
    ECHO ERROR: manualworkstation and autoworkstation are mutually exclusive.
    EXIT /B 4
)

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

IF NOT "%DISABLESERVER_FLAG%"=="" (
    ECHO   LanmanServer: Disabled + stopped
) ELSE IF DEFINED AUTOSERVER (
    ECHO   LanmanServer: Automatic + started
) ELSE (
    ECHO   LanmanServer: Manual + stopped ^(default^)
)
IF NOT "%DISABLEWORKSTATION_FLAG%"=="" (
    ECHO   LanmanWorkstation: Disabled + stopped
) ELSE IF DEFINED AUTOWORKSTATION (
    ECHO   LanmanWorkstation: Automatic + started
) ELSE (
    ECHO   LanmanWorkstation: Manual + stopped ^(default^)
)
ECHO   Broker services: %BROKERS_FLAG:-brokers:=%
ECHO   Start/Search services: %STARTSEARCH_FLAG:-startsearch:=%
IF NOT "%NOBOUNCE_FLAG%"=="" ECHO   NoBounce mode: enabled ^(skips most immediate stop/start transitions; disabled services are still stopped^)
IF NOT "%NORESTARTEXPLORER_FLAG%"=="" ECHO   NoRestartExplorer: explorer.exe and ctfmon.exe will NOT be restarted ^(Start menu auto-type may not work^)
ECHO   Pause on completion: %PAUSE_FLAG:-pause:=%
IF NOT "%WHATIF_FLAG%"=="" ECHO   Mode: TEST MODE (WhatIf)
IF NOT "%WHATIF_FLAG%"=="" ECHO   NOTE: WhatIf does not apply service changes or post-run Start/Search repairs.
IF NOT "%FORCE_FLAG%"=="" ECHO   Confirmation prompt: skipped ^(Force^)
ECHO.

REM Execute PowerShell script with error handling
%POWERSHELLEXECUTABLE% -ExecutionPolicy Bypass -NoProfile -File "%SCRIPT_DIR%stop-services.ps1" %AUDIO_FLAG% %PRINT_FLAG% %SERVER_FLAG% %WORKSTATION_FLAG% %BROKERS_FLAG% %STARTSEARCH_FLAG% %NOBOUNCE_FLAG% %NORESTARTEXPLORER_FLAG% %PAUSE_FLAG% %WHATIF_FLAG% %FORCE_FLAG% %DISABLESERVER_FLAG% %DISABLEWORKSTATION_FLAG%

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
ECHO   pause              - Pause before script exits
ECHO   noaudio            - Disable audio services (default: audio enabled)
ECHO   noprint            - Disable print services (default: print enabled)

ECHO.
ECHO   LanmanServer (SMB server) - pick one (mutually exclusive):
ECHO     manualserver       - Manual + stopped (default, explicit no-op for clarity)
ECHO     autoserver         - Automatic + started. Enables file/print/pipe sharing
ECHO     disableserver      - Disabled + stopped. Prevents file/print/pipe sharing on reboot
ECHO.
ECHO   LanmanWorkstation (SMB client) - pick one (mutually exclusive):
ECHO     manualworkstation  - Manual + stopped (default, explicit no-op for clarity)
ECHO     autoworkstation    - Automatic + started. Enables mapped drives, UNC, domain access
ECHO     disableworkstation - Disabled + stopped. Breaks mapped drives, UNC, domain access
ECHO.
ECHO   nobrokers          - Disable broker services (default: brokers enabled)
ECHO   nostartsearch      - Disable Start/Search input services (default: enabled)
ECHO   nobounce           - Skip most immediate stop/start transitions; disabled services are still stopped
ECHO   norestartexplorer  - Skip post-run explorer.exe/ctfmon.exe restart (Start menu auto-type may break)
ECHO   whatif             - Show what would happen without making changes
ECHO   force              - Skip interactive security confirmation prompt
ECHO   help, ?            - Show this help message
ECHO.
ECHO Examples:
ECHO   %~nx0 force
ECHO   %~nx0 noaudio noprint force

ECHO   %~nx0 disableserver disableworkstation force
ECHO   %~nx0 disableserver force
ECHO   %~nx0 autoworkstation force
ECHO   %~nx0 autoserver autoworkstation force
ECHO   %~nx0 nobrokers force
ECHO   %~nx0 audio nobounce force
ECHO   %~nx0 whatif
ECHO.
ECHO Recovery note: if Start menu typing does not work after service changes,
ECHO run without 'nostartsearch' and restart explorer.exe or sign out/sign in.
ECHO.
ECHO This script requires Administrator privileges to modify Windows services.
PAUSE
EXIT /B 0

:EOF
