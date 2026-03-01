# Stop and Disable Windows Services

Copyright 2024-2025 Maxim Masiutin. All rights reserved

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

- `$True` (default in PowerShell): Audio services set to Automatic startup and started
- `$False` (default in CMD wrapper): Audio services set to Manual startup and stopped

### -print

Controls printing, scanning, and imaging services (Spooler, Canon, HP, ScanSnap, PrintNotify, PrintScanBrokerService, DeviceInstall, WIA, etc.):

- `$True` (default in PowerShell): Print services set to Automatic startup and started
- `$False` (default in CMD wrapper): Print services set to Manual startup and stopped

### -workstation

Controls workstation networking services (LanmanWorkstation):

- `$True` (default): Workstation services set to Automatic startup and started
- `$False`: Workstation services set to Manual startup and stopped

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
- In this mode, end-of-run Explorer refresh is also skipped
- Disabled services are still stopped in this mode for consistency and security hardening

Warning when NOT using `-NoBounce`:

- After a run with immediate stop/start transitions, Start menu behavior may be temporarily inconsistent.
- `Ctrl+Esc` may not immediately put keyboard focus into Start search.
- If you start typing in Start menu without explicitly placing the mouse cursor in the search input line, typing may not work until shell input focus is restored.

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
# Default: Keep audio, print, workstation, brokers enabled
./stop-services.ps1

# Disable audio and print services, pause at end
./stop-services.ps1 -audio $False -print $False -pause $True

# Test what would happen without making changes
./stop-services.ps1 -audio $False -WhatIf

# Apply startup type changes only (no immediate stop/start)
./stop-services.ps1 -audio $False -print $False -NoBounce

# Recommended stable profile for this repository use case
./stop-services.ps1 -workstation $False -audio $True -print $False -brokers $True -startsearch $True -NoBounce -Force

# Detailed logging with verbose output
./stop-services.ps1 -audio $False -print $False -Verbose -LogFile "C:\ServiceLog.txt"
```

### CMD Wrapper Usage

The included `stop-services.cmd` provides a convenient wrapper:

```cmd
REM Default behavior (audio/print disabled, workstation/brokers enabled)
stop-services.cmd

REM Enable audio and print services
stop-services.cmd audio print

REM Disable workstation and broker services
stop-services.cmd noworkstation nobrokers

REM Disable Start/Search typing dependencies
stop-services.cmd nostartsearch

REM Startup-type changes only (no immediate stop/start)
stop-services.cmd nobounce

REM Recommended stable profile
stop-services.cmd noworkstation audio nobounce

REM Pause at completion
stop-services.cmd pause

REM Show help
stop-services.cmd help
```

#### CMD Wrapper Features

- Administrative privilege checking: Automatically verifies admin rights
- PowerShell detection: Finds PowerShell Core (pwsh) or Windows PowerShell automatically
- Enhanced parameter parsing: Supports flexible argument formats
- Better error handling: Provides clear error messages and exit codes
- Help system: Built-in help with `help` or `?` arguments
- WhatIf support: Support for testing mode via `whatif` argument
- Conservative defaults: CMD wrapper defaults to audio/print disabled unless you explicitly pass `audio` and/or `print`

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
