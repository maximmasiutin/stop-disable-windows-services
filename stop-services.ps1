<#
.SYNOPSIS
 Stop and Disable Windows Services

 Copyright 2024 Maxim Masiutin. All rights reserved

.DESCRIPTION
 This script manages Windows services across multiple categories by setting startup types and starting/stopping services.
 It includes guardrails for Start menu type-to-search and Windows Hello PIN dependencies.

.PARAMETER audio
 If this parameter is $False, services related to audio will be switched to Manual startup type and stopped. Otherwise, if this parameter is $True, audio services' startup type will be Automatic, and such services will be started. Defaults to $True.

.PARAMETER print
 If this parameter is $False, services related to print will be switched to Manual startup type and stopped. Otherwise, if this parameter is $True, print services' startup type will be Automatic, and such services will be started. Defaults to $True.

.PARAMETER pause
 If this parameter is $True, the script will prompt the user to press any key before it exits. Defaults to $False.

.PARAMETER server
 Controls the LanmanServer (Server/SMB server) service.
 - $False (default): Manual + stopped. File/print sharing will not auto-start.
 - $True: Automatic + started. Enables file/print/named-pipe sharing.
 Ignored when -DisableServer is used.
 CMD wrapper: "autoserver" = $True, "manualserver" = $False (default, explicit no-op).

.PARAMETER workstation
 Controls the LanmanWorkstation (Workstation/SMB client) service.
 - $False (default): Manual + stopped. SMB client access will not auto-start.
 - $True: Automatic + started. Enables mapped drives, UNC paths, domain resources.
 Ignored when -DisableWorkstation is used.
 CMD wrapper: "autoworkstation" = $True, "manualworkstation" = $False (default, explicit no-op).

.PARAMETER DisableServer
 Sets LanmanServer startup type to Disabled and stops it. Overrides -server flag.
 Prevents file/print/named-pipe sharing even after reboot.
 CMD wrapper: "disableserver". Mutually exclusive with manualserver and autoserver.

.PARAMETER DisableWorkstation
 Sets LanmanWorkstation startup type to Disabled and stops it. Overrides -workstation flag.
 Prevents SMB client access (mapped drives, UNC paths, domain resources) even after reboot.
 Other services (e.g. Netlogon, Browser) may log errors.
 CMD wrapper: "disableworkstation". Mutually exclusive with manualworkstation and autoworkstation.

.PARAMETER brokers
 If this parameter is $False, services related to brokers will be switched to Manual startup type and stopped. Otherwise, if this parameter is $True, broker services' startup type will be Automatic, and such services will be started. Defaults to $True.
 SystemEventsBroker is intentionally excluded from management and remains untouched.

.PARAMETER CheckStartSearchSafety
 Runs a read-only safety audit for Start menu type-to-search behavior (Ctrl+Esc then type). This mode reports whether planned startup-type/stop actions could break keyboard typing in Start/Search and exits without changing services.
 Exit code 0 means no script-induced risk was detected; exit code 3 means potential risk was detected.

.PARAMETER startsearch
 Controls Start menu type-to-search services.
 - $True (default): keeps Start/Search input services protected and available.
    Also runs a post-run self-heal/input-stack repair pass unless -NoBounce is used.
 - $False: intentionally moves Start/Search input services to Manual and stops them, so Ctrl+Esc then typing may stop working until re-enabled.
    If you re-enable later, restart explorer.exe or sign out/sign in if shell typing does not recover immediately.

.PARAMETER NoBounce
 Applies startup type policy changes without immediate stop/start transitions in the same run.
 This mode reduces runtime churn and is useful when keeping Start menu auto-type stable is a priority.
 In this mode, explicit stop/start lists and post-run Start/Search repair actions are skipped.
 Disabled services are still stopped in this mode for consistency and security hardening.
 When -NoBounce is not used, the script kills and relaunches explorer.exe and ctfmon.exe
 at the end to restore Start menu keyboard input state.
 If you run without -NoBounce, temporary shell input-focus issues can occur: Ctrl+Esc may not
 immediately focus Start search, and typing in Start may fail unless the search input line is
 explicitly focused first.

.PARAMETER NoRestartExplorer
 Skips the post-run restart of explorer.exe and ctfmon.exe. By default (without this flag and
 without -NoBounce), the script kills and relaunches both processes to restore Start menu
 keyboard input state after service changes.
 Warning: without restarting explorer.exe and ctfmon.exe, Start menu auto-type (Ctrl+Esc then
 typing) may not work. The user may need to click the search input line with the mouse to
 activate typing, or manually restart explorer.exe, or sign out and sign back in.
 CMD wrapper: pass "norestartexplorer".

.PARAMETER Force
 Skips the interactive security warning confirmation prompt.
 CMD wrapper: pass "force".

.PARAMETER DisableWindowsUpdate
 Sets all Windows Update services (BITS, DoSvc, wuauserv, UsoSvc, WaaSMedicSvc) to Disabled
 and stops them. Without this flag, these services default to Manual + stopped so that Windows
 Update remains functional when triggered manually or by the system.
 On Windows 11 24H2+, DoSvc (Delivery Optimization) is the primary download engine for both
 Windows Update and Microsoft Store. Disabling it causes download error 0x80004002.
 CMD wrapper: "disablewindowsupdate".

.PARAMETER LogFile
 Specify a file path to save detailed operation logs.
 Example: -LogFile "C:\Logs\ServiceManagement.log"
 Not supported in CMD wrapper; use PowerShell directly.

.PARAMETER WhatIf
 Shows what the script would do without making changes. Post-run Start/Search repair actions
 are preview-only and not applied. CMD wrapper: pass "whatif".

.EXAMPLE
 ./stop-services.ps1 -Force

 Default: both SMB services Manual+stopped, audio/print per PS1 defaults, brokers Automatic.

.EXAMPLE
 ./stop-services.ps1 -DisableServer -DisableWorkstation -Force

 Fully disables both SMB services (startup type = Disabled, stopped).

.EXAMPLE
 ./stop-services.ps1 -workstation $True -audio $True -brokers $True -Force

 Sets LanmanWorkstation to Automatic+started, enables audio, keeps LanmanServer Manual+stopped.

.EXAMPLE
 ./stop-services.ps1 -CheckStartSearchSafety -startsearch $True

 Runs a read-only audit for Start/Search type-to-search safety and exits without changing services.

.EXAMPLE
 ./stop-services.ps1 -audio $True -NoBounce -Force

 Applies startup type changes while avoiding immediate stop/start transitions for reduced shell/input churn.
#>

[CmdletBinding(SupportsShouldProcess)]
param(
    [bool]$audio = $true,
    [bool]$print = $true,
    [bool]$pause = $false,
    [bool]$brokers = $true,
    [bool]$server = $false,
    [bool]$workstation = $false,
    [bool]$startsearch = $true,
    [switch]$NoBounce,
    [switch]$NoRestartExplorer,
    [switch]$DisableServer,
    [switch]$DisableWorkstation,
    [switch]$DisableWindowsUpdate,
    [switch]$CheckStartSearchSafety,
    [switch]$Force,
    [string]$LogFile = ""
)

# Check if running with administrator privileges
function Test-Administrator {
    $currentUser = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($currentUser)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

if (-not (Test-Administrator)) {
    if ($CheckStartSearchSafety) {
        Write-Warning "Running Start/Search safety audit without Administrator privileges. Read-only checks will continue."
    }
    else {
        Write-Error "This script requires Administrator privileges. Please run PowerShell as Administrator."
        if ($pause) {
            Write-Host "Press any key to continue..."
            $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
        }
        exit 1
    }
}

# Initialize logging
$script:LogEntries = @()
function Write-Log {
    param(
        [string]$Message,
        [string]$Level = "Info"
    )
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logEntry = "[$timestamp] [$Level] $Message"
    $script:LogEntries += $logEntry

    switch ($Level) {
        # Use host output for operational errors so pwsh exit code is controlled by explicit exit paths,
        # not by non-terminating error records emitted during expected per-service failures.
        "Error" { Write-Host "ERROR: $Message" -ForegroundColor Red }
        "Warning" { Write-Warning $Message }
        "Info" { Write-Host $Message }
        "Verbose" { if ($Verbose) { Write-Host $Message -ForegroundColor Gray } }
    }
}

# Save log to file if specified
function Save-Log {
    if ($LogFile -ne "") {
        try {
            $script:LogEntries | Out-File -FilePath $LogFile -Append -Encoding UTF8
            Write-Log "Log saved to: $LogFile" "Info"
        }
        catch {
            Write-Log "Failed to save log to $LogFile`: $($_.Exception.Message)" "Warning"
        }
    }
}

function Test-ServiceMatchesPattern {
    param(
        [string]$ServiceName,
        [string]$Pattern
    )

    if ([string]::IsNullOrWhiteSpace($ServiceName) -or [string]::IsNullOrWhiteSpace($Pattern)) {
        return $false
    }

    if ($Pattern.Contains("*")) {
        return ($ServiceName -like $Pattern)
    }

    return ($ServiceName -ieq $Pattern)
}

function Test-ServicePlannedInList {
    param(
        [string]$ServiceName,
        [array]$ServiceList
    )

    foreach ($pattern in $ServiceList) {
        if (Test-ServiceMatchesPattern -ServiceName $ServiceName -Pattern $pattern) {
            return $true
        }
    }
    return $false
}

function Remove-ServicePatternsFromList {
    param(
        [array]$SourceList,
        [array]$PatternsToRemove
    )

    $result = @()
    foreach ($item in $SourceList) {
        $shouldRemove = $false
        foreach ($pattern in $PatternsToRemove) {
            if ($item -ieq $pattern) {
                $shouldRemove = $true
                break
            }
        }

        if (-not $shouldRemove) {
            $result += $item
        }
    }

    return $result
}

function Test-IsStartSearchService {
    param(
        [string]$ServiceName
    )

    $startSearchPatterns = @(
        "WSearch",
        "TextInputManagementService",
        "TabletInputService",
        "WpnService",
        "WpnUserService",
        "WpnUserService_*"
    )

    foreach ($pattern in $startSearchPatterns) {
        if (Test-ServiceMatchesPattern -ServiceName $ServiceName -Pattern $pattern) {
            return $true
        }
    }

    return $false
}

function Test-IsManagedStartupService {
    param(
        [string]$ServiceName
    )

    $managedPatterns = @(
        "TextInputManagementService"
    )

    foreach ($pattern in $managedPatterns) {
        if (Test-ServiceMatchesPattern -ServiceName $ServiceName -Pattern $pattern) {
            return $true
        }
    }

    return $false
}

function Test-IsKnownProtectedInputService {
    param(
        [string]$ServiceName
    )

    $knownPatterns = @(
        "TextInputManagementService",
        "TabletInputService",
        "WpnService",
        "WpnUserService_*",
        "TokenBroker",
        "WbioSrvc",
        "cloudidsvc"
    )

    foreach ($pattern in $knownPatterns) {
        if (Test-ServiceMatchesPattern -ServiceName $ServiceName -Pattern $pattern) {
            return $true
        }
    }

    return $false
}

function Get-ServiceStartupTypeSafe {
    param(
        [string]$ServiceName
    )

    try {
        $cimService = Get-CimInstance -ClassName Win32_Service -Filter "Name='$ServiceName'" -ErrorAction Stop
        switch ($cimService.StartMode) {
            "Auto" { return "Automatic" }
            "Manual" { return "Manual" }
            "Disabled" { return "Disabled" }
            default { return $cimService.StartMode }
        }
    }
    catch {
        return "Unknown"
    }
}

function Set-ServiceStartupTypeRegistryFallback {
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [string]$ServiceName,
        [string]$StartupType
    )

    $registryValue = switch ($StartupType) {
        "Automatic" { 2 }
        "Manual" { 3 }
        "Disabled" { 4 }
        default { $null }
    }

    if ($null -eq $registryValue) {
        Write-Log "Registry fallback: invalid startup type '$StartupType' for service '$ServiceName'." "Warning"
        return "Failed"
    }

    $serviceKeyPath = "HKLM:\SYSTEM\CurrentControlSet\Services\$ServiceName"
    if (-not (Test-Path $serviceKeyPath)) {
        Write-Log "Registry fallback: service key not found for $ServiceName. Skipping." "Verbose"
        return "Skipped"
    }

    try {
        if ($psCmdlet.ShouldProcess("Registry: $serviceKeyPath", "Set Start=$registryValue")) {
            Set-ItemProperty -Path $serviceKeyPath -Name "Start" -Value $registryValue -ErrorAction Stop
            Write-Log "Registry fallback applied for $($ServiceName): Start=$registryValue." "Info"
        }
        return "Success"
    }
    catch {
        $msg = $_.Exception.Message
        if ($msg -like "*Access is denied*" -or $msg -like "*PermissionDenied*") {
            if (Test-IsKnownProtectedInputService -ServiceName $ServiceName) {
                Write-Log "Registry fallback denied for protected/input service $ServiceName. Treating as skipped." "Warning"
                return "Skipped"
            }
        }

        Write-Log "Registry fallback failed for $ServiceName`: $msg" "Error"
        return "Failed"
    }
}

