# **Application Specification: PowerShell Script for Winget Installation**

**Version:** 1.0

**Date:** September 20, 2025

**Author:** Gemini

## **1\. Introduction**

### **1.1. Purpose**

This document outlines the functional and non-functional requirements for a PowerShell script, Install-WingetV2.ps1. The script's primary purpose is to automate the installation of the Windows Package Manager (Winget) and its entire dependency chain on systems that do not have Winget or its dependencies pre-installed, such as clean installations of Windows Server 2025\.

### **1.2. Scope**

The script will be a self-contained solution for bootstrapping Winget. It will handle prerequisite checks, installation of the necessary PowerShell module, and the execution of commands to install Winget and the Windows App SDK Runtime. The script is designed for use by system administrators in automated deployment scenarios.

### **1.3. Background**

As detailed in the "Analysis of the Windows Package Manager's Evolving Dependency Architecture," newer versions of Winget have transitioned to a dependency on the Windows App SDK Runtime. This script will leverage the Microsoft.WinGet.Client PowerShell module and its Repair-WinGetPackageManager cmdlet, which acts as a bootstrapping engine to install Winget and all its modern dependencies.

## **2\. Functional Requirements**

### **2.1. Prerequisite Checks**

The script must perform the following checks before proceeding with the installation:

* **Operating System:** Verify that the script is running on a compatible version of Windows (Windows 10 version 1809 or later, or Windows Server 2022 or later).  
* **PowerShell Version:** Ensure that the PowerShell version is 5.1 or higher.  
* **Execution Policy:** Check if the execution policy allows for running local scripts. If not, the script should notify the user with instructions on how to change it.  
* **Administrative Privileges:** Ensure the script is executed in an elevated PowerShell session (as an administrator).

### **2.2. Installation of Microsoft.WinGet.Client Module**

The script must be able to install Microsoft.WinGet.Client module from the PowerShell Gallery. This includes:

* Detecting if the module is already installed.  
* If not installed, install the module for all users.  
* Handling the installation of the NuGet package provider if it is not already present.

### **2.3. Winget Installation**

The core functionality of the script is to install Winget using the Repair-WinGetPackageManager cmdlet. The script will:

* Execute Repair-WinGetPackageManager to trigger the download and installation of Winget (Microsoft.DesktopAppInstaller) and its dependencies.  
* Include an option to install the prerelease version of Winget to ensure the latest version with the Windows App SDK dependency is installed.

### **2.4. Error Handling and Logging**

The script must include robust error handling and logging capabilities:

* The script should use try/catch blocks for all major operations.  
* All actions, errors, and warnings should be logged to the console and to a log file in the system %temp% folder called Install-WingetV2.log.
* The script should provide clear and actionable error messages.

## **3\. Non-Functional Requirements**

### **3.1. Idempotency**

The script should be idempotent, meaning it can be run multiple times on the same system without changing the outcome after the initial successful installation.

### **3.2. Automation Support**

The script must be able to run non-interactively to support automated deployment tools like Microsoft Intune, SCCM, or custom startup scripts.

### **3.3. Security**

The script will rely on the official PowerShell Gallery for module installation, which is a trusted repository.

## **4\. Dependency Manifest**

Based on the provided analysis, the script will facilitate the installation of the following packages on a clean system:

* **Primary Application:**  
  * Microsoft.DesktopAppInstaller  
* **Windows App SDK Runtime Components:**  
  * Microsoft.WindowsAppRuntime (Framework)  
  * Microsoft.WindowsAppSDK.Main (Main)  
  * Microsoft.WindowsAppSDK.Singleton (Singleton)  
  * Microsoft.WindowsAppSDK.DDLM (for the appropriate architecture)  
* **Other Dependencies:**  
  * Microsoft.VCLibs (Visual C++ Runtime)

## **5\. Script Parameters**

The script should support the following parameters:

* \-IncludePrerelease: A switch parameter to install the latest preview version of Winget.  
* \-LogPath: An optional string parameter to specify a path for a log file.

## **6\. Example Usage**

### **6.1. Standard Installation**

.\\Install-WingetV2.ps1

### **6.2. Prerelease Installation with Logging**

.\\Install-WingetV2.ps1 \-IncludePrerelease \-LogPath "C:\\Logs\\Winget-Install.log"  
