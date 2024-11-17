<# 
.SYNOPSIS
  Stop and Disable Windows Services v1.0

  Copyright 2024 Maxim Masiutin. All rights reserved

.DESCRIPTION
  This script disables and stops certain Windows services.

.PARAMETER audio
  If this parameter is false, services related to audio will be switched to Manual startup type and stopped. Otherwise, if this parameter is True, audio services startup type will be Automatic, such services will be started. Defaults to True.

.PARAMETER print
  If this parameter is false, services related to print will be switched to Manual startup type and stopped. Otherwise, if this parameter is True, print services startup type will be Automatic, such services will be started. Defaults to True.


.EXAMPLE 
  ./stop-services.ps1 -audio False 

  This example stops audio-related services and sets them to Manual startup type, and also modifies other services (see the code below for the list of services and the action upon them).

#>



param( 
  [bool]$audio = $true, 
  [bool]$print = $true 
)


# Note: the following services should be automatically started to avoid errors such as "Volume Shadow Copy Service error: Unexpected error calling routine IVssAsrWriterBackup::GetDiskComponents"
# - COMSysApp			COM+ System Application Service
# - EventSystem 		COM+ Event System
# - MSDTC			Distributed Transaction Coordinator Service
# - swprv			Microsoft Software Shadow Copy Provider
# - srservice			System Restore Service (doe not exist in lates Windows 11 versions)
# - SDRSVC			Can replace srservice in latest Windows 11 versions
# - VSS 			Volume Shadow Copy Service
# - vds 			Virtual Disk Service - needed for Disk Management

# The "auto" list is empty, but we may fill it later, depending on our options
$auto_services = @(
)

