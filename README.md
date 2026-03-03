# Stop and Disable Windows Services

Copyright 2024-2026 Maxim Masiutin. All rights reserved

This PowerShell script comprehensively manages Windows services by stopping, starting, enabling, and disabling services across multiple categories including audio, printing/scanning, smart card, workstation, broker services, and vendor-specific applications.

## Important Requirements

- Administrator privileges required: This script must be run as Administrator to modify Windows services
- PowerShell version: PowerShell Core (pwsh) 7.5+ is the recommended and tested runtime; the CMD wrapper can fall back to Windows PowerShell when pwsh is not available
- PowerShell execution policy: If running the script gives an error that scripts cannot be loaded because running scripts are disabled, enable script execution by running `Set-ExecutionPolicy RemoteSigned` in PowerShell

> [!IMPORTANT]
> Backup Recommended: Because this script modifies over 200 services and disables several security components, it is highly recommended to create a System Restore Point before running it without the `-WhatIf` flag.

## What This Script Does and What it Does Not

The script manages over 200 Windows services across these categories:

- Vendor Services: ASUS, Dell, Intel, NVIDIA, Razer, HP, Canon, Conexant, Realtek, Focusrite, Adobe, Google, VMware, and others
- Windows Core Services: Gaming, telemetry, diagnostics, update services, background apps
- Network Services: Bluetooth, WiFi, remote access, sharing services
- Development Services: Docker, virtualization, debugging services
- Security Services: Smart Card (SCardSvr, ScDeviceEnum, DevQueryBroker, WPDBusEnum), biometric services
- Audio/Media Services: Windows Audio, Audio Endpoint Builder, Focusrite Control Server, multimedia services
- Printing/Scanning Services: Print Spooler, Canon, HP, ScanSnap, Print Scan Broker, WIA services

### Service Management Types

- Manual Services: Set to manual startup and stopped (vast majority)
- Disabled Services: Completely disabled and stopped (security/privacy services)
- Stopped Services: Services that are just stopped but keep their startup type
- Started Services: Services that are started without changing startup type
- Protected Services: Essential system services that are never modified (documented in code)

## PowerShell Script Parameters

### -audio

Controls audio-related services (AudioSrv, AudioEndpointBuilder, Focusrite Control Server, ShellHWDetection):

- `$True` (default): Audio services set to Automatic startup and started
- `$False`: Audio services set to Manual startup and stopped


### -print

Controls printing, scanning, and imaging services (Spooler, Canon, HP, ScanSnap, PrintNotify, PrintScanBrokerService, DeviceInstall, WIA, etc.):

- `$True` (default): Print services set to Automatic startup and started
- `$False`: Print services set to Manual startup and stopped


### SMB Service Control

Both LanmanServer (Server) and LanmanWorkstation (Workstation) support three modes each.
For each service, pick one mode. The three options per service are mutually exclusive.

| Mode | Server (LanmanServer) | Workstation (LanmanWorkstation) |
|---|---|---|
| **Manual + stopped** (default) | `-server:$false` / CMD: `manualserver` | `-workstation:$false` / CMD: `manualworkstation` |
| **Automatic + started** | `-server:$true` / CMD: `autoserver` | `-workstation:$true` / CMD: `autoworkstation` |
| **Disabled + stopped** | `-DisableServer` / CMD: `disableserver` | `-DisableWorkstation` / CMD: `disableworkstation` |

**-DisableServer**: Prevents file/print/named-pipe sharing from this machine even after reboot.

**-DisableWorkstation**: Prevents SMB client access (mapped drives, UNC paths, domain resources) even after reboot. Other services (e.g. Netlogon, Browser) may log errors.

### -brokers

Controls Windows background task and token broker services:

- `$True` (default): Broker services (BrokerInfrastructure, SysMain) set to Automatic startup and started
- `$False`: Broker services set to Manual startup and stopped

Note: `SystemEventsBroker` is intentionally not managed by this script.
Note: `TokenBroker` is managed separately in the stop list and protected from startup-type changes/stops when required for sign-in safety.

### -pause

Controls script completion behavior:

- `$False` (default): Script exits immediately after completion
- `$True`: Script waits for user keypress before exiting

### -WhatIf