function Invoke-StartSearchSafetyCheck {
    param(
        [array]$AutoList,
        [array]$ManualList,
        [array]$DisableList,
        [array]$StopList,
        [array]$StartList
    )

    Write-Log "=== Start/Search Safety Audit (Read-Only) ===" "Info"
    Write-Log "Checking whether planned operations can break Ctrl+Esc -> immediate typing in Start menu search." "Info"

    $criticalDefinitions = @(
        @{ Pattern = "BrokerInfrastructure"; Reason = "Core shell background task broker for Start/Search" },
        @{ Pattern = "StateRepository"; Reason = "Maintains Start menu shell state" },
        @{ Pattern = "WSearch"; Reason = "Search backend for Start menu type-to-search" },
        @{ Pattern = "TextInputManagementService"; Reason = "Text input routing to search UI" },
        @{ Pattern = "TabletInputService"; Reason = "Legacy text input service used on some builds" },
        @{ Pattern = "AppXSVC"; Reason = "App model integration used by Start" },
        @{ Pattern = "ClipSVC"; Reason = "App activation path used by Start entries" },
        @{ Pattern = "ShellHWDetection"; Reason = "Shell event routing dependency" },
        @{ Pattern = "WpnService"; Reason = "Core push channel used by shell UI state" },
        @{ Pattern = "WpnUserService_*"; Reason = "Per-user push channel used by Start UI state" }
    )

    $protectedFromChange = @(
        "BrokerInfrastructure",
        "StateRepository",
        "AppXSVC",
        "ClipSVC",
        "ShellHWDetection"
    )

    $protectedFromStop = @(
        "BrokerInfrastructure",
        "StateRepository",
        "AppXSVC",
        "ClipSVC",
        "ShellHWDetection"
    )

    $riskCount = 0
    $checkedCount = 0

    foreach ($definition in $criticalDefinitions) {
        $pattern = $definition.Pattern
        $reason = $definition.Reason
        $matchedServices = @()

        if ($pattern.Contains("*")) {
            $matchedServices = Get-Service -Name $pattern -ErrorAction SilentlyContinue
        }
        else {
            $single = Get-Service -Name $pattern -ErrorAction SilentlyContinue
            if ($single) { $matchedServices = @($single) }
        }

        if (-not $matchedServices -or $matchedServices.Count -eq 0) {
            Write-Log "[INFO] $pattern not present on this system ($reason)." "Info"
            continue
        }

        foreach ($service in $matchedServices) {
            $checkedCount++
            $name = $service.Name
            $startupType = Get-ServiceStartupTypeSafe -ServiceName $name

            $plannedStartupType = "NoChange"
            if (Test-ServicePlannedInList -ServiceName $name -ServiceList $DisableList) {
                $plannedStartupType = "Disabled"
            }
            elseif (Test-ServicePlannedInList -ServiceName $name -ServiceList $ManualList) {
                $plannedStartupType = "Manual"
            }
            elseif (Test-ServicePlannedInList -ServiceName $name -ServiceList $AutoList) {
                $plannedStartupType = "Automatic"
            }

            $plannedStop = (Test-ServicePlannedInList -ServiceName $name -ServiceList $StopList) -or
                (Test-ServicePlannedInList -ServiceName $name -ServiceList $ManualList) -or
                (Test-ServicePlannedInList -ServiceName $name -ServiceList $DisableList)

            $plannedStart = (Test-ServicePlannedInList -ServiceName $name -ServiceList $StartList) -or
                (Test-ServicePlannedInList -ServiceName $name -ServiceList $AutoList)

            $startupProtected = ($name -in $protectedFromChange)
            $stopProtected = ($name -in $protectedFromStop)

            if ($startsearch -and (Test-IsStartSearchService -ServiceName $name)) {
                $startupProtected = $true
                $stopProtected = $true
            }

            $startupRisk = (($plannedStartupType -eq "Manual") -or ($plannedStartupType -eq "Disabled")) -and (-not $startupProtected)
            $stopRisk = $plannedStop -and (-not $stopProtected)

            if ($startupRisk -or $stopRisk) {
                $riskCount++
                Write-Log "[RISK] $name | Now: status=$($service.Status), startup=$startupType | Plan: startup->$plannedStartupType, stop=$plannedStop, start=$plannedStart | Reason: $reason" "Warning"
            }
            else {
                Write-Log "[OK] $name | Now: status=$($service.Status), startup=$startupType | Plan: startup->$plannedStartupType, stop=$plannedStop, start=$plannedStart | Reason: $reason" "Info"
            }
        }
    }

    Write-Log "Checked $checkedCount Start/Search-related service instance(s)." "Info"
    if ($riskCount -eq 0) {
        Write-Log "Safety audit result: no script-induced Start/Search typing risk detected." "Info"
        return $true
    }

    Write-Log "Safety audit result: detected $riskCount potential risk(s). Review lists before running service changes." "Warning"
    return $false
}

function Invoke-StartSearchSelfHeal {
    [CmdletBinding(SupportsShouldProcess)]
    param()

    Write-Log "=== Start/Search Self-Heal (Post-Run) ===" "Info"

    # Broader critical set than the minimal Start/Search list. These services influence shell activation,
    # app model state, and keyboard routing into Start/Search.
    $criticalServices = @(
        "BrokerInfrastructure",
        "StateRepository",
        "AppXSVC",
        "ClipSVC",
        "ShellHWDetection",
        "WSearch",
        "TextInputManagementService",
        "TabletInputService",
        "WpnService",
        "WpnUserService_*"
    )

    foreach ($servicePattern in $criticalServices) {
        $services = @()

        if ($servicePattern.Contains("*")) {
            $services = Get-Service -Name $servicePattern -ErrorAction SilentlyContinue
        }
        else {
            $single = Get-Service -Name $servicePattern -ErrorAction SilentlyContinue
            if ($single) { $services = @($single) }
        }

        if (-not $services -or $services.Count -eq 0) {
            Write-Log "Start/Search self-heal: service '$servicePattern' is not present on this system. Skipping." "Verbose"
            continue
        }

        foreach ($service in $services) {
            if (-not (Test-IsManagedStartupService -ServiceName $service.Name)) {
                [void](Set-ServiceStartupType -serviceName $service.Name -startupType "Automatic")
            }
            [void](Invoke-ServiceManagement -serviceName $service.Name -action "Start")
        }
    }

    # Refresh the text input host to reduce stale shell input routing after service changes.
    try {
        $ctfPath = Join-Path $env:WINDIR "System32\ctfmon.exe"
        if (Test-Path $ctfPath) {
            Start-Process -FilePath $ctfPath -ErrorAction SilentlyContinue
            Write-Log "Start/Search self-heal: ctfmon refresh requested." "Verbose"
        }
    }
    catch {
        Write-Log "Start/Search self-heal: failed to refresh ctfmon: $($_.Exception.Message)" "Warning"
    }
}

function Invoke-StartSearchInputStackRepair {
    [CmdletBinding(SupportsShouldProcess)]
    param()

    Write-Log "=== Start/Search Input Stack Repair (Post-Run) ===" "Info"

    # Refresh text input host explicitly.
    try {
        $ctfPath = Join-Path $env:WINDIR "System32\ctfmon.exe"
        if (Test-Path $ctfPath) {
            $existingCtf = Get-Process -Name "ctfmon" -ErrorAction SilentlyContinue
            foreach ($p in $existingCtf) {
                if ($psCmdlet.ShouldProcess("Process: ctfmon ($($p.Id))", "Stop process")) {
                    Stop-Process -Id $p.Id -Force -ErrorAction SilentlyContinue
                }
            }

            if ($psCmdlet.ShouldProcess("Process: ctfmon", "Start process")) {
                Start-Process -FilePath $ctfPath -ErrorAction SilentlyContinue
            }
            Write-Log "Start/Search input stack repair: ctfmon restarted." "Verbose"
        }
    }
    catch {
        Write-Log "Start/Search input stack repair: failed to restart ctfmon: $($_.Exception.Message)" "Warning"
    }

    # Restart shell sidecar processes that usually relaunch automatically.
    $sidecarProcesses = @(
        "SearchHost",
        "StartMenuExperienceHost"
    )

    foreach ($procName in $sidecarProcesses) {
        try {
            $procs = Get-Process -Name $procName -ErrorAction SilentlyContinue
            if (-not $procs) {
                continue
            }

            foreach ($p in $procs) {
                if ($psCmdlet.ShouldProcess("Process: $procName ($($p.Id))", "Restart sidecar process")) {
                    Stop-Process -Id $p.Id -Force -ErrorAction SilentlyContinue
                    Write-Log "Start/Search input stack repair: restarted $procName (PID $($p.Id))." "Verbose"
                }
            }
        }
        catch {
            Write-Log "Start/Search input stack repair: failed to restart $($procName): $($_.Exception.Message)" "Warning"
        }
    }
}

