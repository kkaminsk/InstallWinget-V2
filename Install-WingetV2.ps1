<#
.SYNOPSIS
    Installs Windows Package Manager (Winget) and its dependencies on systems without Winget pre-installed.

.DESCRIPTION
    This script automates the installation of Windows Package Manager (Winget) and its entire dependency chain
    on systems that do not have Winget or its dependencies pre-installed, such as clean installations of 
    Windows Server 2025. The script leverages the Microsoft.WinGet.Client PowerShell module and its 
    Repair-WinGetPackageManager cmdlet to bootstrap Winget installation.

.PARAMETER IncludePrerelease
    Switch parameter to install the latest preview version of Winget.

.PARAMETER LogPath
    Optional string parameter to specify a custom path for the log file.
    Default: %temp%\Install-WingetV2.log

.EXAMPLE
    .\Install-WingetV2.ps1
    Standard installation of Winget with default logging.

.EXAMPLE
    .\Install-WingetV2.ps1 -IncludePrerelease
    Install the latest preview version of Winget.

.EXAMPLE
    .\Install-WingetV2.ps1 -IncludePrerelease -LogPath "C:\Logs\Winget-Install.log"
    Install preview version with custom log file location.

.NOTES
    Version: 1.0
    Author: Generated from specification
    Date: September 20, 2025
    
    Requirements:
    - Windows 10 version 1809 or later, or Windows Server 2022 or later
    - PowerShell 5.1 or higher
    - Administrative privileges
    - Internet connectivity

.LINK
    https://github.com/microsoft/winget-cli
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [switch]$IncludePrerelease,
    
    [Parameter(Mandatory = $false)]
    [string]$LogPath = (Join-Path $env:TEMP "Install-WingetV2.log")
)

# Global variables
$script:LogPath = $LogPath
$script:StartTime = Get-Date

#region Helper Functions

function Write-Log {
    <#
    .SYNOPSIS
        Writes messages to both console and log file with timestamps.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Message,
        
        [Parameter(Mandatory = $false)]
        [ValidateSet("INFO", "WARNING", "ERROR", "SUCCESS")]
        [string]$Level = "INFO"
    )
    
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logEntry = "[$timestamp] [$Level] $Message"
    
    # Write to console with color coding
    switch ($Level) {
        "INFO"    { Write-Host $logEntry -ForegroundColor White }
        "WARNING" { Write-Host $logEntry -ForegroundColor Yellow }
        "ERROR"   { Write-Host $logEntry -ForegroundColor Red }
        "SUCCESS" { Write-Host $logEntry -ForegroundColor Green }
    }
    
    # Write to log file
    try {
        # Ensure the log directory exists before writing
        $logDirectory = Split-Path -Path $script:LogPath -Parent
        if (-not (Test-Path -Path $logDirectory)) {
            New-Item -ItemType Directory -Path $logDirectory -Force -ErrorAction Stop | Out-Null
        }
        Add-Content -Path $script:LogPath -Value $logEntry -ErrorAction Stop
    }
    catch {
        Write-Warning "Failed to write to log file: $_"
    }
}