$manual_services = @(
  "AarSvc_*"					# ????
  "AdobeARMservice"				# Adobe Acrobat Update Service -- Adobe Acrobat Updater keeps your Adobe software up to date.
  "AESMService" 				# Intel SGX AESM -- The system services management agent for Intel Software Guard Extensions enabled applications.
  "agent_ovpnconnect"				# OpenVPN Agent agent_ovpnconnec
  "AppVClient"					# Microsoft App-V Client -- Manages App-V users and virtual applications
  "ArmouryCrateService" 			# ASUS ARMOURY CRATE Service
  "asus"					# ASUS Update Service (asus) -- Keeps your ASUS software up to date. If this service is disabled or stopped, your ASUS software will not be kept up to date, meaning security vulnerabilities that may arise cannot be fixed and features may not work. This service uninstalls itself when there is no ASUS software using it.
  "AsusAppService"				# ASUS App Service -- Monitors the status of services within MyASUS.
  "ASUSOptimization"				# Provides hardware and software settings control inside Customization tab of MyASUS.
  "AsusROGLSLService"				# AsusROGLSLService Download ROGLSLoader
  "ASUSSoftwareManager" 			# Supports software, firmware, and driver updates through MyASUS.
  "ASUSSwitch"					# Provides Switch & Recovery services within MyASUS.
  "ASUSSystemAnalysis"				# Provides the hardware information required for System Diagnosis inside MyASUS.
  "ASUSSystemDiagnosis" 			# Provides System Diagnosis services within MyASUS.
  "atashost"					# WebEx Service Host for Support Center
  "BcastDVRUserService_*"			# This user service is used for Game Recordings and Live Broadcasts
  "BITS"					# Background Intelligent Transfer Service -- Transfers files in the background using idle network bandwidth. If the service is disabled, then any applications that depend on BITS, such as Windows Update or MSN Explorer, will be unable to automatically download programs and other information.
  "BluetoothUserService_*"			# The Bluetooth user service supports proper functionality of Bluetooth features relevant to each user session.
  "BrokerInfrastructure"			# Background Tasks Infrastructure Service -- Windows infrastructure service that controls which background tasks can run on the system.
  "BTAGService" 				# Bluetooth Audio Gateway Service -- Service supporting the audio gateway role of the Bluetooth Handsfree Profile.
  "BluetoothUserService"
  "BthAvctpSvc" 				# AVCTP service -- This is Audio Video Control Transport Protocol service
  "bthserv"					# Bluetooth Support Service -- The Bluetooth service supports discovery and association of remote Bluetooth devices.	Stopping or disabling this service may cause already installed Bluetooth devices to fail to operate properly and prevent new devices from being discovered or associated.
  "camsvc"					# Capability Access Manager Service -- Provides facilities for managing UWP apps access to app capabilities as well as checking an app's access to specific app capabilities
  "cbdhsvc"
  "cbdhsvc_*"
  "CDPUserSvc"
  "CDPUserSvc_*"
  "ClickToRunSvc"				# Microsoft Office Click-to-Run Service
  "CloudBackupRestoreSvc_"			# Monitors the system for changes in application and setting states and performs cloud backup and restore operations when required.
  "cloudidsvc"					# Microsoft Cloud Identity Service -- Supports integrations with Microsoft cloud identity services.  If disabled, tenant restrictions will not be enforced properly.
  "cplspcon"					# Intel(R) Content Protection HDCP Service -- Intel(R) Content Protection HDCP Service - enables communication with Content Protection HDCP HW
  "CscService"					# Offline Files -- The Offline Files service performs maintenance activities on the Offline Files cache, responds to user logon and logoff events, implements the internals of the public API, and dispatches interesting events to those interested in Offline Files activities and changes in cache state.
  "CxAudioSvc"
  "CxUIUSvc"
  "CxUtilSvc"
  "DDVCollectorSvcApi"				# Dell Data Vault Service API -- Dell Data Vault Service API exposes a COM API for working with the DDV services
  "DDVDataCollector"				# Dell Data Vault Collector -- DDV Collector service gathers system information and stores it for later use
  "DDVRulesProcessor"				# Dell Data Vault Processor -- DDV Rules Processor generates alerts based on data collected by DDV Collector service
  "debugregsvc" 				# Provides helper APIs to enable device discovery and debugging over the network
  "Dell Digital Delivery Services"		# Downloads and installs the applications that you purchased with your computer
  "Dell SupportAssist Remediation"		# Dell SupportAssist Remediation Service
  "DellClientManagementService" 		# Enables Dell applications to manage Dell specific features of the system. If this service is stopped, any services that explicitly depend on it will cause this service to be restarted. If this service is disabled, any services that explicitly depend on it will fail to function.
  "DellTechHub" 				# Dell TechHub -- Foundational service managing Dell applications through Dell TechHub
  "DellTrustedDevice"				# Dell Trusted Device -- Enables enhanced physical hardware security.
  "DeviceAssociationBrokerSvc_*"		# Enables apps to pair devices
  "DeviceAssociationService"			# Device Association Service -- Enables pairing between the system and wired or wireless devices.
  "Dhcp"					# DHCP Client -- Registers and updates IP addresses and DNS records for this computer. If this service is stopped, this computer will not receive dynamic IP addresses and DNS updates. If this service is disabled, any services that explicitly depend on it will fail to start.
  "diagnosticshub.standardcollector.service"	# Microsoft (R) Diagnostics Hub Standard Collector Service
  "DiagTrack"					# Diagnostics Tracking Service
  "DiracAudSrv" 				# Dirac Audio Service
  "DispBrokerDesktopSvc"
  "DisplayEnhancementService"			# Display Enhancement Service -- A service for managing display enhancement such as brightness control.
  "dmwappushservice"				# WAP Push Message Routing Service (see known issues)
  "DPMService"					# Dell Peripheral Manager Service
  "DPS" 					# Diagnostic Policy Service -- The Diagnostic Policy Service enables problem detection, troubleshooting and resolution for Windows components.	If this service is stopped, diagnostics will no longer function.
  "dptftcs"					# Intel(R) Dynamic Tuning Technology Telemetry Service
  "DSAService"
  "DSAUpdateService"				# Intel(R) Driver & Support Assistant Updater -- Keep Intel(R) Driver & Support Assistant up-to-date
  "DsmSvc"					# Device Setup Manager -- Enables the detection, download and installation of device-related software. If this service is disabled, devices may be configured with outdated software, and may not work correctly.
  "DsSvc"					# Data Sharing Service -- Provides data brokering between applications.
  "DusmSvc"
  "edgeupdate"					# Microsoft Edge Update Service (edgeupdate) -- Keeps your Microsoft software up to date. If this service is disabled or stopped, your Microsoft software will not be kept up to date, meaning security vulnerabilities that may arise cannot be fixed and features may not work. This service uninstalls itself when there is no Microsoft software using it.
  "esifsvc"
  "ESRV_SVC_QUEENCREEK" 			# Maxim: this service is CPU-hungry, it makes lots of page faults! Energy Server Service queencreek -- Intel(r) Energy Checker SDK. ESRV Service queencreek
  "fdPHost"					# Function Discovery Provider Host -- The FDPHOST service hosts the Function Discovery (FD) network discovery providers. These FD providers supply network discovery services for the Simple Services Discovery Protocol (SSDP) and Web Services Discovery (WS-D) protocol. Stopping or disabling the FDPHOST service will disable network discovery for these protocols when using FD. When this service is unavailable, network services using FD and relying on these discovery protocols will be unable to find network devices or resources.
  "FDResPub"					# Function Discovery Resource Publication -- Publishes this computer and resources attached to this computer so they can be discovered over the network.	If this service is stopped, network resources will no longer be published and they will not be discovered by other computers on the network.
  "FontCache"					# Windows Font Cache Service -- Optimizes performance of applications by caching commonly used font data. Applications will start this service if it is not already running. It can be disabled, though doing so will degrade application performance.
  "FontCache*"
  "FoxitReaderUpdateService"			# Foxit PDF Reader Update Service
  "GameInput Service"				# Host service for GameInput.
  "GamingServices"
  "GamingServicesNet"
  "GoogleChromeElevationService"		#
  "GoogleUpdaterInternalService*"
  "GoogleUpdaterInternalService*"		#
  "GoogleUpdaterService*"			#
  "GoogleUpdaterService128.0.6597.0"
  "gupdate"
  "HNS" 					# Host Network Service -- Provides support for Windows Virtual Networks.
  "ibtsiva"					# Intel(R) Wireless Bluetooth(R) iBtSiva Service
  "igccservice"
  "igfxCUIService*"				# Intel(R) HD Graphics Control Panel Service -- Service for Intel(R) HD Graphics Control Panel
  "Intel(R) Platform License Manager Service"	# Intel(R) Platform License Manager Service
  "Intel(R) TPM Provisioning Service"		# Intel(R) TPM Provisioning Service (C:\WINDOWS\System32\DriverStore\FileRepository\iclsclient.inf_amd64_76523213b78d9046\lib\TPMProvisioningService.exe)
  "IntelArcControlService"			# Intel(R) Arc Control Service Service for Intel Arc Control. Manages the backend for the Intel Arc Control
  "IntelAudioService"				# Intel(R) Audio Service
  "IntelVrocOobAgent"				# Intel VROC OOB Agent -- Intel Virtual RAID on CPU out-of-band management agent.
  "IntuneManagementExtension"			# Microsoft Intune Management Extension
  "ipfsvc"					# Intel(R) Innovation Platform Framework Service
  "jhi_service" 				# Intel(R) Dynamic Application Loader Host Interface Service -- Intel(R) Dynamic Application Loader Host Interface Service - Allows applications to access the local Intel (R) DAL
  "LanmanServer"				# Server		- Maxim: if we disable server, other services (such as Distributed Transaction Coordinator) will give errors to the event log
  "LanmanWorkstation"				# Workstation - if we disable workstation, other services will give errors to the event log
  "lfsvc"					# Geolocation Service
  "LightingService"				# ASUS AURA SYNC lighting service
  "lmhosts"
  "LMS" 					# Intel(R) Management and Security Application Local Management Service -- Intel(R) Management and Security Application Local Management Service - Provides OS-related Intel(R) ME functionality.
  "ManyCam Service"
  "MapsBroker"					# Downloaded Maps Manager
  "MSDTC"					# MSDTC -- Maxim: if we disable this service, Volume Shadow Copy will stop working properly -- Distributed Transaction Coordinator Service -- Needed for the Volume Shadow Copy service to work
  "ndu" 					# Windows Network Data Usage Monitor
  "Net Driver HPZ12"
  "NetTcpPortSharing"				# Net.Tcp Port Sharing Service
  "NPSMSvc_*"
  "nscp"					# NSClient++ (x64) -- Monitoring agent for nagios (and others) used to respond to status querie
  "NvContainerLocalSystem"			# NVIDIA LocalSystem Container -- Container service for NVIDIA root features
  "NVDisplay.ContainerLocalSystem"
  "NVIDIA Share"
  "NVWMI"					# NVWMI Provider Service
  "OneSyncSvc"
  "OneSyncSvc_*"
  "OpenVPNServiceInteractive"			# OpenVPN Interactive Service -- Allows OpenVPN GUI and other clients to establish OpenVPN connections without administrative privileges in a secure way.
  "ovpnhelper_service"				# OpenVPN Connect Helper Service
  "PcaSvc"
  "PCNS1"					# PowerChute Network Shutdown -- Reliable network based shutdown of multiple servers.
  "PlugPlay"					# Plug and Play -- Enables a computer to recognize and adapt to hardware changes with little or no user input. Stopping or disabling this service will result in system instability.
  "Pml Driver HPZ12"
  "Power"
  "RasMan"
  "Razer Chroma SDK Server"			# Razer Chroma SDK Server -- Razer Chroma SDK web interface
  "Razer Chroma SDK Service"			# Razer Chroma SDK Service -- Provides access to Razer hardware for applications using Razer SDK
  "Razer Chroma Stream Server"			# Razer Chroma Stream Server -- Provides access to the Razer Stream API
  "Razer Game Manager Service 3"		# Razer Game Manager Service 3 -- This service allows for Razer software applications and services to manage the games installed on the system.
  "Razer Game Manager Service"			# Razer Game Manager -- This service allows for Razer software applications and services to manage the games installed on the system.
  "Razer Synapse Service"			# Razer Synapse Service
  "RmSvc"					# Radio Management Service -- Radio Management and Airplane Mode Service
  "RstMwService"				# Intel Storage Middleware Service -- RPC endpoint service which allows communication between driver and Windows Store Application
  "RtkAudioUniversalService"			# Realtek Audio Universal Service
  "RtkBtManServ"				# Realtek Bluetooth Device Manager Service
  "RzActionSvc" 				# Razer Central Service
  "SAService"					# Conexant SmartAudio service -- SmartAudio Helper service
  "SCardSvr"					# Smart Card -- Manages access to smart cards read by this computer. If this service is stopped, this computer will be unable to read smart cards. If this service is disabled, any services that explicitly depend on it will fail to start.
  "ScDeviceEnum"				# Smart Card Device Enumeration Service -- Creates software device nodes for all smart card readers accessible to a given session. If this service is disabled, WinRT APIs will not be able to enumerate smart card readers.
  "SCPolicySvc" 				# Allows the system to be configured to lock the user desktop upon smart card removal.
  "SecurityHealthService"			# Windows Security Service -- Windows Security Service handles unified device protection and health information
  "SENS"
  "SQLWriter"					# SQL Server VSS Writer -- Provides the interface to backup/restore Microsoft SQL server through the Windows VSS infrastructure.
  "SSDPSRV"					# SSDP Discovery -- Discovers networked devices and services that use the SSDP discovery protocol, such as UPnP devices. Also announces SSDP devices and services running on the local computer. If this service is stopped, SSDP-based devices will not be discovered. If this service is disabled, any services that explicitly depend on it will fail to start.
  "ssh-agent"					# OpenSSH Authentication Agent
  "sshd"					# SSH Daemon
  "StateRepository"				# State Repository Service -- Provides required infrastructure support for the application model.
  "StorSvc"
  "stunnel"					# Stunnel TLS wrapper -- TLS offloading and load-balancing proxy
  "SupportAssistAgent"				# Dell SupportAssist keeps your PC up to date and running at its best with recommended software and driver updates. It also helps resolve issues quickly by detecting common problems and sending issue details to Dell Technical Support agents on your behalf.
  "swprv"					# Microsoft Software Shadow Copy Provider -- Maxim: if we disable this service, Volume Shadow Copy will stop working properly -- Manages software-based volume shadow copies taken by the Volume Shadow Copy service. If this service is stopped, software-based volume shadow copies cannot be managed. If this service is disabled, any services that explicitly depend on it will fail to start.
  "SysMain"
  "SystemEventsBroker"
  "TabletInputService"
  "TbtHostControllerService"
  "TextInputManagementService"			# Text Input Management Service -- Enables text input, expressive input, touch keyboard, handwriting, and IMEs.
  "Themes"
  "Themes"					# Provides user experience theme management.
  "TokenBroker" 				# * !!! *  (used by Microsoft Office licence check login, Microsoft store login) # Web Account Manager -- This service is used by Web Account Manager to provide single-sign-on to apps and services.
  "TrkWks"					# Distributed Link Tracking Client
  "UdkUserSvc"
  "UdkUserSvc_*"
  "UnistoreSvc_*"				# Handles storage of structured user data, including contact info, calendars, messages, and other content. If you stop or disable this service, apps that use this data might not work correctly.
  "UserDataSvc_*"				# Provides apps access to structured user data, including contact info, calendars, messages, and other content. If you stop or disable this service, apps that use this data might not work correctly.
  "UsoSvc"					# Update Orchestrator Service -- Manages Windows Updates. If stopped, your devices will not be able to download and install the latest updates.
  "VMAuthdService"
  "vmms"					# Hyper-V Virtual Machine Management -- Management service for Hyper-V, provides service to run multiple virtual machines.
  "VMnetDHCP"
  "VMUSBArbService"
  "VMware NAT Service"
  "VMwareHostd"
  "WaaSMedicSvc"				# Windows Update Medic Service -- Enables remediation and protection of Windows Update components.
  "WbioSrvc"					# Windows Biometric Service (required for Fingerprint reader / facial detection)
  "Wcmsvc"					# Windows Connection Manager -- Makes automatic connect/disconnect decisions based on the network connectivity options currently available to the PC and enables management of network connectivity based on Group Policy settings.
  "webthreatdefsvc"
  "webthreatdefusersvc" 			# Web Threat Defense User Service -- Web Threat Defense User Service helps protect your computer by warning the user when unauthorized entities attempt to gain access to their credentials
  "webthreatdefusersvc_*"
  "Winmgmt"					# Windows Management Instrumentation -- Provides a common interface and object model to access management information about operating system, devices, applications and services. If this service is stopped, most Windows-based software will not function properly. If this service is disabled, any services that explicitly depend on it will fail to start.
  "WlanSvc"
  "WMIRegistrationService"			# Intel(R) Management Engine WMI Provider Registration Service
  "WMPNetworkSvc"				# Windows Media Player Network Sharing Service
  "WpnService"
  "WpnUserService_*"				# This service hosts Windows notification platform which provides support for local and push notifications. Supported notifications are tile, toast and raw.
  "wscsvc"
  "WSearch"
  "wuauserv"					# Windows Update -- Enables the detection, download, and installation of updates for Windows and other programs. If this service is disabled, users of this computer will not be able to use Windows Update or its automatic updating feature, and programs will not be able to use the Windows Update Agent (WUA) API.
  "XblAuthManager"				# Xbox Live Auth Manager
  "XblGameSave" 				# Xbox Live Game Save Service
  "XboxGipSvc"					# Xbox Accessory Management Service
)