function Invoke-ExplorerRefreshAfterBounce {
    [CmdletBinding(SupportsShouldProcess)]
    param()

    Write-Log "=== Explorer Refresh (Post-Run) ===" "Info"

    try {
        if ($psCmdlet.ShouldProcess("Process: explorer", "Restart explorer and refresh text input host")) {
            Stop-Process -Name explorer -Force -ErrorAction SilentlyContinue
            Start-Process explorer.exe -ErrorAction SilentlyContinue

            $ctfPath = Join-Path $env:WINDIR "System32\ctfmon.exe"
            if (Test-Path $ctfPath) {
                Start-Process -FilePath $ctfPath -ErrorAction SilentlyContinue
            }
            Write-Log "Explorer refresh completed (explorer + ctfmon)." "Info"
        }
    }
    catch {
        Write-Log "Explorer refresh failed: $($_.Exception.Message)" "Warning"
    }
}

# Function to show security warning and get confirmation
function Show-SecurityWarning {
    # Detect WhatIf or Force at the script level
    if ($Force -or $PSCmdlet.MyInvocation.BoundParameters.ContainsKey('WhatIf')) {
        return $true
    }

    Write-Host "`n" -NoNewline
    Write-Host "****************************************************************" -ForegroundColor Yellow
    Write-Host "*                      SECURITY WARNING                        *" -ForegroundColor Yellow
    Write-Host "****************************************************************" -ForegroundColor Yellow
    Write-Host "This script will modify over 200 Windows services, including:"
    Write-Host " - Disabling Windows Defender and Web Threat Defense"
    Write-Host " - Disabling Windows Update and Security Center"
    Write-Host " - Stopping Telemetry and Diagnostics"
    Write-Host ""
    Write-Host "It is HIGHLY RECOMMENDED to create a System Restore Point before"
    Write-Host "proceeding if you haven't already done so."
    Write-Host ""
    
    $confirmation = Read-Host "Do you want to proceed? (Type 'Y' and press Enter to continue)"
    if ($confirmation -eq 'Y' -or $confirmation -eq 'y') {
        Write-Log "User confirmed security warning." "Info"
        return $true
    }
    else {
        Write-Log "User declined security warning. Exiting." "Warning"
        return $false
    }
}

Write-Log "=== Windows Service Management Script Started ===" "Info"
Write-Log "Parameters: audio=$audio, print=$print, server=$server, workstation=$workstation, brokers=$brokers, startsearch=$startsearch, NoBounce=$NoBounce, NoRestartExplorer=$NoRestartExplorer, DisableServer=$DisableServer, DisableWorkstation=$DisableWorkstation, DisableWindowsUpdate=$DisableWindowsUpdate, pause=$pause, CheckStartSearchSafety=$CheckStartSearchSafety, Force=$Force, WhatIf=$($PSBoundParameters.ContainsKey('WhatIf'))" "Info"

# Validate mutual exclusivity: -DisableServer vs -server:$true
if ($DisableServer -and $server -eq $true) {
    Write-Error "-DisableServer and -server:`$true are mutually exclusive. Pick one mode for LanmanServer."
    exit 4
}

# Validate mutual exclusivity: -DisableWorkstation vs -workstation:$true
if ($DisableWorkstation -and $workstation -eq $true) {
    Write-Error "-DisableWorkstation and -workstation:`$true are mutually exclusive. Pick one mode for LanmanWorkstation."
    exit 4
}

if (-not $CheckStartSearchSafety -and -not (Show-SecurityWarning)) {
    if ($pause) {
        Write-Host "Press any key to continue..."
        $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
    }
    exit 0
}

# Note: the following services should be automatically started to avoid errors such as "Volume Shadow Copy Service error: Unexpected error calling routine IVssAsrWriterBackup::GetDiskComponents"
# - COMSysApp - COM+ System Application Service: Provides support for COM+ components. If this service is stopped, most COM+-based components will not function properly.
# - EventSystem - COM+ Event System: Manages event subscriptions and event delivery to COM components. If this service is stopped, most COM+-based components will not function properly.
# - MSDTC - Distributed Transaction Coordinator Service: Coordinates transactions that span multiple resource managers, such as databases, message queues, and file systems. Required for Volume Shadow Copy service and other system components.
# - swprv - Microsoft Software Shadow Copy Provider: Manages software-based volume shadow copies. If this service is stopped, software-based volume shadow copies cannot be managed.
# - srservice - System Restore Service: Creates and manages system restore points. Not present in the latest versions of Windows 11.
# - SDRSVC - System Restore Service: Can replace srservice in the latest versions of Windows 11. Manages system restore points.
# - VSS - Volume Shadow Copy Service: Manages and implements volume shadow copies for backups and other purposes.
# - vds - Virtual Disk Service: Provides management services for disks, volumes, and file systems. Required for Disk Management.

# The "auto" list may be augmented later, depending on our options
$auto_services = @(
)

