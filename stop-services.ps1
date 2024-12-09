<#
.SYNOPSIS
 Stop and Disable Windows Services v1.0

 Copyright 2024 Maxim Masiutin. All rights reserved

.DESCRIPTION
 This script disables and stops certain Windows services.

.PARAMETER audio
 If this parameter is $False, services related to audio will be switched to Manual startup type and stopped. Otherwise, if this parameter is $True, audio services' startup type will be Automatic, and such services will be started. Defaults to $True.

.PARAMETER print
 If this parameter is $False, services related to print will be switched to Manual startup type and stopped. Otherwise, if this parameter is $True, print services' startup type will be Automatic, and such services will be started. Defaults to $True.

.PARAMETER pause
 If this parameter is $True, the script will prompt the user to press any key before it exits. Defaults to $False.

.PARAMETER workstation
 If this parameter is $False, services related to workstation will be switched to Manual startup type and stopped. Otherwise, if this parameter is $True, workstation services' startup type will be Automatic, and such services will be started. Defaults to $True.

.PARAMETER brokers
 If this parameter is $False, services related to brokers will be switched to Manual startup type and stopped. Otherwise, if this parameter is $True, broker services' startup type will be Automatic, and such services will be started. Defaults to $True.

.EXAMPLE
 ./stop-services.ps1 -audio $False -pause $True -workstation $True -brokers $True

 This example stops audio-related services and sets them to Manual startup type, starts workstation and broker services as Automatic, and prompts the user to press any key before the script exits. Also, it modifies other services as specified in the code.
#>