function Test-Prerequisites {
    <#
    .SYNOPSIS
        Performs all prerequisite checks before installation.
    #>
    [CmdletBinding()]
    param()
    
    Write-Log "Starting prerequisite checks..." -Level "INFO"
    
    # Check if running as administrator
    $currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
    if (-not $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
        Write-Log "Script must be run as Administrator. Please restart PowerShell as Administrator." -Level "ERROR"
        return $false
    }
    Write-Log "Administrative privileges confirmed." -Level "SUCCESS"
    
    # Check PowerShell version
    if ($PSVersionTable.PSVersion.Major -lt 5 -or ($PSVersionTable.PSVersion.Major -eq 5 -and $PSVersionTable.PSVersion.Minor -lt 1)) {
        Write-Log "PowerShell version 5.1 or higher is required. Current version: $($PSVersionTable.PSVersion)" -Level "ERROR"
        return $false
    }
    Write-Log "PowerShell version check passed: $($PSVersionTable.PSVersion)" -Level "SUCCESS"
    
    # Check Windows version
    $osVersion = [System.Environment]::OSVersion.Version
    $buildNumber = (Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion").CurrentBuildNumber
    
    # Windows 10 1809 = build 17763, Windows Server 2022 = build 20348
    if ([int]$buildNumber -lt 17763) {
        Write-Log "Windows 10 version 1809 (build 17763) or Windows Server 2022 or later is required. Current build: $buildNumber" -Level "ERROR"
        return $false
    }
    Write-Log "Windows version check passed: Build $buildNumber" -Level "SUCCESS"
    
    # Check execution policy
    $executionPolicy = Get-ExecutionPolicy
    if ($executionPolicy -eq "Restricted") {
        Write-Log "Execution policy is set to Restricted. Please run 'Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser' to allow script execution." -Level "ERROR"
        return $false
    }
    Write-Log "Execution policy check passed: $executionPolicy" -Level "SUCCESS"
    
    Write-Log "All prerequisite checks completed successfully." -Level "SUCCESS"
    return $true
}

function Install-NuGetProvider {
    <#
    .SYNOPSIS
        Installs the NuGet package provider if it is not already present, ensuring non-interactive execution.
    #>
    [CmdletBinding()]
    param()

    Write-Log "Checking NuGet package provider..." -Level "INFO"

    try {
        if (Get-PackageProvider -Name "NuGet" -ErrorAction SilentlyContinue) {
            Write-Log "NuGet provider is already installed." -Level "SUCCESS"
            return $true
        }

        Write-Log "NuGet provider not found. Installing..." -Level "INFO"
        
        Install-PackageProvider -Name "NuGet" -Force -Confirm:$false -ErrorAction Stop
        
        Write-Log "NuGet provider installed successfully." -Level "SUCCESS"
        return $true
    }
    catch {
        Write-Log "Failed to install NuGet package provider: $_" -Level "ERROR"
        return $false
    }
}

function Install-WinGetModule {
    <#
    .SYNOPSIS
        Installs Microsoft.WinGet.Client module if not already present.
    #>
    [CmdletBinding()]
    param()
    
    Write-Log "Checking Microsoft.WinGet.Client module..." -Level "INFO"
    
    try {
        $wingetModule = Get-Module -Name "Microsoft.WinGet.Client" -ListAvailable -ErrorAction SilentlyContinue
        if ($wingetModule) {
            Write-Log "Microsoft.WinGet.Client module is already installed (Version: $($wingetModule.Version))" -Level "SUCCESS"
            return $true
        }
        
        Write-Log "Installing Microsoft.WinGet.Client module..." -Level "INFO"
        
        # Set PSGallery as trusted to avoid prompts during automation
        $gallery = Get-PSRepository -Name "PSGallery" -ErrorAction SilentlyContinue
        if ($gallery -and $gallery.InstallationPolicy -ne "Trusted") {
            $oldConfirmPreference = $ConfirmPreference
            $ConfirmPreference = 'None'
            Set-PSRepository -Name "PSGallery" -InstallationPolicy Trusted -ErrorAction Stop
            $ConfirmPreference = $oldConfirmPreference
            Write-Log "Set PSGallery as trusted repository." -Level "INFO"
        }
        
        $oldConfirmPreference = $ConfirmPreference
        $ConfirmPreference = 'None'
        Install-Module -Name "Microsoft.WinGet.Client" -Scope AllUsers -Force -ErrorAction Stop
        $ConfirmPreference = $oldConfirmPreference
        Write-Log "Microsoft.WinGet.Client module installed successfully." -Level "SUCCESS"
        return $true
    }
    catch {
        Write-Log "Failed to install Microsoft.WinGet.Client module: $_" -Level "ERROR"
        return $false
    }
}

function Install-WinGet {
    <#
    .SYNOPSIS
        Installs Winget using the Repair-WinGetPackageManager cmdlet.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [switch]$IncludePrerelease
    )
    
    Write-Log "Starting Winget installation..." -Level "INFO"
    
    try {
        # Import the module
        Import-Module Microsoft.WinGet.Client -Force -ErrorAction Stop
        Write-Log "Microsoft.WinGet.Client module imported successfully." -Level "SUCCESS"
        
        # Prepare parameters for Repair-WinGetPackageManager
        $repairParams = @{
            Force = $true
            AllUsers = $true
        }
        
        if ($IncludePrerelease) {
            $repairParams.Add("IncludePrerelease", $true)
            Write-Log "Including prerelease version in installation." -Level "INFO"
        }
        
        Write-Log "Executing Repair-WinGetPackageManager to install Winget and dependencies..." -Level "INFO"
        Write-Log "This may take several minutes as it downloads and installs multiple components..." -Level "INFO"
        
        # Execute the repair command
        try {
            Repair-WinGetPackageManager @repairParams -ErrorAction Stop
            Write-Log "Winget installation completed successfully." -Level "SUCCESS"
        }
        catch {
            Write-Log "Repair-WinGetPackageManager reported an error: $_" -Level "WARNING"
            Write-Log "Checking if Winget was installed despite the error..." -Level "INFO"
        }
        
        # Always verify Winget installation regardless of repair command result
        # Sometimes the repair command reports errors but Winget still gets installed
        Start-Sleep -Seconds 3  # Give Windows time to register the installation
        
        # Test if winget command is available
        $wingetPath = Get-Command "winget" -ErrorAction SilentlyContinue
        if ($wingetPath) {
            Write-Log "Winget installation verification successful." -Level "SUCCESS"
            return $true
        }
        
        # If not found in PATH, check common installation locations
        $commonPaths = @(
            "$env:LOCALAPPDATA\Microsoft\WindowsApps\winget.exe",
            "$env:ProgramFiles\WindowsApps\Microsoft.DesktopAppInstaller*\winget.exe"
        )
        
        foreach ($path in $commonPaths) {
            $resolvedPaths = Get-ChildItem -Path $path -ErrorAction SilentlyContinue
            if ($resolvedPaths) {
                Write-Log "Winget found at: $($resolvedPaths[0].FullName)" -Level "SUCCESS"
                return $true
            }
        }
        
        Write-Log "Winget installation verification failed - Winget not found." -Level "ERROR"
        return $false
    }
    catch {
        Write-Log "Unexpected error during Winget installation: $_" -Level "ERROR"
        return $false
    }
}

