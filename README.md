# Stop and Disable Windows Services

Copyright 2024 Maxim Masiutin. All rights reserved

This PowerShell script comprehensively manages Windows services by stopping, starting, enabling, and disabling services across multiple categories including audio, printing, workstation, broker services, and vendor-specific applications.

##  Important Requirements

- **Administrator privileges required**: This script must be run as Administrator to modify Windows services
- **PowerShell execution policy**: If running the script gives an error that scripts cannot be loaded because running scripts are disabled, enable script execution by running `Set-ExecutionPolicy RemoteSigned` in PowerShell

## What This Script Does and What it Does Not

The script manages **over 150 Windows services** across these categories:

- **Vendor Services**: ASUS, Dell, Intel, NVIDIA, Razer, HP, Adobe, Google, VMware, and others
- **Windows Core Services**: Gaming, telemetry, diagnostics, update services, background apps
- **Network Services**: Bluetooth, WiFi, remote access, sharing services
- **Development Services**: Docker, virtualization, debugging services
- **Security Services**: Windows Defender, Smart Card, biometric services
- **Audio/Media Services**: Windows Audio, Audio Endpoint Builder, multimedia services


### Service Management Types

- **Manual Services**: Set to manual startup and stopped (vast majority)
- **Disabled Services**: Completely disabled and stopped (security/privacy services)
- **Stopped Services**: Services that are just stopped but keep their startup type
- **Protected Services**: Essential system services that are never modified (documented in code)

##  PowerShell Script Parameters

### -audio

Controls audio-related services (AudioSrv, AudioEndpointBuilder, ShellHWDetection):

- `$True` (default): Audio services set to **Automatic** startup and started
- `$False`: Audio services set to **Manual** startup and stopped

### -print

Controls printing and imaging services (Spooler, PrintNotify, DeviceInstall, etc.):

- `$True` (default): Print services set to **Automatic** startup and started
- `$False`: Print services set to **Manual** startup and stopped

### -workstation

Controls workstation networking services (LanmanWorkstation):

- `$True` (default): Workstation services set to **Automatic** startup and started
- `$False`: Workstation services set to **Manual** startup and stopped

### -brokers

Controls Windows background task and token broker services:

- `$True` (default): Broker services (BrokerInfrastructure, SystemEventsBroker, SysMain, TokenBroker) set to **Automatic** startup and started
- `$False`: Broker services set to **Manual** startup and stopped

### -pause

Controls script completion behavior:

- `$False` (default): Script exits immediately after completion
- `$True`: Script waits for user keypress before exiting

### -WhatIf *(NEW)*

- When specified, shows what the script would do without actually making changes
- Useful for testing and validation before running the actual changes

### -Verbose *(NEW)*

- Provides detailed logging output showing each service operation
- Helpful for troubleshooting and understanding script behavior

### -LogFile *(NEW)*

- Specify a file path to save detailed operation logs
- Example: `-LogFile "C:\Logs\ServiceManagement.log"`

##  Usage Examples

### Basic Usage (PowerShell)

```powershell
# Default: Keep audio, print, workstation, brokers enabled
./stop-services.ps1

# Disable audio and print services, pause at end
./stop-services.ps1 -audio $False -print $False -pause $True

# Test what would happen without making changes
./stop-services.ps1 -audio $False -WhatIf

# Detailed logging with verbose output
./stop-services.ps1 -audio $False -print $False -Verbose -LogFile "C:\ServiceLog.txt"
```

### CMD Wrapper Usage *(ENHANCED)*

The included `stop-services.cmd` provides a convenient wrapper with improved error handling:

```cmd
REM Default behavior (audio/print disabled, workstation/brokers enabled)
stop-services.cmd

REM Enable audio and print services
stop-services.cmd audio print

REM Disable workstation and broker services
stop-services.cmd noworkstation nobrokers

REM Pause at completion
stop-services.cmd pause

REM Show help
stop-services.cmd help
```

#### CMD Wrapper Features *(NEW)*

- **Administrative privilege checking**: Automatically verifies admin rights
- **PowerShell detection**: Finds PowerShell Core (pwsh) or Windows PowerShell automatically
- **Enhanced parameter parsing**: Supports flexible argument formats
- **Better error handling**: Provides clear error messages and exit codes
- **Help system**: Built-in help with `help` or `?` arguments

##  Safety Features

### Protected Services

The script includes extensive documentation of **critical services that should never be disabled**:

- Volume Shadow Copy Service (VSS)
- COM+ System Application (COMSysApp)
- Event System (EventSystem)
- Distributed Transaction Coordinator (MSDTC)
- Virtual Disk Service (vds)
- System Restore Services (srservice/SDRSVC)

### Error Handling

- **Graceful degradation**: Falls back to `sc` and `net` commands if PowerShell cmdlets fail
- **Service validation**: Checks for service existence before operations
- **Wildcard support**: Handles services with dynamic names (services ending with `*`)
- **Progress tracking**: Shows operation progress and completion statistics
- **Comprehensive logging**: Tracks all operations with timestamps and error details

##  Service Categories Managed

| Category | Count | Examples |
|----------|-------|-----------|
| Vendor-Specific | 60+ | ASUS, Dell, Intel, NVIDIA, Razer services |
| Windows Core | 40+ | Gaming, Store, Update, Telemetry services |
| Network & Connectivity | 20+ | Bluetooth, WiFi, Remote Access services |
| Development & Virtualization | 15+ | VMware, Hyper-V, Container services |
| Security & Privacy | 10+ | Defender, Telemetry, Remote Registry |

##  Advanced Features

### Wildcard Service Matching

The script intelligently handles services with dynamic names:

- `CDPUserSvc_*` matches all Connected Device Platform user services
- `OneSyncSvc_*` matches all sync services for different users
- `GoogleUpdaterService*` matches all Google updater service versions

### Multiple Execution Environments

- **PowerShell Core (pwsh)**: Preferred for cross-platform compatibility
- **Windows PowerShell (powershell.exe)**: Fallback for older systems
- **Command Prompt wrapper**: For users preferring batch file execution

##  Troubleshooting

### Common Issues

1. **"Access Denied" errors**: Ensure running as Administrator
2. **"Cannot find service" warnings**: Normal for services not installed on your system
3. **Execution policy errors**: Run `Set-ExecutionPolicy RemoteSigned` first
4. **Services not stopping**: Some services have dependencies; check event logs

### Debugging Tools

- Use `-WhatIf` parameter to preview changes
- Use `-Verbose` for detailed operation logs
- Use `-LogFile` to save operation history
- Check Windows Event Viewer for service-related events

##  Important Notes

- **System Impact**: This script modifies many system services and may affect system functionality
- **Backup Recommended**: Consider creating a system restore point before running
- **Vendor Software**: May affect functionality of ASUS, Dell, Intel, NVIDIA, and other vendor software
- **Gaming Impact**: May affect Xbox Live, gaming overlays, and related features
- **Office Impact**: May affect Microsoft Office Click-to-Run updates and features

##  Version History

- **v1.0**: Initial release with basic service management
- **v1.1**: Enhanced error handling, logging, and CMD wrapper improvements