$manual_services = @(
    "AppXSVC" # AppX Deployment Service - Provides infrastructure support for deploying Store apps. This service is started on demand and if disabled, apps bought using the Store app will not be deployed to the system.
    "AarSvc_*" # AllJoyn Router Service - Manages communication between AllJoyn devices. If disabled, AllJoyn-enabled devices will not function properly.
    "AdobeARMservice" # Adobe Acrobat Update Service - Keeps Adobe Acrobat software up to date. If disabled, Adobe software will not be kept up to date.
    "AESMService" # Intel SGX AESM - Manages Intel Software Guard Extensions (SGX) enabled applications.
    "agent_ovpnconnect" # OpenVPN Agent - Manages OpenVPN connections.
    "AppVClient" # Microsoft App-V Client - Manages App-V users and virtual applications, enabling application virtualization.
    "ArmouryCrateService" # ASUS Armoury Crate Service - Manages settings and updates for ASUS devices.
    "asus" # ASUS Update Service - Keeps ASUS software up to date, ensuring security and functionality.
    "AsusAppService" # ASUS App Service - Monitors the status of services within MyASUS.
    "ASUSOptimization" # ASUS Optimization - Provides hardware and software settings control within MyASUS.
    "AsusROGLSLService" # Asus ROG LSL Service - Manages ROG-related services and settings.
    "ASUSSoftwareManager" # ASUS Software Manager - Supports software, firmware, and driver updates through MyASUS.
    "ASUSSwitch" # ASUS Switch - Provides Switch & Recovery services within MyASUS.
    "ASUSSystemAnalysis" # ASUS System Analysis - Provides hardware information required for System Diagnosis in MyASUS.
    "asusm" # ASUS Management Service - Manages ASUS system components and settings.
    "ASUSSystemDiagnosis" # ASUS System Diagnosis - Provides diagnostic services within MyASUS.
    "atashost" # WebEx Service Host - Provides support for WebEx sessions.
    "BcastDVRUserService_*" # Broadcast DVR User Service - Supports game recordings and live broadcasts.
    # "BITS" -- moved to $windowsupdate_services; required for Windows Update

    "BluetoothUserService_*" # Bluetooth User Service - Supports Bluetooth functionality for each user session.
    "BTAGService" # Bluetooth Audio Gateway Service - Supports the audio gateway role of the Bluetooth Handsfree Profile.
    "BluetoothUserService" # Bluetooth User Service - Supports Bluetooth functionality for each user session.
    "BthAvctpSvc" # AVCTP Service - Audio Video Control Transport Protocol service.
    "bthserv" # Bluetooth Support Service - Manages Bluetooth device discovery and association. Required for proper Bluetooth functionality.
    "camsvc" # Capability Access Manager Service - Manages UWP apps' access to capabilities.
    "cbdhsvc" # Clipboard User Service - Handles clipboard operations.
    "cbdhsvc_*" # Clipboard User Service - Handles clipboard operations for specific user sessions.
    "CDPUserSvc" # Connected Devices Platform User Service - Manages connected device scenarios.
    "CDPUserSvc_*" # Connected Devices Platform User Service - Manages connected device scenarios for specific user sessions.
    "ClickToRunSvc" # Microsoft Office Click-to-Run Service - Manages Office updates and installations.
    "CloudBackupRestoreSvc_*" # Cloud Backup and Restore Service - Monitors changes in application and setting states, and performs cloud backup and restore operations.
    # "cloudidsvc" -- moved to $stop_services; required for Windows Hello PIN login with Microsoft accounts
    "cplspcon" # Intel Content Protection HDCP Service - Enables communication with Content Protection HDCP hardware.
    "CscService" # Offline Files - Manages maintenance activities on the Offline Files cache and responds to user logon and logoff events.
    "CxAudioSvc" # Conexant Audio Service - Manages Conexant audio settings and functionality.
    "CxUIUSvc" # Conexant UIU Service - Supports Conexant user interface utilities.
    "CxUtilSvc" # Conexant Utility Service - Manages Conexant utility features and settings.
    "DDVCollectorSvcApi" # Dell Data Vault Service API - Exposes a COM API for working with Dell Data Vault services.
    "DDVDataCollector" # Dell Data Vault Collector - Gathers system information for later use.
    "DDVRulesProcessor" # Dell Data Vault Processor - Generates alerts based on collected data.
    "debugregsvc" # Network Device Registration Service - Enables device discovery and debugging over the network.
    "Dell Digital Delivery Services" # Dell Digital Delivery Services - Downloads and installs applications purchased with your computer.
    "Dell SupportAssist Remediation" # Dell SupportAssist Remediation Service - Provides remediation services for Dell systems.
    "DellClientManagementService" # Dell Client Management Service - Manages Dell-specific features. Required for dependent services.
    "DellTechHub" # Dell TechHub - Manages Dell applications through Dell TechHub.
    "DellTrustedDevice" # Dell Trusted Device - Enhances physical hardware security.
    "DevQueryBroker" # Device Query Broker - Enables apps to discover devices with a background task.
    "DeviceAssociationBrokerSvc_*" # Device Association Broker Service - Enables apps to pair devices.
    "DeviceAssociationService" # Device Association Service - Manages pairing between the system and devices.
    "Dhcp" # DHCP Client - Registers and updates IP addresses and DNS records. Required for dynamic IP and DNS updates.
    "diagnosticshub.standardcollector.service" # Diagnostics Hub Standard Collector Service - Provides diagnostic data collection.
    "DiagTrack" # Diagnostics Tracking Service - Collects diagnostic data to improve system performance and reliability.
    "DiracAudSrv" # Dirac Audio Service - Enhances audio performance and provides advanced sound processing.
    "DispBrokerDesktopSvc" # Display Broker Desktop Service - Manages connection and configuration of local and remote displays, including resolution and power settings.
    "DisplayEnhancementService" # Display Enhancement Service - Manages display enhancements such as brightness control.
    "dmwappushservice" # WAP Push Message Routing Service - Handles WAP push messages (known issues may exist).
    "DPMService" # Dell Peripheral Manager Service - Manages peripherals connected to Dell systems.
    "DPS" # Diagnostic Policy Service - Enables detection, troubleshooting, and resolution for Windows components. If stopped, diagnostics will not function.
    "dptftcs" # Intel Dynamic Tuning Technology Telemetry Service - Manages telemetry data for Intel Dynamic Tuning Technology.
    "DSAService" # Intel Driver & Support Assistant Service - Manages updates and support for Intel drivers and software.
    "DSAUpdateService" # Intel Driver & Support Assistant Updater - Keeps Intel Driver & Support Assistant up to date.
    "DsmSvc" # Device Setup Manager - Enables detection, download, and installation of device-related software. If disabled, devices may not work correctly.
    "DsSvc" # Data Sharing Service - Provides data brokering between applications.
    "DusmSvc" # Delivery Update Service Manager - Manages delivery and updates of services.
    "edgeupdate" # Microsoft Edge Update Service - Keeps Microsoft Edge software up to date, ensuring security and functionality.
    "esifsvc" # Intel Energy Server Service Interface - Manages power and thermal management for Intel systems.
    "ESRV_SVC_QUEENCREEK" # Energy Server Service (QUEENCREEK) - Intel Energy Checker SDK. This service is CPU-intensive and generates many page faults.
    "fdPHost" # Function Discovery Provider Host - Hosts network discovery providers for SSDP and WS-D protocols. Disabling this service will disable network discovery.
    "FDResPub" # Function Discovery Resource Publication - Publishes this computer and its resources over the network. If stopped, network resources will not be discoverable.
    "FontCache*" # Windows Font Cache Service - Optimizes application performance by caching commonly used font data. Disabling this service will degrade application performance.
    "FoxitReaderUpdateService" # Foxit PDF Reader Update Service - Keeps Foxit PDF Reader up to date.
    "GameInput Service" # Game Input Service - Host service for game input devices and peripherals.
    "GamingServices" # Gaming Services - Manages gaming-related services and features.
    "GamingServicesNet" # Gaming Services Network - Supports network features for gaming services.
    "GoogleChromeElevationService" # Google Chrome Elevation Service - Manages elevation requests for Google Chrome updates.
    "GoogleUpdaterInternalService*" # Google Updater Internal Service - Manages internal updates for Google software.
    "GoogleUpdaterService*" # Google Updater Service - Manages updates for Google software.
    "gupdate" # Google Update Service - Keeps Google software up to date.
    "HNS" # Host Network Service - Provides support for Windows Virtual Networks.
    "HotKeyServiceUWP" # HP Hotkey UWP Service - Handles Fn+F1-F12 hotkey combos for brightness, volume, wireless toggle on HP laptops. Part of HP Hotkey Support driver package. Known to cause high CPU/memory on Windows 11.
    "HPAppHelperCap" # HP App Helper HSA Service - HSA capability broker that launches interdependent HP apps, suspends/resumes devices, adjusts network resources, and enables presence-aware sensors. Runs as background COM service from DriverStore.
    "HPAudioAnalytics" # HP Audio Analytics Service - Collects audio performance telemetry (mic levels, speaker usage, conferencing stats) and reports to HP cloud. Bundled with HP Hotkey Support driver. Can cause slow shutdown.
    "HPDiagsCap" # HP Diagnostics HSA Service - HSA capability that exposes hardware/software diagnostic routines to HP apps (HP PC Hardware Diagnostics, HP Support Assistant). Runs DiagsCap.exe from DriverStore.
    "HPNetworkCap" # HP Network HSA Service - HSA capability that connects to HP cloud for device registration, consent sync, and network resource management. Runs NetworkCap.exe from DriverStore. Not required for normal networking.
    "hpsvcsscan" # HP Services Scan - Lightweight virtual driver that queries HP Insights Cloud for service entitlements (HP Premium+ Support, HP Smart Support) and auto-downloads entitled software. Delivered via Windows Update on HP platforms.
    "HPSysInfoCap" # HP System Info HSA Service - HSA capability that reads WMI classes, BIOS tables, serial number, motherboard ID, battery PCM info, and registry keys for HP apps. Can freeze system under heavy WMI load.
    "HpTouchpointAnalyticsService" # HP Touchpoint Analytics / HP Insights Analytics - Background telemetry service that collects device health, performance, and config data and submits it to HP. Silently installed via Windows Update. Data shared only with opt-in but service runs regardless.
    "LanWlanWwanSwitchingServiceUWP" # HP LAN/WLAN/WWAN Switching UWP Service - Auto-disables WLAN/WWAN adapters when wired LAN is detected to save battery. Controlled by BIOS setting on HP business notebooks. Part of HP Hotkey Support. Can interfere with VPN connections.
    "SFUService" # HP SFU (Storage Firmware Update) Service - Manages NVMe/SSD firmware updates on HP systems via the Windows SFU driver framework. Runs from C:\Windows\Firmware\HpSfuService.exe. Only needed during firmware update cycles.
    "ibtsiva" # Intel Wireless Bluetooth Service - Manages Bluetooth connections for Intel wireless devices.
    "igccservice" # Intel Graphics Command Center Service - Manages settings and features for Intel graphics.
    "IntelGraphicsSoftwareService" # Intel Graphics Software Service - Background service for Intel graphics driver features and telemetry.
    "igfxCUIService*" # Intel HD Graphics Control Panel Service - Manages settings for Intel HD Graphics.
    "Intel(R) Platform License Manager Service" # Intel Platform License Manager Service - Manages licenses for Intel software.
    "Intel(R) TPM Provisioning Service" # Intel TPM Provisioning Service - Manages Trusted Platform Module (TPM) provisioning.
    "IntelArcControlService" # Intel Arc Control Service - Manages backend features for Intel Arc Control.
    "IntelAudioService" # Intel Audio Service - Manages Intel audio settings and functionality.
    "IntelVrocOobAgent" # Intel VROC OOB Agent - Manages out-of-band features for Intel Virtual RAID on CPU.
    "IntuneManagementExtension" # Microsoft Intune Management Extension - Manages Intune operations and device compliance.
    "ipfsvc" # Intel Innovation Platform Framework Service - Supports Intel innovation platform features.
    "jhi_service" # Intel Dynamic Application Loader Host Interface Service - Allows applications to access Intel Dynamic Application Loader.
    "LanmanServer" # Server Service (SMB server) - Provides file, print, and named-pipe sharing over the network. Default: Manual+stopped. Use -server:$true for Auto or -DisableServer to disable. See also: LanmanWorkstation in $workstation_services.
    "lfsvc" # Geolocation Service - Manages location data for applications and services.
    "LightingService" # ASUS AURA SYNC Lighting Service - Manages lighting settings for ASUS devices.
    "lmhosts" # TCP/IP NetBIOS Helper - Provides support for NetBIOS over TCP/IP (NetBT) service and NetBIOS name resolution.
    "LMS" # Intel Local Management Service - Provides OS-related functionality for Intel Management Engine.
    "ManyCam Service" # ManyCam Service - Manages settings and features for ManyCam software.
    "MapsBroker" # Downloaded Maps Manager - Manages downloaded maps for Windows applications.
    "MSDTC" # Distributed Transaction Coordinator - Coordinates distributed transactions for applications and services. Required for Volume Shadow Copy service.
    "ndu" # Network Data Usage Monitor - Monitors network data usage.
    "NetTcpPortSharing" # Net.Tcp Port Sharing Service - Allows multiple applications to share TCP ports over the network.
    "NPSMSvc_*" # Network Policy Server Management Service - Manages network policy and access services.
    "nscp" # NSClient++ Service - Monitoring agent for Nagios and other systems.
    "NvContainerLocalSystem" # NVIDIA Local System Container - Manages NVIDIA root features.
    "NVDisplay.ContainerLocalSystem" # NVIDIA Display Container Local System - Manages NVIDIA display settings.
    "NVIDIA Share" # NVIDIA Share Service - Manages NVIDIA Share features for game streaming and recording.
    "NVWMI" # NVIDIA WMI Provider Service - Provides WMI management features for NVIDIA graphics.
    "OneSyncSvc" # Sync Host Service - Manages data synchronization for mail, contacts, calendar, and other user data.
    "OneSyncSvc_*" # Sync Host Service - Manages data synchronization for mail, contacts, calendar, and other user data for specific user sessions.
    "OpenVPNServiceInteractive" # OpenVPN Interactive Service - Allows OpenVPN GUI to establish connections without administrative privileges.
    "ovpnhelper_service" # OpenVPN Connect Helper Service - Assists in managing OpenVPN connections.
    "PcaSvc" # Program Compatibility Assistant Service - Detects and mitigates compatibility issues for older programs.
    "PCNS1" # PowerChute Network Shutdown - Provides network-based shutdown for multiple servers.
    "PlugPlay" # Plug and Play Service - Manages hardware changes with little or no user input. Disabling this service will result in system instability.
    "Power" # Power Service - Manages power policy and delivery.
    "RasMan" # Remote Access Connection Manager - Manages dial-up and VPN connections.
    "Razer Chroma SDK Server" # Razer Chroma SDK Server - Provides web interface for Razer Chroma SDK.
    "Razer Chroma SDK Service" # Razer Chroma SDK Service - Provides access to Razer hardware for applications using Razer SDK.
    "Razer Chroma Stream Server" # Razer Chroma Stream Server - Provides access to the Razer Stream API.
    "Razer Game Manager Service 3" # Razer Game Manager Service 3 - Manages games installed on the system for Razer software.
    "Razer Game Manager Service" # Razer Game Manager Service - Manages games installed on the system for Razer software.
    "Razer Synapse Service" # Razer Synapse Service - Manages settings and features for Razer devices.
    "RmSvc" # Radio Management Service - Manages radio and airplane mode settings.
    "RstMwService" # Intel Storage Middleware Service - Provides communication between driver and Windows Store applications.
    "RtkAudioUniversalService" # Realtek Audio Universal Service - Manages settings for Realtek audio.
    "RtkBtManServ" # Realtek Bluetooth Device Manager Service - Manages Bluetooth settings for Realtek devices.
    "RzActionSvc" # Razer Central Service - Manages central settings for Razer software.
    "SAService" # Conexant SmartAudio Service - Manages settings for Conexant SmartAudio.
    "SCardSvr" # Smart Card Service - Manages access to smart cards. If stopped, this computer will be unable to read smart cards.
    "ScDeviceEnum" # Smart Card Device Enumeration Service - Creates software device nodes for all smart card readers accessible to a given session. If disabled, WinRT APIs will not be able to enumerate smart card readers.
    "SCPolicySvc" # Smart Card Removal Policy Service - Configures the system to lock the user desktop upon smart card removal.
    "SecurityHealthService" # Windows Security Service - Handles unified device protection and health information for Windows.
    "SENS" # System Event Notification Service - Monitors system events and notifies subscribers of these events.
    "SQLWriter" # SQL Server VSS Writer - Provides the interface to backup/restore Microsoft SQL Server through the Windows VSS infrastructure.
    "SSDPSRV" # SSDP Discovery - Discovers networked devices and services using the SSDP discovery protocol (e.g., UPnP devices). Also announces SSDP devices and services running on the local computer.
    "ssh-agent" # OpenSSH Authentication Agent - Manages SSH keys for authentication.
    "sshd" # SSH Daemon - Provides SSH remote access and management capabilities.
    "StateRepository" # State Repository Service - Provides infrastructure support for the application model and state management.
    "StorSvc" # Storage Service - Manages storage settings and features, including Storage Spaces and storage pools.
    "stunnel" # Stunnel TLS Wrapper - Provides TLS offloading and load-balancing proxy functionalities.
    "SupportAssistAgent" # Dell SupportAssist Agent - Keeps your PC up to date with recommended software and driver updates. Detects and resolves issues by sending details to Dell Technical Support agents.
    "swprv" # Microsoft Software Shadow Copy Provider - Manages software-based volume shadow copies taken by the Volume Shadow Copy service. Disabling this service will prevent software-based volume shadow copies from being managed.
    # "TabletInputService" -- removed; related to TextInputManagementService, required for Start menu type-to-search and PIN entry
    "TbtHostControllerService" # Thunderbolt Host Controller Service - Manages Thunderbolt connections and settings.
    # "TextInputManagementService" -- moved to $stop_services; required for PIN entry on lock screen
    "Themes" # Themes Service - Provides user experience theme management.
    "TrkWks" # Distributed Link Tracking Client - Maintains links to files on NTFS volumes within a network domain.
    "UdkUserSvc" # Universal Driver Kit User Service - Manages user-specific settings for Universal Driver Kit.
    "UdkUserSvc_*" # Universal Driver Kit User Service - Manages user-specific settings for Universal Driver Kit for specific user sessions.
    "UnistoreSvc_*" # User Data Storage Service - Handles storage of structured user data (contacts, calendars, messages, etc.). Disabling this service may affect apps using this data.
    "UserDataSvc_*" # User Data Access Service - Provides apps access to structured user data (contacts, calendars, messages, etc.). Disabling this service may affect apps using this data.
    "UsoSvc" # Update Orchestrator Service - Manages Windows Updates. Disabling this service will prevent the downloading and installation of updates.
    "VMAuthdService" # VMware Authorization Service - Manages permissions and authorization for VMware applications.
    "vmms" # Hyper-V Virtual Machine Management - Manages Hyper-V virtual machines and related services.
    "VMnetDHCP" # VMware DHCP Service - Provides DHCP services for VMware virtual networks.
    "VMUSBArbService" # VMware USB Arbitration Service - Manages USB device connections for VMware virtual machines.
    "VMware NAT Service" # VMware NAT Service - Provides network address translation (NAT) for VMware virtual networks.
    "VMwareHostd" # VMware Host Agent - Manages VMware ESXi hosts and their resources.
    # "WaaSMedicSvc" -- moved to $windowsupdate_services; required for Windows Update
    # "WbioSrvc" -- moved to $stop_services; required for Windows Hello PIN and biometric login
    "WPDBusEnum" # Portable Device Enumerator Service - Enforces group policy for removable mass-storage devices and enables applications to transfer and synchronize content using MTP.
    "Wcmsvc" # Windows Connection Manager - Manages network connectivity and makes automatic connect/disconnect decisions based on available options.
    "webthreatdefsvc" # Web Threat Defense Service - Protects against web-based threats and unauthorized access.
    "webthreatdefusersvc" # Web Threat Defense User Service - Helps protect against unauthorized access to user credentials.
    "webthreatdefusersvc_*" # Web Threat Defense User Service - Helps protect against unauthorized access to user credentials for specific user sessions.
    "Winmgmt" # Windows Management Instrumentation (WMI) - Provides a common interface and object model to access management information about the operating system, devices, applications, and services.
    "WlanSvc" # WLAN AutoConfig Service - Manages wireless network connections.
    "WMIRegistrationService" # Intel Management Engine WMI Provider Registration Service - Registers WMI providers for Intel Management Engine.
    "WMPNetworkSvc" # Windows Media Player Network Sharing Service - Shares Windows Media Player libraries over the network.
    "WpnService" # Windows Push Notifications Service - Manages push notifications for Windows apps.
    "WpnUserService_*" # Windows Push Notifications User Service - Manages push notifications for specific user sessions.
    "wscsvc" # Windows Security Center Service - Monitors and reports security health settings for the system.
    # "WSearch" -- removed; required for Start menu type-to-search functionality
    "wuauserv" # Windows Update Service - Manages detection, download, and installation of updates for Windows and other programs.
    "XblAuthManager" # Xbox Live Auth Manager - Manages authentication for Xbox Live services.
    "XblGameSave" # Xbox Live Game Save Service - Manages game save data for Xbox Live.
    "XboxGipSvc" # Xbox Accessory Management Service - Manages Xbox accessories and their settings.
)