- When specified, shows what the script would do without actually making changes
- Useful for testing and validation before running the actual changes
- Usage Strategy: Once you are satisfied with the `-WhatIf` output and want to apply the changes, simply remove the `-WhatIf` parameter.
- In `-WhatIf` mode, post-run Start/Search repair actions are preview-only and are not applied.

### -startsearch

Controls Start menu type-to-search dependencies (including `WSearch`, `TextInputManagementService`, and push notification channels used by shell UI state):

- `$True` (default): Keeps Start/Search typing dependencies protected and available, excludes a broader shell-stability service set from stop/downgrade phases, runs a post-run self-heal/input repair pass, and performs end-of-run Explorer refresh when `-NoBounce` is not used
- `$False`: Moves these services to Manual and stops them; Start menu typing can stop working until restored

Notes:

- `TextInputManagementService` is treated as startup-type managed; the script ensures it is started but does not force startup type changes.
- For known protected/input services that return access denied on startup-type or action operations, the script treats that as skipped instead of failed.

### -NoBounce

- Changes startup types only and skips immediate stop/start transitions
- Useful when you want to avoid runtime shell/input churn during the same run
- In this mode, explicit stop/start lists and post-run Start/Search repair actions are skipped
- In this mode, end-of-run explorer.exe/ctfmon.exe restart is also skipped
- Disabled services are still stopped in this mode for consistency and security hardening

### -NoRestartExplorer

- Skips the post-run kill and relaunch of explorer.exe and ctfmon.exe
- By default (without `-NoBounce` and without `-NoRestartExplorer`), the script kills and relaunches both processes to restore Start menu keyboard input state after service changes
- CMD wrapper: pass `norestartexplorer`

> [!WARNING]
> **Explorer restart behavior:** By default, the script **kills and relaunches explorer.exe and ctfmon.exe** at the end of each run (unless `-NoBounce` or `-NoRestartExplorer` is used). This is required for Start menu auto-type (pressing Ctrl+Esc then immediately typing to search) to work after service changes. Without this restart:
> - Ctrl+Esc may open Start menu but keyboard focus will not be in the search input
> - Typing after Ctrl+Esc may not produce any visible text
> - The user must click the search input line with the mouse to activate typing
> - Alternatively, manually restart explorer.exe or sign out and sign back in
>
> The explorer restart causes a brief visual flash as the taskbar and desktop icons reload.

### -CheckStartSearchSafety

- Runs a read-only audit and exits without changing services
- Reports whether planned actions could break `Ctrl+Esc` then typing in Start/Search
- Exit code `0`: no risk detected; exit code `3`: potential risk detected

### -Force

- Skips the interactive security warning prompt
- Useful for unattended execution and scheduled runs

### -Verbose

- Provides detailed logging output showing each service operation
- Helpful for troubleshooting and understanding script behavior

### -LogFile

- Specify a file path to save detailed operation logs
- Example: `-LogFile "C:\Logs\ServiceManagement.log"`

## Usage Examples

### Basic Usage (PowerShell)

```powershell
# Default: audio/print on, server/workstation Manual+stopped, brokers Automatic
./stop-services.ps1 -Force

# Disable both SMB services (startup type = Disabled)
./stop-services.ps1 -DisableServer -DisableWorkstation -Force

# Disable server, keep workstation Auto (mapped drives, domain access)
./stop-services.ps1 -DisableServer -workstation $True -Force

# Test what would happen without making changes
./stop-services.ps1 -WhatIf

# Apply startup type changes only (no immediate stop/start, no explorer restart)
./stop-services.ps1 -NoBounce -Force

# Skip explorer.exe restart (keeps taskbar stable, but Start auto-type may break)
./stop-services.ps1 -NoRestartExplorer -Force

# Detailed logging with verbose output
./stop-services.ps1 -Verbose -LogFile "C:\ServiceLog.txt" -Force
```

### CMD Wrapper Usage

The included `stop-services.cmd` provides a convenient wrapper:

```cmd
REM Default behavior (audio/print enabled, server/workstation Manual+stopped)

stop-services.cmd force

REM Disable audio and print services
stop-services.cmd noaudio noprint force


REM Disable both SMB server and client (startup type = Disabled)
stop-services.cmd disableserver disableworkstation force

REM Disable only SMB server, keep workstation Manual+stopped
stop-services.cmd disableserver force

REM Disable broker services
stop-services.cmd nobrokers force

REM Disable Start/Search typing dependencies
stop-services.cmd nostartsearch force

REM Startup-type changes only (no immediate stop/start)
stop-services.cmd nobounce force

REM Stable profile with noaudio
stop-services.cmd noaudio nobounce force


REM Pause at completion
stop-services.cmd pause

REM Show help
stop-services.cmd help
```