param(
    [bool]$audio = $true,
    [bool]$print = $true,
    [bool]$pause = $false,
    [bool]$brokers = $true,
    [bool]$workstation = $true

)

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
    "ASUSSystemDiagnosis" # ASUS System Diagnosis - Provides diagnostic services within MyASUS.
    "atashost" # WebEx Service Host - Provides support for WebEx sessions.
    "BcastDVRUserService_*" # Broadcast DVR User Service - Supports game recordings and live broadcasts.
    "BITS" # Background Intelligent Transfer Service - Transfers files in the background using idle network bandwidth. Required for Windows Update and other applications.
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
    "CloudBackupRestoreSvc_" # Cloud Backup and Restore Service - Monitors changes in application and setting states, and performs cloud backup and restore operations.
    "cloudidsvc" # Microsoft Cloud Identity Service - Integrates with Microsoft cloud identity services, enforcing tenant restrictions.
    "cplspcon" # Intel Content Protection HDCP Service - Enables communication with Content Protection HDCP hardware.
    "CscService" # Offline Files - Manages maintenance activities on the Offline Files cache and responds to user logon and logoff events.
    "CxAudioSvc" # Conexant Audio Service - Manages Conexant audio settings and functionality.
    "CxUIUSvc" # Conexant UIU Service - Supports Conexant user interface utilities.
    "CxUtilSvc" # Conexant Utility Service - Manages Conexant utility features and settings.
    "DDVCollectorSvcApi" # Dell Data Vault Service API - Exposes a COM API for working with Dell Data Vault services.
    "DDVDataCollector" # Dell Data Vault Collector - Gathers system information for later use.
    "DDVRulesProcessor" # Dell Data Vault Processor - Generates alerts based on collected data.
    "debugregsvc" # Network Device Registration Service - Enables device discovery and debugging over the network.
    "Dell Digital Delivery Services" # Downloads and installs applications purchased with your computer.
    "Dell SupportAssist Remediation" # Dell SupportAssist Remediation Service - Provides remediation services for Dell systems.
    "DellClientManagementService" # Dell Client Management Service - Manages Dell-specific features. Required for dependent services.
    "DellTechHub" # Dell TechHub - Manages Dell applications through Dell TechHub.
    "DellTrustedDevice" # Dell Trusted Device - Enhances physical hardware security.
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
    "FontCache" # Windows Font Cache Service - Optimizes application performance by caching commonly used font data. Disabling this service will degrade application performance.
    "FontCache*" # Windows Font Cache Service - Optimizes application performance by caching commonly used font data. Disabling this service will degrade application performance.
    "FoxitReaderUpdateService" # Foxit PDF Reader Update Service - Keeps Foxit PDF Reader up to date.
    "GameInput Service" # Game Input Service - Host service for game input devices and peripherals.
    "GamingServices" # Gaming Services - Manages gaming-related services and features.
    "GamingServicesNet" # Gaming Services Network - Supports network features for gaming services.
    "GoogleChromeElevationService" # Google Chrome Elevation Service - Manages elevation requests for Google Chrome updates.
    "GoogleUpdaterInternalService*" # Google Updater Internal Service - Manages internal updates for Google software.
    "GoogleUpdaterInternalService*" # Google Updater Internal Service - Manages internal updates for Google software.
    "GoogleUpdaterService*" # Google Updater Service - Manages updates for Google software.
    "GoogleUpdaterService128.0.6597.0" # Google Updater Service - Manages updates for Google software.
    "gupdate" # Google Update Service - Keeps Google software up to date.
    "HNS" # Host Network Service - Provides support for Windows Virtual Networks.
    "ibtsiva" # Intel Wireless Bluetooth Service - Manages Bluetooth connections for Intel wireless devices.
    "igccservice" # Intel Graphics Command Center Service - Manages settings and features for Intel graphics.
    "igfxCUIService*" # Intel HD Graphics Control Panel Service - Manages settings for Intel HD Graphics.
    "Intel(R) Platform License Manager Service" # Intel Platform License Manager Service - Manages licenses for Intel software.
    "Intel(R) TPM Provisioning Service" # Intel TPM Provisioning Service - Manages Trusted Platform Module (TPM) provisioning.
    "IntelArcControlService" # Intel Arc Control Service - Manages backend features for Intel Arc Control.
    "IntelAudioService" # Intel Audio Service - Manages Intel audio settings and functionality.
    "IntelVrocOobAgent" # Intel VROC OOB Agent - Manages out-of-band features for Intel Virtual RAID on CPU.
    "IntuneManagementExtension" # Microsoft Intune Management Extension - Manages Intune operations and device compliance.
    "ipfsvc" # Intel Innovation Platform Framework Service - Supports Intel innovation platform features.
    "jhi_service" # Intel Dynamic Application Loader Host Interface Service - Allows applications to access Intel Dynamic Application Loader.
    "LanmanServer" # Server Service - Provides file, print, and named-pipe sharing over the network.
    "lfsvc" # Geolocation Service - Manages location data for applications and services.
    "LightingService" # ASUS AURA SYNC Lighting Service - Manages lighting settings for ASUS devices.
    "lmhosts" # TCP/IP NetBIOS Helper - Provides support for NetBIOS over TCP/IP (NetBT) service and NetBIOS name resolution.
    "LMS" # Intel Local Management Service - Provides OS-related functionality for Intel Management Engine.
    "ManyCam Service" # ManyCam Service - Manages settings and features for ManyCam software.
    "MapsBroker" # Downloaded Maps Manager - Manages downloaded maps for Windows applications.
    "MSDTC" # Distributed Transaction Coordinator - Coordinates distributed transactions for applications and services. Required for Volume Shadow Copy service.
    "ndu" # Network Data Usage Monitor - Monitors network data usage.
    "Net Driver HPZ12" # HP Network Printer Driver - Manages network printing for HP printers.
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
    "Pml Driver HPZ12" # HP PML Driver - Manages settings for HP printers.
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
    "SCardSvr" # Smart Card Service - Manages access to smart cards. If stopped "ScDeviceEnum"				# Smart Card Device Enumeration Service -- Creates software device nodes for all smart card readers accessible to a given session. If this service is disabled, WinRT APIs will not be able to enumerate smart card readers.
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
    "TabletInputService" # Tablet PC Input Service - Enables pen and touch input features, including handwriting and touch keyboard.
    "TbtHostControllerService" # Thunderbolt Host Controller Service - Manages Thunderbolt connections and settings.
    "TextInputManagementService" # Text Input Management Service - Enables text input, touch keyboard, handwriting, and IMEs (Input Method Editors).
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
    "WaaSMedicSvc" # Windows Update Medic Service - Enables remediation and protection of Windows Update components.
    "WbioSrvc" # Windows Biometric Service - Manages biometric devices, such as fingerprint readers and facial recognition.
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
    "WSearch" # Windows Search Service - Provides content indexing, property caching, and search results for files, emails, and other content.
    "wuauserv" # Windows Update Service - Manages detection, download, and installation of updates for Windows and other programs.
    "XblAuthManager" # Xbox Live Auth Manager - Manages authentication for Xbox Live services.
    "XblGameSave" # Xbox Live Game Save Service - Manages game save data for Xbox Live.
    "XboxGipSvc" # Xbox Accessory Management Service - Manages Xbox accessories and their settings.
)