$workstation_services = @(
    # Controlled by -workstation flag. $True = Automatic + started; $False (CMD default) = Manual + stopped.
    # -DisableWorkstation overrides this flag and sets to Disabled + stopped.
    # LanmanServer (Server) is separate: controlled by -server and -DisableServer flags.
    "LanmanWorkstation" # Workstation (SMB client) - Provides SMB client access for mapped drives, UNC paths, and domain resources. If disabled, other services (e.g. Netlogon, Browser) will log errors.
)

$broker_services = @(
    "BrokerInfrastructure" # Background Tasks Infrastructure Service - Controls which background tasks can run on the system.
    "SysMain" # SysMain (formerly Superfetch) - Improves system performance by preloading frequently used applications into RAM. It analyzes usage patterns and preloads applications to reduce load times and improve overall performance. Can cause high CPU or disk usage; disable if it causes performance issues.
    # "TokenBroker" -- moved to $stop_services; required for Windows Hello PIN login
)

$windowsupdate_services = @(
    # Controlled by -DisableWindowsUpdate switch. Default: Manual + stopped (not disabled).
    # -DisableWindowsUpdate overrides this and sets to Disabled + stopped.
    # On Windows 11 24H2+, DoSvc (Delivery Optimization) is the primary download engine for
    # both Windows Update and Microsoft Store. Disabling it causes error 0x80004002.
    "BITS" # Background Intelligent Transfer Service - Transfers files in the background using idle network bandwidth. Required for Windows Update.
    "DoSvc" # Delivery Optimization - Download engine for Windows Update and Store on Windows 11 24H2+. Listens on port 7680 TCP for P2P (optional). Disabling breaks all update downloads.
    "UsoSvc" # Update Orchestrator Service - Manages Windows Updates. Coordinates scan, download, and install of updates.
    "WaaSMedicSvc" # Windows Update Medic Service - Enables remediation and protection of Windows Update components.
    "wuauserv" # Windows Update Service - Manages detection, download, and installation of updates for Windows and other programs.
)

$audio_services = @(
    "AudioEndpointBuilder" # Windows Audio Endpoint Builder - Manages audio devices for the Windows Audio service. If stopped, audio devices and effects won't function properly. Dependent services will fail to start if disabled.
    "Audiosrv" # Windows Audio - Manages audio for Windows-based programs. If stopped, audio devices and effects won't function properly. Dependent services will fail to start if disabled.
    "Focusrite Control Server" # Focusrite Control Server - Manages Focusrite audio interface settings and routing.
    "ShellHWDetection" # Shell Hardware Detection - Provides notifications for AutoPlay hardware events.
    "FMAPOService" # Fortemedia APO Control Service (Audio Processing Object  / Realtek Audio driver)
)

$print_services = @(
    "Canon Driver Information Assist Service" # Canon Driver Information Assist Service - Provides driver information for Canon printers.
    "LPDSVC" # LPD Service - Enables client computers to print to the Line Printer Daemon (LPD) service on this server using TCP/IP and the Line Printer Remote (LPR) protocol.
    "StiSvc" # Windows Image Acquisition (WIA) - Provides image acquisition services for scanners and cameras.
    "SshWiaRestart" # ScanSnap Home WIA Restart Service - ScanSnap Home WIA Control for Fujitsu ScanSnap scanners.
    "DeviceInstall" # Device Install Service - Enables a computer to recognize and adapt to hardware changes with little or no user input. Stopping or disabling this service will result in system instability.
    "DmEnrollmentSvc" # Device Management Enrollment Service - Performs Device Enrollment Activities for Device Management.
    "Net Driver HPZ*" # HP Network Printer Driver - Used by HP printers.
    "Pml Driver HPZ*" # HP PML Driver - Used by HP printers.
    "PrintDeviceConfigurationService" # Print Device Configuration Service - Configures print devices.
    "PrintNotify" # Printer Extensions and Notifications - Opens custom printer dialog boxes and handles notifications from a remote print server or a printer. If disabled, printer extensions or notifications won't be visible.
    "PrintScanBrokerService" # Print Scan Broker Service - Provides support for secure privileged operations needed by low privilege spooler.
    "PrintWorkflow_*" # Print Workflow - Provides support for Print Workflow applications. Disabling this service might prevent successful printing.
    "PrintWorkflowUserSvc" # Print Workflow User Service - Provides support for Print Workflow applications.
    "PrintWorkflowUserSvc_*" # Print Workflow User Service - Provides support for Print Workflow applications. Disabling this service might prevent successful printing.
    "Spooler" # Print Spooler - Spools print jobs and handles interaction with the printer. If stopped, printing and printer visibility will not be possible.
)

$disable_services = @(
    # "DoSvc" -- moved to $windowsupdate_services; required for Windows Update on Windows 11 24H2+
    "CDPSvc" # Connected Devices Platform Service - Used for Connected Devices Platform scenarios. Listens on port 5040 TCP.
    "CDPUserSvc_*" # Connected Devices Platform User Service - Additional service for CDPSvc used for Connected Devices Platform scenarios.
    "tvnserver" # TightVNC Server - Allows remote access to the desktop.
    "RemoteAccess" # Routing and Remote Access - Provides routing and remote access services.
    "RemoteRegistry" # Remote Registry - Enables remote users to modify registry settings on the machine.
    "SharedAccess" # Internet Connection Sharing (ICS) - Provides Network Address Translation (NAT), addressing, name resolution and/or intrusion prevention services for a home or small office network.
    "SystemUsageReportSvc_QUEENCREEK" # System Usage Report Service - This service generates a lot of page faults.
    "WinRM" # Windows Remote Management (WS-Management) - Implements the WS-Management protocol for remote management. Provides access to WMI data and enables event collection. Uses HTTP and HTTPS as transports. Needs to be configured with a listener.
)