$audio_services = @(
  "AudioEndpointBuilder"			# Windows Audio Endpoint Builder - Manages audio devices for the Windows Audio service.  If this service is stopped, audio devices and effects will not function properly.  If this service is disabled, any services that explicitly depend on it will fail to start
  "Audiosrv"						# Windows Audio - Manages audio for Windows-based programs.  If this service is stopped, audio devices and effects will not function properly.	If this service is disabled, any services that explicitly depend on it will fail to start
  "ShellHWDetection"				# Shell Hardware Detection -- Provides notifications for AutoPlay hardware events.
);


$print_services = @(
  "LPDSVC"					# LPD Service -- nables client computers to print to the Line Printer Daemon (LPD) service on this server using TCP/IP and the Line Printer Remote (LPR) protocol.
  "StiSvc"					# Windows Image Acquisition (WIA) -- Provides image acquisition services for scanners and cameras
  "DeviceInstall"				# Device Install Service -- Enables a computer to recognize and adapt to hardware changes with little or no user input. Stopping or disabling this service will result in system instability.
  "DmEnrollmentSvc"				# Device Management Enrollment Service -- Performs Device Enrollment Activities for Device Management
  "Net Driver HPZ*"
  "Pml Driver HPZ*"
  "PrintNotify" 				# Printer Extensions and Notifications -- This service opens custom printer dialog boxes and handles notifications from a remote print server or a printer. If you turn off this service, you won't be able to see printer extensions or notifications.
  "PrintWorkflow_*"
  "PrintWorkflowUserSvc_*"			# Provides support for Print Workflow applications. If you turn off this service, you may not be able to print successfully.
  "Spooler"					# Print Spooler -- This service spools print jobs and handles interaction with the printer.  If you turn off this service, you won�t be able to print or see your printers.
)


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