$workstation_services = @(
    "LanmanWorkstation" # Workstation - If disabled, other services will log errors in the event log; if set to Manual, it will not start automatically.
)

$broker_services = @(
    "BrokerInfrastructure" # Background Tasks Infrastructure Service - Controls which background tasks can run on the system.
    "SystemEventsBroker" # System Events Broker - Coordinates the execution of background tasks for Windows Store and UWP applications. If stopped, these tasks might not be triggered, affecting the functionality of the apps.
    "SysMain" # SysMain (formerly Superfetch) - Improves system performance by preloading frequently used applications into RAM. It analyzes usage patterns and preloads applications to reduce load times and improve overall performance. Can cause high CPU or disk usage; disable if it causes performance issues.
    "TokenBroker" # Token Broker - Used by Microsoft Office license check, Microsoft Store login. Provides single-sign-on to apps and services via Web Account Manager.
)

$audio_services = @(
    "AudioEndpointBuilder" # Windows Audio Endpoint Builder - Manages audio devices for the Windows Audio service. If stopped, audio devices and effects won't function properly. Dependent services will fail to start if disabled.
    "Audiosrv" # Windows Audio - Manages audio for Windows-based programs. If stopped, audio devices and effects won't function properly. Dependent services will fail to start if disabled.
    "ShellHWDetection" # Shell Hardware Detection - Provides notifications for AutoPlay hardware events.
)

$print_services = @(
    "LPDSVC" # LPD Service - Enables client computers to print to the Line Printer Daemon (LPD) service on this server using TCP/IP and the Line Printer Remote (LPR) protocol.
    "StiSvc" # Windows Image Acquisition (WIA) - Provides image acquisition services for scanners and cameras.
    "DeviceInstall" # Device Install Service - Enables a computer to recognize and adapt to hardware changes with little or no user input. Stopping or disabling this service will result in system instability.
    "DmEnrollmentSvc" # Device Management Enrollment Service - Performs Device Enrollment Activities for Device Management.
    "Net Driver HPZ*" # HP Network Printer Driver - Used by HP printers.
    "Pml Driver HPZ*" # HP PML Driver - Used by HP printers.
    "PrintNotify" # Printer Extensions and Notifications - Opens custom printer dialog boxes and handles notifications from a remote print server or a printer. If disabled, printer extensions or notifications won't be visible.
    "PrintWorkflow_*" # Print Workflow - Provides support for Print Workflow applications. Disabling this service might prevent successful printing.
    "PrintWorkflowUserSvc_*" # Print Workflow User Service - Provides support for Print Workflow applications. Disabling this service might prevent successful printing.
    "Spooler" # Print Spooler - Spools print jobs and handles interaction with the printer. If stopped, printing and printer visibility will not be possible.
)