$stop_services = @(
    "XboxNetApiSvc" # Xbox Live Networking Service - Manages network connectivity for Xbox Live features.
    "BrokerInfrastructure" # Background Tasks Infrastructure Service - Controls which background tasks can run on the system.
    "bthserv" # Bluetooth Support Service - Supports discovery and association of remote Bluetooth devices. Stopping or disabling this service may cause installed Bluetooth devices to fail to operate properly.
    "camsvc" # Capability Access Manager Service - Manages UWP apps' access to app capabilities and checks app capability access.
    "cbdhsvc_*" # Clipboard User Service - Manages clipboard operations for user scenarios.
    "CDPSvc" # Connected Devices Platform Service - Manages connected device scenarios.
    "CertPropSvc" # Certificate Propagation - Copies user and root certificates from smart cards into the user's certificate store, detects smart card insertion, and installs the smart card Plug and Play minidriver if needed.
    "ClickToRunSvc" # Microsoft Office Click-to-Run Service - Manages updates and installations for Microsoft Office.
    "ClipSVC" # Client License Service (ClipSVC) - Provides infrastructure support for the Microsoft Store. Disabling this service may cause applications bought from the Store to malfunction.
    "cloudidsvc" # Microsoft Cloud Identity Service - Supports integrations with Microsoft cloud identity services. Required for Windows Hello PIN login with Microsoft accounts.
    "ConsentUxUser" # Consent User Service - Manages consent for user actions.
    "ConsentUxUserSvc_*" # Consent User Service - Manages consent for user actions for specific user sessions.
    "cplspcon" # Intel Content Protection HDCP Service - Enables communication with Content Protection HDCP hardware.
    "dcsvc" # Declared Configuration Service - Manages declared configurations for applications and services.
    "DisplayEnhancementService" # Display Enhancement Service - Manages display enhancements such as brightness control.
    "DSAUpdateService" # Intel Driver & Support Assistant Updater - Keeps Intel Driver & Support Assistant up to date.
    "DsmSvc" # Device Setup Manager - Enables detection, download, and installation of device-related software. Disabling this service may cause devices to use outdated software and malfunction.
    "fdPHost" # Function Discovery Provider Host - Hosts Function Discovery network discovery providers for SSDP and WS-D protocols. Stopping or disabling this service will disable network discovery.
    "FDResPub" # Function Discovery Resource Publication - Publishes this computer and its resources over the network. Stopping this service will prevent network resources from being discovered.
    "GamingServices" # Gaming Services - Manages gaming-related services and features.
    "igfxCUIService*" # Intel HD Graphics Control Panel Service - Manages settings and features for Intel HD Graphics.
    "InstallService" # Microsoft Store Install Service - Provides infrastructure support for the Microsoft Store. Disabling this service may cause installations to malfunction.
    "Intel(R) Capability Licensing Service TCP IP Interface" # Intel Capability Licensing Service - Manages TCP/IP licensing for Intel features.
    "InventorySvc" # Inventory and Compatibility Appraisal Service - Performs system inventory, compatibility appraisal, and maintenance for system components.
    "NPSMSvc_*" # Network Policy Server Management Service - Manages network policy and access services.
    "nvagent" # Network Virtualization Service - Provides network virtualization services.
    "PhoneSvc" # Phone Service - Manages phone-related services and features.
    "PimIndexMaintenanceSvc" # Personal Information Manager Index Maintenance Service - Manages indexing for personal information data.
    "PimIndexMaintenanceSvc_*" # Personal Information Manager Index Maintenance Service - Manages indexing for personal information data for specific user sessions.
    "RmSvc" # Radio Management Service - Manages radio and airplane mode settings.
    "sacsvr" # Special Administration Console Helper - Allows administrators to remotely access a command prompt using Emergency Management Services.
    "StorSvc" # Storage Service - Manages storage settings and external storage expansion.
    # "TextInputManagementService" -- removed; required for PIN entry on lock screen and Start menu type-to-search
    "TimeBrokerSvc" # Time Broker Service - Coordinates execution of background work for WinRT applications. Disabling this service may prevent background work from being triggered.
    "TokenBroker" # Token Broker - Manages tokens for application authentication. Required for Windows Hello PIN login.
    "UdkUserSvc_*" # Universal Driver Kit User Service - Manages settings for Universal Driver Kit for specific user sessions.
    "UnistoreSvc_*" # User Data Storage Service - Handles storage of structured user data (contacts, calendars, messages, etc.). Disabling this service may affect apps that use this data.
    "UserDataSvc_*" # User Data Access Service - Provides apps access to structured user data (contacts, calendars, messages, etc.). Disabling this service may affect apps that use this data.
    # "UsoSvc" -- moved to $windowsupdate_services; required for Windows Update
    "vmcompute" # Hyper-V Host Compute Service - Provides support for running Windows Containers and Virtual Machines.
    # "WaaSMedicSvc" -- moved to $windowsupdate_services; required for Windows Update
    "WinHttpAutoProxySvc" # WinHTTP Web Proxy Auto-Discovery Service - Implements the client HTTP stack and provides support for auto-discovering a proxy configuration via the Web Proxy Auto-Discovery (WPAD) protocol.
    "Winmgmt" # Windows Management Instrumentation (WMI) - Provides a common interface and object model to access management information about the operating system, devices, applications, and services.
    "WbioSrvc" # Windows Biometric Service - Manages biometric devices. Required for Windows Hello PIN and biometric login.
    "WpnUserService_*" # Windows Push Notifications User Service - Manages push notifications for specific user sessions. Supports tile, toast, and raw notifications.
    # "wuauserv" -- moved to $windowsupdate_services; required for Windows Update
    # HP services
    "HotKeyServiceUWP" # HP Hotkey UWP Service - Handles Fn+F1-F12 hotkey combos for brightness, volume, wireless toggle on HP laptops. Known high CPU/memory on Win11.
    "HPAppHelperCap" # HP App Helper HSA Service - HSA capability broker: launches interdependent HP apps, suspends/resumes devices, enables presence-aware sensors.
    "HPAudioAnalytics" # HP Audio Analytics Service - Collects audio performance telemetry (mic, speaker, conferencing) and reports to HP cloud. Can cause slow shutdown.
    "HPDiagsCap" # HP Diagnostics HSA Service - Exposes hardware/software diagnostic routines to HP Support Assistant and HP PC Hardware Diagnostics.
    "HPNetworkCap" # HP Network HSA Service - Connects to HP cloud for device registration, consent sync, and network resource management. Not needed for normal networking.
    "hpsvcsscan" # HP Services Scan - Queries HP Insights Cloud for service entitlements (Premium+ Support, Smart Support) and auto-downloads entitled software.
    "HPSysInfoCap" # HP System Info HSA Service - Reads WMI classes, BIOS tables, serial number, motherboard ID, battery PCM, and registry for HP apps. Can freeze system under heavy WMI load.
    "HpTouchpointAnalyticsService" # HP Touchpoint Analytics / HP Insights Analytics - Background telemetry: collects device health, performance, config data, submits to HP. Silently installed via Windows Update.
    "LanWlanWwanSwitchingServiceUWP" # HP LAN/WLAN/WWAN Switching UWP Service - Auto-disables WLAN/WWAN when wired LAN detected. BIOS-controlled on business notebooks. Can interfere with VPN.
    "SFUService" # HP SFU (Storage Firmware Update) Service - Manages NVMe/SSD firmware updates via Windows SFU driver framework. Only needed during firmware update cycles.
)

$start_services = @(
    "DeviceAssociationService" # Device Association Service - Manages pairing between the system and wired or wireless devices.
    "SecurityHealthService" # Windows Security Service - Handles unified device protection and health information.
    "WlanSvc" # WLAN AutoConfig Service - Manages wireless network connections.
)

$never_manage_services = @(
    "SystemEventsBroker" # Keep untouched: no startup-type changes and no stop/start attempts.
)

$start_search_services = @(
    "WSearch" # Windows Search - backend for Start menu type-to-search.
    "TextInputManagementService" # Text input routing for Start menu search box.
    "TabletInputService" # Legacy text input service used on some Windows builds.
    "WpnService" # Push notifications channel used by Start UI state updates.
    "WpnUserService_*" # Per-user push notifications channel used by Start UI state updates.
)

$start_search_auto_services = @(
    "WSearch" # Windows Search - backend for Start menu type-to-search.
    "WpnService" # Push notifications channel used by Start UI state updates.
    "WpnUserService_*" # Per-user push notifications channel used by Start UI state updates.
)

$start_search_start_only_services = @(
    "TextInputManagementService" # Startup behavior is OS-managed on many builds; ensure running only.
    "TabletInputService" # Not present on all builds; start only when available.
)

$start_search_stability_services = @(
    "BrokerInfrastructure" # Background task broker used by Start and Search host flow.
    "StateRepository" # Maintains shell/app model state used by Start interactions.
    "SystemEventsBroker" # Coordinates background events consumed by modern shell/UWP components.
    "AppXSVC" # App model deployment/runtime glue used by Start app activation.
    "ClipSVC" # Client licensing service used by Microsoft Store-backed app activation.
    "ShellHWDetection" # Shell event routing that can impact focus/input behavior.
    "TimeBrokerSvc" # Background work coordinator for WinRT tasks.
    "UserDataSvc_*" # Per-user data access service used by modern shell surfaces.
    "UnistoreSvc_*" # Per-user data storage service paired with UserDataSvc.
    "ConsentUxUserSvc_*" # Per-user consent UX host that can influence shell prompts/focus.
    "camsvc" # Capability broker used by modern app capability checks.
    "cbdhsvc_*" # Per-user clipboard service used by modern UX surfaces.
    "WSearch" # Keep aligned with Start/Search dependency set.
    "TextInputManagementService" # Keep aligned with Start/Search dependency set.
    "TabletInputService" # Keep aligned with Start/Search dependency set.
    "WpnService" # Keep aligned with Start/Search dependency set.
    "WpnUserService_*" # Keep aligned with Start/Search dependency set.
)