$disable_services = @(
  "DoSvc"					# Listens on port 7680 TCP! -- Delivery Optimization -- Performs content delivery optimization tasks -- This service is part of Windows Update Delivery Optimization (WUDO), which helps distribute updates and apps more efficiently by using peer-to-peer sharing.
  "CDPSvc"					# Listens on port 5040 TCP!  -- Connected Devices Platform Service -- This service is used for Connected Devices Platform scenarios
  "CDPUserSvc_*"				# Additional service for CDPSvs Connected Devices Platform User Service -- This user service is used for Connected Devices Platform scenarios
  "tvnserver"					# TightVNC Server
  "RemoteAccess"				# Routing and Remote Access
  "RemoteRegistry"				# Remote Registry
  "SharedAccess"				# Internet Connection Sharing (ICS)
  "SystemUsageReportSvc_QUEENCREEK"		# Maxim: this service makes lots of page faults
  "WinRM"					# Windows Remote Management (WS-Management) -- Windows Remote Management (WinRM) service implements the WS-Management protocol for remote management. WS-Management is a standard web services protocol used for remote software and hardware management. The WinRM service listens on the network for WS-Management requests and processes them. The WinRM Service needs to be configured with a listener using winrm.cmd command line tool or through Group Policy in order for it to listen over the network. The WinRM service provides access to WMI data and enables event collection. Event collection and subscription to events require that the service is running. WinRM messages use HTTP and HTTPS as transports. The WinRM service does not depend on IIS but is preconfigured to share a port with IIS on the same machine.  The WinRM service reserves the /wsman URL prefix. To prevent conflicts with IIS, administrators should ensure that any websites hosted on IIS do not use the /wsman URL prefix.
)