$disable_services = @(
    "DoSvc" # Delivery Optimization - Performs content delivery optimization tasks. Uses peer-to-peer sharing for efficient distribution of updates and apps. Listens on port 7680 TCP.
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
    "cloudidsvc" # Microsoft Cloud Identity Service - Supports integrations with Microsoft cloud identity services. If disabled, tenant restrictions will not be enforced properly.
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
    "Spooler" # Print Spooler - Manages print jobs and printer interactions. Stopping this service will prevent printing and printer visibility.
    "StorSvc" # Storage Service - Manages storage settings and external storage expansion.
    "TextInputManagementService" # Text Input Management Service - Enables text input, touch keyboard, handwriting, and IMEs.
    "TimeBrokerSvc" # Time Broker Service - Coordinates execution of background work for WinRT applications. Disabling this service may prevent background work from being triggered.
    "TokenBroker" # Token Broker - Manages tokens for application authentication.
    "UdkUserSvc_*" # Universal Driver Kit User Service - Manages settings for Universal Driver Kit for specific user sessions.
    "UnistoreSvc_*" # User Data Storage Service - Handles storage of structured user data (contacts, calendars, messages, etc.). Disabling this service may affect apps that use this data.
    "UserDataSvc_*" # User Data Access Service - Provides apps access to structured user data (contacts, calendars, messages, etc.). Disabling this service may affect apps that use this data.
    "UsoSvc" # Update Orchestrator Service - Manages Windows Updates. Disabling this service will prevent downloading and installing updates.
    "vmcompute" # Hyper-V Host Compute Service - Provides support for running Windows Containers and Virtual Machines.
    "WaaSMedicSvc" # Windows Update Medic Service - Enables remediation and protection of Windows Update components.
    "WinHttpAutoProxySvc" # WinHTTP Web Proxy Auto-Discovery Service - Implements the client HTTP stack and provides support for auto-discovering a proxy configuration via the Web Proxy Auto-Discovery (WPAD) protocol.
    "Winmgmt" # Windows Management Instrumentation (WMI) - Provides a common interface and object model to access management information about the operating system, devices, applications, and services.
    "WpnUserService_*" # Windows Push Notifications User Service - Manages push notifications for specific user sessions. Supports tile, toast, and raw notifications.
    "wuauserv" # Windows Update Service - Manages detection, download, and installation of updates for Windows and other programs. Disabling this service will prevent the use of Windows Update and its automatic updating feature.
)

$start_services = @(
    "DeviceAssociationService" # Device Association Service - Manages pairing between the system and wired or wireless devices.
    "SecurityHealthService" # Windows Security Service - Handles unified device protection and health information.
    "WlanSvc" # WLAN AutoConfig Service - Manages wireless network connections.
)

function Set-ServiceStartupType {
    param (
        [string]$serviceName,
        [string]$startupType
    )
    try {
        $serviceHandle = Get-Service -Name $serviceName -ErrorAction Stop
        if ($null -ne $serviceHandle) {
            Write-Output "Trying to change startup type to $startupType of the service $serviceHandle.Name ($serviceName)..."
            Set-Service -Name $serviceHandle.Name -StartupType $startupType -ErrorAction Stop
            Write-Output "$serviceHandle.Name startup type changed to $startupType."
        }
        else {
            Write-Output "Service $serviceName does not exist."
        }
    }
    catch {
        if ($_.Exception.Message -like "*Access is denied*" -or $_.Exception.Message -like "*PermissionDenied*") {
            Write-Output "Permission denied for $serviceName. Attempting with 'net' commands."
            switch ($startupType) {
                "Automatic" { Invoke-Expression "sc config $serviceName start= auto" }
                "Manual" { Invoke-Expression "sc config $serviceName start= demand" }
                "Disabled" { Invoke-Expression "sc config $serviceName start= disabled" }
            }
        }
        elseif ($_.Exception.Message -like "*Cannot find any service with service name*") {
            Write-Output "Service $serviceName does not exist."
        }
        else {
            Write-Error "Failed to handle $($serviceName): $($_.Exception.Message)"
        }
    }
}

