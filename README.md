# Install-WingetV2 PowerShell Script

A robust PowerShell script that automates the installation of Windows Package Manager (Winget) and its entire dependency chain on systems without Winget pre-installed, such as clean installations of Windows Server 2025.

## Quick Start Usage

### Basic Installation
```powershell
.\Install-WingetV2.ps1
```

### Install Prerelease Version
```powershell
.\Install-WingetV2.ps1 -IncludePrerelease
```

### Custom Log File Location
```powershell
.\Install-WingetV2.ps1 -LogPath "C:\Logs\Winget-Install.log"
```

### Winget Prerelease Install
```powershell
.\Install-WingetV2.ps1 -IncludePrerelease -LogPath "C:\Logs\Winget-Install.log"
```

### Winget Silent Installation

```powershell
PowerShell.exe -NonInteractive .\Install-WingetV2.ps1
```



## Background

As detailed in the "Analysis of the Windows Package Manager's Evolving Dependency Architecture," newer versions of Winget have transitioned to a dependency on the Windows App SDK Runtime. This represents a significant architectural shift from earlier versions that relied primarily on Visual C++ redistributables.

This script addresses the challenge of bootstrapping Winget on clean Windows installations, particularly Windows Server environments, where Winget and its modern dependencies are not pre-installed. The script leverages the `Microsoft.WinGet.Client` PowerShell module and its `Repair-WinGetPackageManager` cmdlet, which acts as a bootstrapping engine to install Winget and all its modern dependencies automatically.

**Primary Use Cases:**
- Clean installations of Windows Server 2025 and other server editions
- Unattended installation through NonInteractive mode
- Eases system administrator workflows for bootstrapping package management capabilities
- Enterprise environments requiring consistent Winget deployment across multiple systems

## Dependency Update: App Installer uses WinUI 3

- Starting with WinGet 1.12.350, App Installer moved from WinUI 2 to WinUI 3.
- This change replaces the WinUI 2 dependency with the Windows App Runtime 1.8+.
- This script relies on `Repair-WinGetPackageManager` to pull the correct components and includes a verification step that enforces Windows App Runtime 1.8+ presence.

## Parameters

| Parameter | Type | Required | Default | Description |
|-----------|------|----------|---------|-------------|
| `IncludePrerelease` | Switch | No | False | Install the latest preview version of Winget |
| `LogPath` | String | No | `%temp%\Install-WingetV2.log` | Custom path for the log file |

## Overview

This script leverages the `Microsoft.WinGet.Client` PowerShell module and its `Repair-WinGetPackageManager` cmdlet to bootstrap Winget installation. It handles all prerequisites, dependencies, and provides comprehensive logging for automation scenarios.

## Features

- ✅ **Comprehensive Prerequisite Checks**: Validates OS version, PowerShell version, execution policy, and administrative privileges
- ✅ **Idempotent Operation**: Safe to run multiple times without side effects
- ✅ **Automation Ready**: Non-interactive execution suitable for deployment tools (Intune, SCCM, etc.)
- ✅ **Robust Error Handling**: Detailed error messages and logging for troubleshooting
- ✅ **Dual Logging**: Console output with color coding and file logging
- ✅ **Prerelease Support**: Option to install preview versions of Winget
- ✅ **Dependency Management**: Automatically installs all required components
- ✅ **Dependency Verification**: Validates Windows App Runtime 1.8+ presence after installation

## Requirements

### System Requirements
- **Operating System**: Windows 10 version 1809 (build 17763) or later, or Windows Server 2022 or later
- **PowerShell**: Version 5.1 or higher
- **Privileges**: Must run as Administrator
- **Network**: Internet connectivity required for downloads

### Dependencies Installed
The script automatically installs the following components:
- **Primary Application**: Microsoft.DesktopAppInstaller (Winget)
- **Windows App Runtime 1.8+ and Windows App SDK components**:
  - Microsoft.WindowsAppRuntime (Framework, 1.8+)
  - Microsoft.WindowsAppSDK.Main (Main)
  - Microsoft.WindowsAppSDK.Singleton (Singleton)
  - Microsoft.WindowsAppSDK.DDLM (for appropriate architecture)
- **Other Dependencies**: Microsoft.VCLibs (Visual C++ Runtime)

## Installation Process

The script follows this sequence:

1. **Initialize Logging** - Sets up dual logging (console + file)
2. **Prerequisite Checks** - Validates system requirements
3. **Idempotency Check** - Verifies if Winget is already installed
4. **NuGet Provider** - Installs NuGet package provider if needed
5. **WinGet Module** - Installs Microsoft.WinGet.Client module
6. **Winget Installation** - Executes `Repair-WinGetPackageManager`
7. **Verification** - Tests Winget functionality and validates Windows App Runtime 1.8+ presence
8. **Completion** - Reports success and duration

## Windows Sandbox Examples

### A) Quick run in Windows Sandbox (.wsb)
Save the following as `WingetSandbox.wsb` and double-click it. It downloads and runs the installer script inside the sandbox.

```xml
<Configuration>
  <VGpu>Disable</VGpu>
  <Networking>Enable</Networking>
  <LogonCommand>
    <Command>
      powershell -NoProfile -ExecutionPolicy Bypass -Command "
        $url='https://raw.githubusercontent.com/kkaminsk/InstallWinget-V2/main/Install-WingetV2.ps1';
        $script=Join-Path $env:TEMP 'Install-WingetV2.ps1';
        Invoke-WebRequest -UseBasicParsing -Uri $url -OutFile $script;
        & $script;
        winget --version
      "
    </Command>
  </LogonCommand>
</Configuration>
```

### B) Install apps from a simple config.yaml
Create a minimal `config.yaml` with the app Ids you want to install (Ids are from `winget search`, e.g., `Microsoft.VisualStudioCode`).

```yaml
properties:
  configurationVersion: 0.2.0
  resources:
    - resource: Microsoft.WinGet.DSC/WinGetPackage
      id: installVSCode
      directives:
        description: "Install Visual Studio Code"
      settings:
        id: Microsoft.VisualStudioCode
        source: winget
```

After running this script (to ensure winget is present), run:

```powershell
$url2 = 'https://raw.githubusercontent.com/kkaminsk/InstallWinget-V2/main/YAMLExample/config.yaml'
$script2 = Join-Path $env:TEMP 'config.yaml'
Invoke-WebRequest -Uri $url2 -OutFile $script2

winget configure -f $script2
```

Tip: You can combine this with Windows Sandbox by mapping a host folder that contains both `Install-WingetV2.ps1` and `config.yaml`, then referencing them from the sandbox Desktop path (for example: `$env:USERPROFILE\Desktop\InstallWinget-V2`).