#### CMD Wrapper Features

- Administrative privilege checking: Automatically verifies admin rights
- PowerShell detection: Finds PowerShell Core (pwsh) or Windows PowerShell automatically
- Enhanced parameter parsing: Supports flexible argument formats
- Better error handling: Provides clear error messages and exit codes (0=success, 1=no admin, 2=partial failures, 3=safety risk, 4=mutually exclusive flags)
- Help system: Built-in help with `help` or `?` arguments
- WhatIf support: Support for testing mode via `whatif` argument
- Default behavior: CMD wrapper defaults to audio/print enabled (matching .ps1). Pass `noaudio`, `noprint`, `autoserver`, `autoworkstation` to change defaults.


## Safety Features

### Protected Services

The script includes extensive documentation of critical services that should never be disabled:

- Volume Shadow Copy Service (VSS)
- COM+ System Application (COMSysApp)
- Event System (EventSystem)
- Distributed Transaction Coordinator (MSDTC)
- Virtual Disk Service (vds)
- System Restore Services (srservice/SDRSVC)

### Error Handling

- Graceful degradation: Falls back to `sc` and `net` commands if PowerShell cmdlets fail
- Service validation: Checks for service existence before operations
- Wildcard support: Handles services with dynamic names (services ending with `*`)
- Progress tracking: Shows operation progress and completion statistics
- Comprehensive logging: Tracks all operations with timestamps and error details

## Service Categories Managed

| Category | Count | Examples |
|----------|-------|-----------|
| Vendor-Specific | 65+ | ASUS, Dell, Intel, NVIDIA, Razer, Canon, HP, Focusrite services |
| Windows Core | 45+ | Gaming, Store, Update, Telemetry services |
| Network and Connectivity | 20+ | Bluetooth, WiFi, Remote Access services |
| Development and Virtualization | 15+ | VMware, Hyper-V, Container services |
| Security and Smart Card | 15+ | Smart Card, Biometric, Remote Registry |
| Printing and Scanning | 15 | Spooler, Canon, HP, ScanSnap, WIA services |

## Advanced Features

### Wildcard Service Matching

The script intelligently handles services with dynamic names:

- `CDPUserSvc_*` matches all Connected Device Platform user services
- `OneSyncSvc_*` matches all sync services for different users
- `GoogleUpdaterService*` matches all Google updater service versions
- `PrintWorkflowUserSvc_*` matches all print workflow user services

### Multiple Execution Environments

- PowerShell Core (pwsh): Preferred, requires 7.5+
- Windows PowerShell (powershell.exe): Fallback for older systems
- Command Prompt wrapper: For users preferring batch file execution

## Troubleshooting

### Common Issues

1. "Access Denied" errors: Ensure running as Administrator
2. "Cannot find service" warnings: Normal for services not installed on your system
3. Execution policy errors: Run `Set-ExecutionPolicy RemoteSigned` first
4. Services not stopping: Some services have dependencies; check event logs
5. Start menu typing not working: run with `-startsearch $True` (or without `nostartsearch` in CMD), then restart `explorer.exe` or sign out/sign in

### Debugging Tools

- Use `-WhatIf` parameter to preview changes
- Use `-Verbose` for detailed operation logs
- Use `-LogFile` to save operation history
- Check Windows Event Viewer for service-related events

## Important Notes

- System Impact: This script modifies many system services and may affect system functionality
- Backup Recommended: Consider creating a system restore point before running
- Vendor Software: May affect functionality of ASUS, Dell, Intel, NVIDIA, and other vendor software
- Windows Search: If Start/Search dependencies are disabled (for example with `-startsearch $False`), Start menu type-to-search can stop working. Re-enable Start/Search (`-startsearch $True`) and restart Explorer or sign out/sign in to restore shell input state.
- Gaming Impact: May affect Xbox Live, gaming overlays, and related features
- Office Impact: May affect Microsoft Office Click-to-Run updates and features