$stop_services = @(
  "XboxNetApiSvc"				# Xbox Live Networking Service
  "BrokerInfrastructure"			# Background Tasks Infrastructure Service -- Windows infrastructure service that controls which background tasks can run on the system.
  "bthserv"					# Bluetooth Support Service -- The Bluetooth service supports discovery and association of remote Bluetooth devices.	Stopping or disabling this service may cause already installed Bluetooth devices to fail to operate properly and prevent new devices from being discovered or associated.
  "camsvc"					# Capability Access Manager Service -- Provides facilities for managing UWP apps access to app capabilities as well as checking an app's access to specific app capabilities
  "cbdhsvc_*"					# Clipboard User Service -- This user service is used for Clipboard scenarios
  "CDPSvc"					# Connected Devices Platform Service -- This service is used for Connected Devices Platform scenarios
  "CertPropSvc" 				# Certificate Propagation -- Copies user certificates and root certificates from smart cards into the current user's certificate store, detects when a smart card is inserted into a smart card reader, and, if needed, installs the smart card Plug and Play minidriver.
  "ClickToRunSvc"				# Microsoft Office Click-to-Run Service
  "ClipSVC"					# Client License Service (ClipSVC) -- Provides infrastructure support for the Microsoft Store. This service is started on demand and if disabled applications bought using Windows Store will not behave correctly.
  "cloudidsvc"					# Microsoft Cloud Identity Service -- Supports integrations with Microsoft cloud identity services.  If disabled, tenant restrictions will not be enforced properly.
  "ConsentUxUser"
  "ConsentUxUserSvc_*"
  "cplspcon"					# Intel(R) Content Protection HDCP Service -- Intel(R) Content Protection HDCP Service - enables communication with Content Protection HDCP HW
  "dcsvc"					# Declared Configuration(DC) service
  "DisplayEnhancementService"			# Display Enhancement Service -- A service for managing display enhancement such as brightness control.
  "DSAUpdateService"				# Intel(R) Driver & Support Assistant Updater -- Keep Intel(R) Driver & Support Assistant up-to-date
  "DsmSvc"					# Device Setup Manager -- Enables the detection, download and installation of device-related software. If this service is disabled, devices may be configured with outdated software, and may not work correctly.
  "fdPHost"					# Function Discovery Provider Host -- The FDPHOST service hosts the Function Discovery (FD) network discovery providers. These FD providers supply network discovery services for the Simple Services Discovery Protocol (SSDP) and Web Services � Discovery (WS-D) protocol. Stopping or disabling the FDPHOST service will disable network discovery for these protocols when using FD. When this service is unavailable, network services using FD and relying on these discovery protocols will be unable to find network devices or resources.
  "FDResPub"					# Function Discovery Resource Publication -- Publishes this computer and resources attached to this computer so they can be discovered over the network.	If this service is stopped, network resources will no longer be published and they will not be discovered by other computers on the network.
  "GamingServices"
  "igfxCUIService*"				# Intel(R) HD Graphics Control Panel Service -- Service for Intel(R) HD Graphics Control Panel
  "InstallService"				# Microsoft Store Install Service -- Provides infrastructure support for the Microsoft Store.  This service is started on demand and if disabled then installations will not function properly.
  "Intel(R) Capability Licensing Service TCP IP Interface"
  "InventorySvc"				# Inventory and Compatibility Appraisal service -- This service performs background system inventory, compatibility appraisal, and maintenance used by numerous system components.
  "NPSMSvc_*"					# ???
  "nvagent"					# Network Virtualization Service -- Provides network virtualization services.
  "PhoneSvc"
  "PimIndexMaintenanceSvc"
  "PimIndexMaintenanceSvc_*"
  "RmSvc"					# Radio Management Service -- Radio Management and Airplane Mode Service
  "sacsvr"					# Special Administration Console Helper -- Allows administrators to remotely access a command prompt using Emergency Management Services.
  "Spooler"					# Print Spooler -- This service spools print jobs and handles interaction with the printer.  If you turn off this service, you won�t be able to print or see your printers.
  "StorSvc"					# Storage Service -- Provides enabling services for storage settings and external storage expansion
  "TextInputManagementService"			# Text Input Management Service -- Enables text input, expressive input, touch keyboard, handwriting, and IMEs.
  "TimeBrokerSvc"				# Time Broker -- Coordinates execution of background work for WinRT application. If this service is stopped or disabled, then background work might not be triggered.
  "TokenBroker"
  "UdkUserSvc_*"				# Shell components service
  "UnistoreSvc_*"				# Handles storage of structured user data, including contact info, calendars, messages, and other content. If you stop or disable this service, apps that use this data might not work correctly.
  "UserDataSvc_*"				# Provides apps access to structured user data, including contact info, calendars, messages, and other content. If you stop or disable this service, apps that use this data might not work correctly.
  "UsoSvc"					# Update Orchestrator Service -- Manages Windows Updates. If stopped, your devices will not be able to download and install the latest updates.
  "vmcompute"					# Hyper-V Host Compute Service -- Provides support for running Windows Containers and Virtual Machines.
  "WaaSMedicSvc"				# Windows Update Medic Service -- Enables remediation and protection of Windows Update components.
  "WinHttpAutoProxySvc" 			# WinHTTP Web Proxy Auto-Discovery Service -- WinHTTP implements the client HTTP stack and provides developers with a Win32 API and COM Automation component for sending HTTP requests and receiving responses. In addition, WinHTTP provides support for auto-discovering a proxy configuration via its implementation of the Web Proxy Auto-Discovery (WPAD) protocol.
  "Winmgmt"					# Windows Management Instrumentation -- Provides a common interface and object model to access management information about operating system, devices, applications and services. If this service is stopped, most Windows-based software will not function properly. If this service is disabled, any services that explicitly depend on it will fail to start.
  "WpnUserService_*"				# This service hosts Windows notification platform which provides support for local and push notifications. Supported notifications are tile, toast and raw.
  "wuauserv"					# Windows Update -- Enables the detection, download, and installation of updates for Windows and other programs. If this service is disabled, users of this computer will not be able to use Windows Update or its automatic updating feature, and programs will not be able to use the Windows Update Agent (WUA) API.
)