function Set-ServiceStartupType {
    [CmdletBinding(SupportsShouldProcess)]
    param (
        [string]$serviceName,
        [string]$startupType
    )

    if ([string]::IsNullOrWhiteSpace($serviceName)) {
        Write-Log "Invalid service name provided (empty or null)" "Warning"
        return "Failed"
    }

    if ($startupType -notin @("Automatic", "Manual", "Disabled")) {
        Write-Log "Invalid startup type '$startupType' for service '$serviceName'" "Warning"
        return "Failed"
    }

    try {
        # Handle wildcard service names
        if ($serviceName.Contains("*")) {
            $services = Get-Service -Name $serviceName -ErrorAction SilentlyContinue
            if ($services) {
                $serviceCount = 0
                foreach ($service in $services) {
                    $result = Set-ServiceStartupType -serviceName $service.Name -startupType $startupType
                    if ($result -eq "Success") {
                        $serviceCount++
                    }
                }
                Write-Log "Processed $serviceCount services matching pattern '$serviceName'" "Info"
                if ($serviceCount -gt 0) { return "Success" } else { return "Skipped" }
            }
            else {
                Write-Log "No services found matching pattern '$serviceName'" "Verbose"
                return "Skipped"
            }
        }

        # Protection for services required by Start menu type-to-search and Windows Hello PIN
        $protectedFromChange = @(
            "BrokerInfrastructure" # Background Tasks Infrastructure Service - required for modern shell components including Start and SearchHost
            "SystemEventsBroker" # System Events Broker - keep OS-managed to preserve shell/UWP event flow
            "StateRepository" # State Repository Service - maintains Start menu and Shell state; keyboard focus logic breaks without it
            "AppXSVC" # AppX Deployment Service - needed for Start menu app model integration
            "ClipSVC" # Client License Service - required for Start menu app activation and focus handling
            "ShellHWDetection" # Shell Hardware Detection - participates in shell event routing; disabling breaks Start input focus
            "TokenBroker" # Token Broker - manages authentication tokens; required for Windows Hello PIN login
            "WbioSrvc" # Windows Biometric Service - required for Windows Hello PIN and biometric login
            "cloudidsvc" # Microsoft Cloud Identity Service - required for Windows Hello PIN with Microsoft accounts
        )

        if (Test-IsManagedStartupService -ServiceName $serviceName) {
            Write-Log "Service $serviceName uses OS-managed startup behavior. Skipping startup type change." "Verbose"
            return "Skipped"
        }

        $isProtectedFromChange = ($serviceName -in $protectedFromChange)
        $isStartSearchService = Test-IsStartSearchService -ServiceName $serviceName
        $isStartSearchDowngrade = $startsearch -and $isStartSearchService -and ($startupType -ne "Automatic")
        if ($isStartSearchDowngrade -or $isProtectedFromChange) {
            Write-Log "Protecting service $serviceName from startup type change (required for Start menu search or PIN login). Skipping." "Verbose"
            return "Skipped"
        }

        $serviceHandle = Get-Service -Name $serviceName -ErrorAction SilentlyContinue
        if ($null -eq $serviceHandle) {
            Write-Log "Service $serviceName does not exist. Skipping." "Verbose"
            return "Skipped"
        }

        $currentStartupType = Get-ServiceStartupTypeSafe -ServiceName $serviceHandle.Name
        if ($currentStartupType -eq $startupType) {
            Write-Log "Service $($serviceHandle.Name) already has startup type '$startupType'. Skipping." "Verbose"
            return "Skipped"
        }

        if ($psCmdlet.ShouldProcess("Service: $($serviceHandle.Name) ($serviceName)", "Set startup type from $currentStartupType to $startupType")) {
            Write-Log "Changing startup type from $currentStartupType to $startupType for service $($serviceHandle.Name) ($serviceName)..." "Verbose"
            Set-Service -Name $serviceHandle.Name -StartupType $startupType -ErrorAction Stop
            Write-Log "$($serviceHandle.Name) startup type changed from $currentStartupType to $startupType." "Info"
            return "Success"
        }
        return "Success" # WhatIf mode
    }
    catch {
        $msg = $_.Exception.Message
        if ($msg -like "*Access is denied*" -or $msg -like "*PermissionDenied*") {
            if (Test-IsKnownProtectedInputService -ServiceName $serviceName) {
                Write-Log "Startup type change denied for protected/input service $serviceName. Treating as skipped." "Warning"
                return "Skipped"
            }

            Write-Log "Permission denied for $serviceName. Attempting with 'sc' command." "Warning"
            try {
                if ($psCmdlet.ShouldProcess("Service: $serviceName (via sc.exe)", "Set startup type from $currentStartupType to $startupType")) {
                    $scArgs = switch ($startupType) {
                        "Automatic" { @("config", $serviceName, "start=", "auto") }
                        "Manual" { @("config", $serviceName, "start=", "demand") }
                        "Disabled" { @("config", $serviceName, "start=", "disabled") }
                    }

                    $result = & sc.exe @scArgs 2>&1
                    if ($LASTEXITCODE -eq 0) {
                        Write-Log "Successfully changed $serviceName startup type from $currentStartupType to $startupType using sc command" "Info"
                        return "Success"
                    }
                    else {
                        $registryResult = Set-ServiceStartupTypeRegistryFallback -ServiceName $serviceName -StartupType $startupType
                        if ($registryResult -eq "Success" -or $registryResult -eq "Skipped") {
                            return $registryResult
                        }

                        if (Test-IsKnownProtectedInputService -ServiceName $serviceName) {
                            Write-Log "sc denied startup type change for protected/input service $serviceName. Treating as skipped." "Warning"
                            return "Skipped"
                        }

                        Write-Log "sc command failed for $serviceName`: $result" "Error"
                        return "Failed"
                    }
                }
                return "Success" # WhatIf mode
            }
            catch {
                $registryResult = Set-ServiceStartupTypeRegistryFallback -ServiceName $serviceName -StartupType $startupType
                if ($registryResult -eq "Success" -or $registryResult -eq "Skipped") {
                    return $registryResult
                }

                Write-Log "sc command also failed for $serviceName`: $($_.Exception.Message)" "Error"
                return "Failed"
            }
        }
        elseif ($msg -like "*The parameter is incorrect*" -or $msg -like "*cannot be configured*") {
            # Often happens with per-user services like AarSvc or BcastDVRUserService
            Write-Log "Service $serviceName exists but cannot be configured (per-user service). Skipping." "Verbose"
            return "Skipped"
        }
        else {
            Write-Log "Failed to handle $serviceName`: $msg" "Error"
            return "Failed"
        }
    }
}

function Invoke-ServiceManagement {
    [CmdletBinding(SupportsShouldProcess)]
    param (
        [string]$serviceName,
        [string]$action
    )

    if ([string]::IsNullOrWhiteSpace($serviceName)) {
        Write-Log "Invalid service name provided (empty or null)" "Warning"
        return "Failed"
    }

    if ($action -notin @("Start", "Stop")) {
        Write-Log "Invalid action '$action' for service '$serviceName'. Must be 'Start' or 'Stop'" "Warning"
        return "Failed"
    }

    # Protection for critical system services (never stopped)
    $protectedServices = @(
        "Dhcp" # DHCP Client - registers and updates IP addresses and DNS records
        "Power" # Power Service - manages power policy and delivery
        "PlugPlay" # Plug and Play - manages hardware changes; disabling causes system instability
        "BrokerInfrastructure" # Background Tasks Infrastructure Service - required for Start menu and SearchHost
        "SystemEventsBroker" # System Events Broker - coordinates background tasks for Store and UWP apps
        "StateRepository" # State Repository Service - maintains Start menu and Shell state
        "SecurityHealthService" # Windows Security Service - unified device protection and health
        # "WaaSMedicSvc" -- moved to $windowsupdate_services; stoppable by default
        "wscsvc" # Windows Security Center Service - monitors security health settings
        "AppXSVC" # AppX Deployment Service - needed for Start menu app model integration
        "WinHttpAutoProxySvc" # WinHTTP Web Proxy Auto-Discovery Service - client HTTP stack
        "Schedule" # Task Scheduler - enables task scheduling
        "RpcSs" # Remote Procedure Call - endpoint mapper and COM service control manager
        "DcomLaunch" # DCOM Server Process Launcher - launches COM and DCOM servers
        "ProfSvc" # User Profile Service - loads and unloads user profiles
        "LSM" # Local Session Manager - manages logon sessions
        "SamSs" # Security Accounts Manager - stores security information for local accounts
        "ClipSVC" # Client License Service - required for Start menu app activation and focus handling
        "ShellHWDetection" # Shell Hardware Detection - shell event routing; disabling breaks Start input focus
        "TokenBroker" # Token Broker - manages authentication tokens; required for Windows Hello PIN login
        "WbioSrvc" # Windows Biometric Service - required for Windows Hello PIN and biometric login
        "cloudidsvc" # Microsoft Cloud Identity Service - required for Windows Hello PIN with Microsoft accounts
    )

    $isProtectedFromStop = ($serviceName -in $protectedServices)
    $isStartSearchService = Test-IsStartSearchService -ServiceName $serviceName
    if ($action -eq "Stop" -and (($startsearch -and $isStartSearchService) -or $isProtectedFromStop)) {
        Write-Log "Protecting critical service $serviceName from being stopped. Skipping." "Verbose"
        return "Skipped"
    }

    try {
        # Handle wildcard service names
        if ($serviceName.Contains("*")) {
            $services = Get-Service -Name $serviceName -ErrorAction SilentlyContinue
            if ($services) {
                $serviceCount = 0
                foreach ($service in $services) {
                    $result = Invoke-ServiceManagement -serviceName $service.Name -action $action
                    if ($result -eq "Success") {
                        $serviceCount++
                    }
                }
                Write-Log "Processed $serviceCount services matching pattern '$serviceName'" "Info"
                if ($serviceCount -gt 0) { return "Success" } else { return "Skipped" }
            }
            else {
                Write-Log "No services found matching pattern '$serviceName'" "Verbose"
                return "Skipped"
            }
        }

        $serviceHandle = Get-Service -Name $serviceName -ErrorAction SilentlyContinue
        if ($null -eq $serviceHandle) {
            Write-Log "Service $serviceName does not exist. Skipping." "Verbose"
            return "Skipped"
        }

        switch ($action) {
            "Start" {
                if ($serviceHandle.Status -eq "Stopped") {
                    if ($psCmdlet.ShouldProcess("Service: $($serviceHandle.Name)", "Start service")) {
                        Write-Log "Starting service $($serviceHandle.Name)..." "Verbose"
                        Start-Service -Name $serviceHandle.Name -ErrorAction Stop

                        # Wait a moment and verify the service started
                        Start-Sleep -Milliseconds 500
                        $updatedService = Get-Service -Name $serviceHandle.Name
                        if ($updatedService.Status -eq "Running") {
                            Write-Log "$($serviceHandle.Name) started successfully." "Info"
                            return "Success"
                        }
                        else {
                            Write-Log "$($serviceHandle.Name) start initiated but status is: $($updatedService.Status)" "Warning"
                            return "Failed"
                        }
                    }
                    return "Success" # WhatIf mode
                }
                else {
                    Write-Log "The service $($serviceHandle.Name) is already running. Skipping start." "Verbose"
                    return "Skipped"
                }
            }
            "Stop" {
                if ($serviceHandle.Status -eq "Running") {
                    if ($psCmdlet.ShouldProcess("Service: $($serviceHandle.Name)", "Stop service")) {
                        Write-Log "Stopping service $($serviceHandle.Name)..." "Verbose"
                        Stop-Service -Name $serviceHandle.Name -ErrorAction Stop -Force -NoWait
                        Write-Log "$($serviceHandle.Name) stop initiated." "Info"
                        return "Success"
                    }
                    return "Success" # WhatIf mode
                }
                else {
                    Write-Log "The service $($serviceHandle.Name) is not running." "Verbose"
                    return "Success"
                }
            }
        }
    }
    catch {
        $msg = $_.Exception.Message
        if ($msg -like "*Access is denied*" -or $msg -like "*PermissionDenied*") {
            if (Test-IsKnownProtectedInputService -ServiceName $serviceName) {
                Write-Log "Service action '$action' denied for protected/input service $serviceName. Treating as skipped." "Warning"
                return "Skipped"
            }

            Write-Log "Permission denied for $serviceName. Attempting with 'net' command." "Warning"
            try {
                if ($psCmdlet.ShouldProcess("Service: $serviceName (via net.exe)", "$action service")) {
                    $netArgs = switch ($action) {
                        "Start" { @("start", $serviceName) }
                        "Stop" { @("stop", $serviceName, "/y") }
                    }

                    $result = & net.exe @netArgs 2>&1
                    if ($LASTEXITCODE -eq 0) {
                        Write-Log "Successfully executed net command for $serviceName" "Info"
                        return "Success"
                    }
                    else {
                        Write-Log "net command failed for $serviceName`: $result" "Error"
                        return "Failed"
                    }
                }
                return "Success" # WhatIf mode
            }
            catch {
                Write-Log "net command also failed for $serviceName`: $($_.Exception.Message)" "Error"
                return "Failed"
            }
        }
        else {
            Write-Log "Failed to handle $serviceName`: $msg" "Error"
            return "Failed"
        }
    }
}