function Manage-Service {
    param (
        [string]$serviceName,
        [string]$action
    )
    try {
        $serviceHandle = Get-Service -Name $serviceName -ErrorAction Stop
        if ($null -ne $serviceHandle) {
            switch ($action) {
                "Start" {
                    if ($serviceHandle.Status -eq "Stopped") {
                        Start-Service -Name $serviceHandle.Name -ErrorAction Stop
                        Write-Output "$serviceHandle.Name started successfully."
                    }
                    else {
                        Write-Output "The service $($serviceHandle.Name) is already running."
                    }
                }
                "Stop" {
                    if ($serviceHandle.Status -eq "Running") {
                        Stop-Service -Name $serviceHandle.Name -ErrorAction Stop -Force -NoWait
                        Write-Output "$serviceHandle.Name stopped successfully."
                    }
                    else {
                        Write-Output "The service $($serviceHandle.Name) is not running."
                    }
                }
            }
        }
        else {
            Write-Output "Service $serviceName does not exist."
        }
    }
    catch {
        if ($_.Exception.Message -like "*Access is denied*" -or $_.Exception.Message -like "*PermissionDenied*") {
            Write-Output "Permission denied for $serviceName. Attempting with 'net' commands."
            switch ($action) {
                "Start" { Invoke-Expression "net start $serviceName" }
                "Stop" { Invoke-Expression "net stop $serviceName" }
            }
        }
        elseif ($_.Exception.Message -like "*Cannot find any service with service name*") {
            Write-Output "Service $serviceName does not exist."
        }
        else {
            Write-Error "Failed to handle $($serviceName): $($_.Exception.Message)"
        }
    }
}

if ($audio -eq $true) {
    Write-Output "Setting up audio services as automatic..."
    $auto_services += $audio_services
}
else {
    Write-Output "Setting up audio services as manual..."
    $manual_services += $audio_services
    $stop_services += $audio_services
}

if ($print -eq $true) {
    Write-Output "Setting up print services as automatic..."
    $auto_services += $print_services
}
else {
    Write-Output "Setting up print services as manual..."
    $manual_services += $print_services
    $stop_services += $print_services
}

if ($workstation -eq $true) {
    Write-Output "Setting up workstation services as automatic..."
    $auto_services += $workstation_services
}
else {
    Write-Output "Setting up workstation services as manual..."
    $manual_services += $workstation_services
    $stop_services += $workstation_services
}

if ($brokers -eq $true) {
    Write-Output "Setting up broker services as automatic..."
    $auto_services += $broker_services
}
else {
    Write-Output "Setting up broker services as manual..."
    $manual_services += $broker_services
    $stop_services += $broker_services
}


# Process automatic services
foreach ($serviceName in $auto_services) {
    Set-ServiceStartupType -serviceName $serviceName -startupType "Automatic"
    Manage-Service -serviceName $serviceName -action "Start"
}

# Process manual services
foreach ($serviceName in $manual_services) {
    Set-ServiceStartupType -serviceName $serviceName -startupType "Manual"
    Manage-Service -serviceName $serviceName -action "Stop"
}

# Process disabled services
foreach ($serviceName in $disable_services) {
    Set-ServiceStartupType -serviceName $serviceName -startupType "Disabled"
    Manage-Service -serviceName $serviceName -action "Stop"
}

# Process services to be stopped
foreach ($serviceName in $stop_services) {
    Manage-Service -serviceName $serviceName -action "Stop"
}

# Process services to be started
foreach ($serviceName in $start_services) {
    Manage-Service -serviceName $serviceName -action "Start"
}

# Pause execution if the $pause flag is set
if ($pause) {
    Write-Output "Press any key to continue..."
    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
}