$start_services = @(
  "DeviceAssociationService"
  "SecurityHealthService"			# Windows Security Service -- Windows Security Service handles unified device protection and health information
  "WlanSvc"
)

# Sleep 2 seconds to let automatic services to start before we stop them
Start-Sleep -Seconds 2

foreach ($serviceName in $auto_services) {
  $serviceHandle = Get-Service -Name $serviceName -ErrorAction SilentlyContinue
  if ($null -eq $serviceHandle) {
    Write-Output "Service $serviceName does not exist (wanted to change its startup type to Automatic and start it)."
  }
  else {
    Write-Output "Trying to change startup type to Automatic of the service $resolvedName ($serviceName) and start it..."
    $resolvedName = $serviceHandle.Name
    $serviceStartupType = $serviceHandle.StartupType
    $serviceStatus = $serviceHandle.Status
    if ($serviceStartupType -in @("Automatic", "AutomaticDelayedStart")) {
      Write-Output "The service already has startup type '$serviceStartupType'."
    } else
    {
      Set-Service -Name $resolvedName -StartupType Automatic
    }
    if ($serviceStatus -eq "Stopped")
    { 
      Start-Service -Name $resolvedName
    } elseif ($serviceStatus -eq "Running") {
      Write-Output "The service is already running."
    } else {
      Write-Output "The service status is $serviceStatus, would not start it."
    }
  }
}

