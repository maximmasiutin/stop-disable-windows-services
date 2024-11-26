# Stop and Disable Windows Services

Copyright 2024 Maxim Masiutin. All rights reserved

This PowerShell script is aimed to stop and disable certain Windows services listed in the script.

If running the script gives an error that the script cannot be loaded because running scripts are disabled on this system, enable the script by running `Set-ExecutionPolicy RemoteSigned` in PowerShell.

The PowerShell script also has the following boolean parameters:

### -audio

If this parameter is `$False`, services related to audio will be switched to **Manual** startup type and stopped. Otherwise, if this parameter is `$True`, audio services' startup type will be **Automatic**, and such services will be started. Defaults to `$True`.

### -print

If this parameter is `$False`, services related to printing will be switched to **Manual** startup type and stopped. Otherwise, if this parameter is `$True`, print services' startup type will be **Automatic**, and such services will be started. Defaults to `$True`.

### -pause

If this parameter is `$True`, the script will prompt the user to press any key before it exits. Defaults to `$False`.

**Example:**

```powershell
./stop-services.ps1 -audio $False -pause $True