function Test-WinGetInstallation {
    <#
    .SYNOPSIS
        Verifies that Winget is properly installed and functional.
    #>
    [CmdletBinding()]
    param()
    
    Write-Log "Verifying Winget installation..." -Level "INFO"
    
    try {
        # Test if winget command is available
        $wingetPath = Get-Command "winget" -ErrorAction SilentlyContinue
        if (-not $wingetPath) {
            Write-Log "Winget command not found in PATH." -Level "ERROR"
            return $false
        }
        
        # Test winget version command
        $versionOutput = & winget --version 2>&1
        if ($LASTEXITCODE -eq 0) {
            Write-Log "Winget is functional. Version: $versionOutput" -Level "SUCCESS"
            return $true
        }
        else {
            Write-Log "Winget command failed with exit code: $LASTEXITCODE" -Level "ERROR"
            return $false
        }
    }
    catch {
        Write-Log "Error during Winget verification: $_" -Level "ERROR"
        return $false
    }
}

#endregion

#region Main Execution

function Main {
    <#
    .SYNOPSIS
        Main execution function that orchestrates the installation process.
    #>
    [CmdletBinding()]
    param()
    
    try {
        # Initialize logging
        Write-Log "=== Install-WingetV2.ps1 Started ===" -Level "INFO"
        Write-Log "Log file: $script:LogPath" -Level "INFO"
        Write-Log "Include Prerelease: $IncludePrerelease" -Level "INFO"
        
        # Step 1: Run prerequisite checks
        if (-not (Test-Prerequisites)) {
            Write-Log "Prerequisite checks failed. Installation cannot continue." -Level "ERROR"
            exit 1
        }
        
        # Step 2: Check if Winget is already installed (idempotency check)
        if (Test-WinGetInstallation) {
            Write-Log "Winget is already installed and functional. No action needed." -Level "SUCCESS"
            Write-Log "=== Install-WingetV2.ps1 Completed Successfully ===" -Level "SUCCESS"
            exit 0
        }
        
        # Step 3: Install NuGet provider
        if (-not (Install-NuGetProvider)) {
            Write-Log "Failed to install NuGet provider. Installation cannot continue." -Level "ERROR"
            exit 1
        }
        
        # Step 4: Install Microsoft.WinGet.Client module
        if (-not (Install-WinGetModule)) {
            Write-Log "Failed to install Microsoft.WinGet.Client module. Installation cannot continue." -Level "ERROR"
            exit 1
        }
        
        # Step 5: Install Winget
        if (-not (Install-WinGet -IncludePrerelease:$IncludePrerelease)) {
            Write-Log "Failed to install Winget. Installation failed." -Level "ERROR"
            exit 1
        }
        
        # Step 6: Final verification
        if (-not (Test-WinGetInstallation)) {
            Write-Log "Winget installation verification failed." -Level "ERROR"
            exit 1
        }
        
        # Success
        $duration = (Get-Date) - $script:StartTime
        Write-Log "Installation completed successfully in $($duration.TotalMinutes.ToString('F2')) minutes." -Level "SUCCESS"
        Write-Log "=== Install-WingetV2.ps1 Completed Successfully ===" -Level "SUCCESS"
        exit 0
    }
    catch {
        Write-Log "Unexpected error during installation: $_" -Level "ERROR"
        Write-Log "=== Install-WingetV2.ps1 Failed ===" -Level "ERROR"
        exit 1
    }
}

#endregion

# Execute main function
Main