foreach ($serviceName in $manual_services) {
  $serviceHandle = Get-Service -Name $serviceName -ErrorAction SilentlyContinue
  if ($null -eq $serviceHandle) {
    Write-Output "Service $serviceName does not exist (wanted to change its startup type to Manual and stop it)"
  }
  else {
    $resolvedName = $serviceHandle.Name
    Write-Output "Trying to change to Manual the service $resolvedName ($serviceName) and stop it"
    Set-Service -Name $resolvedName -StartupType manual
    Get-Service -Name $resolvedName | Where-Object { $_.Status -eq "Running" } | Stop-Service -Force -NoWait
  }
}

foreach ($serviceName in $disable_services) {
  $serviceHandle = Get-Service -Name $serviceName -ErrorAction SilentlyContinue
  if ($null -eq $serviceHandle) {
    Write-Output "Service $serviceName does not exist (wanted to Disable it and stop it)"
  }
  else {
    $resolvedName = $serviceHandle.Name
    Write-Output "Trying to disable the service $resolvedName ($serviceName)"
    Get-Service -Name $resolvedName | Set-Service -StartupType disabled
    Get-Service -Name $resolvedName | Where-Object { $_.Status -eq "Running" } | Stop-Service -Force -NoWait
  }
}

foreach ($serviceName in $stop_services) {
  $serviceHandle = Get-Service -Name $serviceName -ErrorAction SilentlyContinue
  if ($null -eq $serviceHandle) {
    Write-Output "Service $serviceName does not exist (wanted to stop it)"
  }
  else {
    $resolvedName = $serviceHandle.Name
    Write-Output "Trying to stop service $resolvedName ($serviceName)"
    Get-Service -Name $serviceName | Where-Object { $_.Status -eq "Running" } | Stop-Service -Force -NoWait
  }
}

foreach ($serviceName in $start_services) {
  $serviceHandle = Get-Service -Name $serviceName -ErrorAction SilentlyContinue
  if ($null -eq $serviceHandle) {
    Write-Output "Service $serviceName does not exist (wanted to start it)"
  }
  else {
    $resolvedName = $serviceHandle.Name
    Write-Output "Trying to start service $resolvedName ($serviceName)"
    Get-Service -Name $serviceName | Where-Object { $_.Status -eq "Stopped" } | Start-Service
  }
}