# Initialize counters for summary
$script:ProcessedServices = @{
    Auto     = 0
    Manual   = 0
    Disabled = 0
    Started  = 0
    Stopped  = 0
    Skipped  = 0
    Failed   = 0
}

function Invoke-ServiceProcess {
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [array]$ServiceList,
        [string]$Operation,
        [string]$StartupType = "",
        [string]$Action = ""
    )

    if ($ServiceList.Count -eq 0) {
        Write-Log "No services to process for operation: $Operation" "Verbose"
        return
    }

    Write-Log "Processing $($ServiceList.Count) services for operation: $Operation" "Info"

    $processedCount = 0
    foreach ($serviceName in $ServiceList) {
        $processedCount++
        Write-Progress -Activity "Processing Services" -Status "$Operation ($processedCount/$($ServiceList.Count))" -PercentComplete (($processedCount / $ServiceList.Count) * 100)

        $success = $true

        if ($StartupType -ne "") {
            $result = Set-ServiceStartupType -serviceName $serviceName -startupType $StartupType
            if ($result -eq "Success") {
                $script:ProcessedServices[$StartupType.Replace("Automatic", "Auto")]++
            }
            elseif ($result -eq "Skipped") {
                $script:ProcessedServices.Skipped++
                $success = $false # Don't try to manage if skipped
            }
            else {
                $script:ProcessedServices.Failed++
                $success = $false
            }
        }

        if ($Action -ne "" -and $success) {
            $result = Invoke-ServiceManagement -serviceName $serviceName -action $Action
            if ($result -eq "Success") {
                $script:ProcessedServices[$Action + "ed"]++
            }
            elseif ($result -eq "Skipped") {
                $script:ProcessedServices.Skipped++
            }
            else {
                $script:ProcessedServices.Failed++
            }
        }
    }

    Write-Progress -Activity "Processing Services" -Completed
}

if ($audio -eq $true) {
    Write-Log "Setting up audio services as automatic..." "Info"
    $auto_services += $audio_services
}
else {
    Write-Log "Setting up audio services as manual..." "Info"
    $manual_services += $audio_services
    $stop_services += $audio_services
}

if ($print -eq $true) {
    Write-Log "Setting up print services as automatic..." "Info"
    $auto_services += $print_services
}
else {
    Write-Log "Setting up print services as manual..." "Info"
    $manual_services += $print_services
    $stop_services += $print_services
}

# LanmanServer: -DisableServer > -server:$true (Auto) > -server:$false (Manual, default)
if ($DisableServer) {
    Write-Log "DisableServer: setting LanmanServer to Disabled and stopping it..." "Info"
    $manual_services = $manual_services | Where-Object { $_ -ne "LanmanServer" }
    $disable_services += @("LanmanServer")
}
elseif ($server -eq $true) {
    Write-Log "Setting up LanmanServer as Automatic and started..." "Info"
    $manual_services = $manual_services | Where-Object { $_ -ne "LanmanServer" }
    $auto_services += @("LanmanServer")
}
# else: LanmanServer stays in $manual_services (Manual + stopped) by default

# LanmanWorkstation: -DisableWorkstation > -workstation:$true (Auto) > -workstation:$false (Manual, default)
if ($DisableWorkstation) {
    Write-Log "DisableWorkstation: setting LanmanWorkstation to Disabled and stopping it..." "Info"
    $disable_services += @("LanmanWorkstation")
}
elseif ($workstation -eq $true) {
    Write-Log "Setting up LanmanWorkstation as Automatic and started..." "Info"
    $auto_services += $workstation_services
}
else {
    Write-Log "Setting up LanmanWorkstation as Manual and stopped..." "Info"
    $manual_services += $workstation_services
    $stop_services += $workstation_services
}

if ($brokers -eq $true) {
    Write-Log "Setting up broker services as automatic..." "Info"
    $auto_services += $broker_services
}
else {
    Write-Log "Setting up broker services as manual..." "Info"
    $manual_services += $broker_services
    $stop_services += $broker_services
}

# Windows Update services: -DisableWindowsUpdate > default (Manual + stopped)
if ($DisableWindowsUpdate) {
    Write-Log "DisableWindowsUpdate: setting Windows Update services to Disabled and stopping them. WARNING: This breaks Windows Update and Store downloads on Windows 11 24H2+." "Warning"
    $disable_services += $windowsupdate_services
}
else {
    Write-Log "Setting up Windows Update services as manual and stopped (not disabled)..." "Info"
    $manual_services += $windowsupdate_services
    $stop_services += $windowsupdate_services
}

if ($startsearch -eq $true) {
    Write-Log "Start/Search services are enabled. Restoring Start menu type-to-search dependencies." "Info"

    # Remove Start/Search and shell-stability patterns from down-level lists so later phases
    # do not introduce shell input/state desynchronization.
    $manual_services = Remove-ServicePatternsFromList -SourceList $manual_services -PatternsToRemove $start_search_services
    $disable_services = Remove-ServicePatternsFromList -SourceList $disable_services -PatternsToRemove $start_search_services
    $stop_services = Remove-ServicePatternsFromList -SourceList $stop_services -PatternsToRemove $start_search_services

    $manual_services = Remove-ServicePatternsFromList -SourceList $manual_services -PatternsToRemove $start_search_stability_services
    $disable_services = Remove-ServicePatternsFromList -SourceList $disable_services -PatternsToRemove $start_search_stability_services
    $stop_services = Remove-ServicePatternsFromList -SourceList $stop_services -PatternsToRemove $start_search_stability_services

    $auto_services += $start_search_auto_services
    $start_services += $start_search_start_only_services

    # Ensure core shell brokers are started, but do not force startup type changes here.
    $start_services += @(
        "BrokerInfrastructure",
        "StateRepository",
        "ShellHWDetection"
    )
}
else {
    Write-Log "Start/Search is disabled. Start menu type-to-search may stop working (Ctrl+Esc then typing)." "Warning"
    $manual_services += $start_search_services
    $stop_services += $start_search_services
}

# Remove services that should never be managed from all dynamic lists.
$auto_services = Remove-ServicePatternsFromList -SourceList $auto_services -PatternsToRemove $never_manage_services
$manual_services = Remove-ServicePatternsFromList -SourceList $manual_services -PatternsToRemove $never_manage_services
$disable_services = Remove-ServicePatternsFromList -SourceList $disable_services -PatternsToRemove $never_manage_services
$stop_services = Remove-ServicePatternsFromList -SourceList $stop_services -PatternsToRemove $never_manage_services
$start_services = Remove-ServicePatternsFromList -SourceList $start_services -PatternsToRemove $never_manage_services

if ($CheckStartSearchSafety) {
    # Audit mode is intentionally read-only and returns an explicit exit code for automation.
    $isSafe = Invoke-StartSearchSafetyCheck -AutoList $auto_services -ManualList $manual_services -DisableList $disable_services -StopList $stop_services -StartList $start_services
    Save-Log

    if ($pause) {
        Write-Log "=== Safety audit completed. Press any key to continue... ===" "Info"
        $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
    }

    if ($isSafe) {
        exit 0
    }
    else {
        exit 3
    }
}

# Process services with enhanced tracking
if ($NoBounce) {
    Write-Log "NoBounce mode enabled: skipping auto/manual stop-start transitions while still enforcing disabled services as stopped." "Info"
}

$autoAction = if ($NoBounce) { "" } else { "Start" }
$manualAction = if ($NoBounce) { "" } else { "Stop" }
$disabledAction = "Stop"

Invoke-ServiceProcess -ServiceList $auto_services -Operation "Automatic Services" -StartupType "Automatic" -Action $autoAction
Invoke-ServiceProcess -ServiceList $manual_services -Operation "Manual Services" -StartupType "Manual" -Action $manualAction
Invoke-ServiceProcess -ServiceList $disable_services -Operation "Disabled Services" -StartupType "Disabled" -Action $disabledAction

if (-not $NoBounce) {
    Invoke-ServiceProcess -ServiceList $stop_services -Operation "Services to Stop" -Action "Stop"
    Invoke-ServiceProcess -ServiceList $start_services -Operation "Services to Start" -Action "Start"
}
else {
    Write-Log "NoBounce mode: skipped explicit stop/start service lists in this run." "Info"
}

if (-not $NoBounce -and $startsearch -and -not $PSBoundParameters.ContainsKey('WhatIf')) {
    Invoke-StartSearchSelfHeal
    if ($NoRestartExplorer) {
        Write-Log "NoRestartExplorer mode: skipped explorer.exe and ctfmon.exe restart. Start menu auto-type (Ctrl+Esc then typing) may not work until explorer is manually restarted or user signs out/in." "Warning"
    }
    else {
        Invoke-StartSearchInputStackRepair
        Invoke-ExplorerRefreshAfterBounce
    }
}
elseif (-not $NoBounce -and $startsearch -and $PSBoundParameters.ContainsKey('WhatIf')) {
    Write-Log "WhatIf mode: Start/Search repair actions are preview-only. Run elevated without -WhatIf to apply fixes." "Warning"
}
elseif ($NoBounce -and $startsearch) {
    Write-Log "NoBounce mode: skipped post-run Start/Search repair actions because they restart service/process state." "Info"
}

# Display summary
Write-Log "=== Service Management Summary ===" "Info"
Write-Log "Automatic services configured: $($script:ProcessedServices.Auto)" "Info"
Write-Log "Manual services configured: $($script:ProcessedServices.Manual)" "Info"
Write-Log "Disabled services configured: $($script:ProcessedServices.Disabled)" "Info"
Write-Log "Services started: $($script:ProcessedServices.Started)" "Info"
Write-Log "Services stopped: $($script:ProcessedServices.Stopped)" "Info"
Write-Log "Services skipped/not found: $($script:ProcessedServices.Skipped)" "Info"
Write-Log "Failed operations: $($script:ProcessedServices.Failed)" "Info"
Write-Log "=== End Summary ===" "Info"

# Save log if specified
Save-Log

# Pause execution if the $pause flag is set
if ($pause) {
    Write-Log "=== Script completed. Press any key to continue... ===" "Info"
    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
}

Write-Log "=== Windows Service Management Script Completed ===" "Info"

# Exit with appropriate code
if ($script:ProcessedServices.Failed -gt 0) {
    Write-Log "Script completed with $($script:ProcessedServices.Failed) failed operations" "Warning"
    exit 2
}
else {
    Write-Log "Script completed successfully" "Info"
    exit 0
}
