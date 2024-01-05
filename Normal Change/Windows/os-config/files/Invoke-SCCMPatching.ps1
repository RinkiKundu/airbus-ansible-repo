<#

	.SYNOPSIS
    Script to invoke Manual Patching TS

	.DESCRIPTION
    The script will start the SCCM CB Task Sequence
    to perform the manual patching on the servers

    .PARAMETER ScriptName
    Name of the script for logfile

    .PARAMETER LogPath
    Path where the log file will be saved

    .PARAMETER Transcript
    Enable the Transcript of the script excecution

    .PARAMETER WhatIf
    Simulate the operation

    .EXITCODES
    0       - Operation Completed with Success
    9001    - Generic Failure
    9101    - Script is not running under administrator User
    9201    - DLL not found
    9202    - TS Not Found
    9203    - Failed to start TS


    Created by: Giancarlo Pannullo
    Contact:    Giancarlo.Pannullo@atos.net

    Team:       Airbus ABC Patching team
    Email:      MS-AIRBUS-ABC-PATCHING@atos.net

    Version:    1.0

    .VERSION HISTORY
    Ver 1.1 - 20/05/2020
        -	Added DLL Check

    Ver 1.0 - 03/04/2020
        -	Initial Version

#>

[CmdletBinding()]
param (

    [Parameter(Mandatory = $false)]
    [String]$ScriptName = "Invoke_ManualPatching",

    [Parameter(Mandatory = $false)]
    [String]$LogPath = "C:\LOGS\Softs\SCCM",

    [Parameter(Mandatory = $false)]
    [String]$TSPkgName = "AtoS ABC - Server Patching",

    [Parameter(Mandatory = $false)]
    [String]$SMSDLLPath = "C:\temp\manualpatch\smsclictr.automation.DLL",

    [Parameter(Mandatory = $false)]
    [Switch]$Transcript,

    [Parameter(Mandatory = $false)]
    [Switch]$WhatIf

)

[String]$LogFile = ("{0}\{1}.log" -f $LogPath.TrimEnd("\"), $ScriptName)
[String]$TranscriptFile = ("{0}\{1}_transcript.log" -f $LogPath.TrimEnd("\"), $ScriptName)
$ComputerFQDN = ("{0}.{1}" -f $ENV:COMPUTERNAME, $ENV:USERDOMAIN)
$Computername = $ENV:COMPUTERNAME
$CurrentOSDetails = [Environment]::OSVersion
$RefreshTime = "60"

#region Log / Trap / Transcript
Write-Verbose ("[Log File] - Target Log file {0}" -f $LogFile)
Write-Verbose ("[Transcript File] - Target Transcript file {0}" -f $TranscriptFile)
Function Write-LogFile ($InputText) {

    [string]$TextToLog = "[{0}] - {1}" -f $(Get-Date -Format "dd/MM/yyyy - HH:mm:ss"), $InputText
    $TextToLog | Add-Content -Path $LogFile

}

if (-not (Test-Path -Path $LogPath)) {

    Write-Verbose ("[Log Folder] - Creating LogFolder: {0}" -f $LogPath)
    New-Item -Type Directory -Force -Path $LogPath | Out-Null

}

if ($Transcript) {

    Start-Transcript -Path $TranscriptFile

}

if (-Not (Test-Path -Path $LogFile) ) {

    Write-LogFile -InputText ""
    Write-LogFile -InputText "==========================================================================================================="
    Write-LogFile -InputText ("Starting {0}" -f $ScriptName)
    Write-LogFile -InputText "==========================================================================================================="
    Write-LogFile -InputText ""
    Write-LogFile -InputText ("Hostname: {0} | FQDN: {1} | OS: {2}" -f $ENV:COMPUTERNAME, $ComputerFQDN, $CurrentOSDetails.Version.ToString())
    Write-LogFile -InputText ""

}
Else {

    Write-Verbose ("[Log Folder] - Starting LogFile: {0}" -f $LogFile)
    Write-LogFile -InputText ""
    Write-LogFile -InputText "==========================================================================================================="
    Write-LogFile -InputText ("Starting {0}" -f $ScriptName)
    Write-LogFile -InputText "==========================================================================================================="
    Write-LogFile -InputText ""

}


$ADMCheck = New-Object Security.Principal.WindowsPrincipal( [Security.Principal.WindowsIdentity]::GetCurrent() )
[bool]$IsADM = $ADMCheck.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

if ($IsADM -eq $False) {

    Write-LogFile -InputText "Admin Check: Current user is not on Administrator built in group"
    Write-Warning "PS is not running as Administrator"
    $ExitCode = "9101"
    Write-LogFile -InputText ("Admin Check: Exiting with code {0}" -f $ExitCode)
    [Environment]::Exit($ExitCode)

}

$OSBuild = (Get-WmiObject -class Win32_OperatingSystem -ErrorAction SilentlyContinue).version
switch -wildcard ($OSBuild) {

    "6.1.*" { $OSVersion = "2008R2" }  # W2008R2
    "6.2.*" { $OSVersion = "2012" }    # W2012
    "6.3.*" { $OSVersion = "2012R2" }  # W2012R2
    "10.0.14*" { $OSVersion = "2016" }    # W2016
    "10.0.17*" { $OSVersion = "2019" }    # W2019

    Default {

        $OSVersion = "Null"

    }

}
Write-LogFile -InputText ("OS Build: Current OS version {0}" -f $OSVersion)

Trap {

    $ExitCode = "9001"
    Write-LogFile -InputText ("Error: Critical unrecognized error found {0} | code {1}" -f $_ , $ExitCode)
    Write-LogFile -InputText ("__ Exception:   {0}" -f $_.Exception.ToString() )
    Write-LogFile -InputText ("__ Message:     {0}" -f $_.Exception.Message )
    Write-LogFile -InputText ("__ ExitCode:    {0}" -f $ExitCode)
    [Environment]::Exit($ExitCode)

}
#endregion Log / Trap / Transcript

If (Test-Path -Path $SMSDLLPath) { # Load the .DLL locally to be able manage SMS Client from CLI

    Add-Type -Path $SMSDLLPath
    Write-LogFile -InputText "SCCM DLL: Loaded"
    $ReRun = New-Object -TypeName smsclictr.automation.SMSClient($Computername)

    # Request to refresh the machine policy to have the last packages and wait 30 Seconds to let the server download the policies
    Write-LogFile -InputText ("SCCM Policies: Starting Policy refresh... waiting {0} seconds" -f $RefreshTime)
    $ReRun.RequestMachinePolicy()
    Write-Host ("Waiting {0} Seconds to refresh the policies" -f $RefreshTime)
    Start-Sleep -seconds $RefreshTime
    Write-LogFile -InputText "SCCM Policies: Starting Policy refreshed"

    $Adv = $ReRun.SoftwareDistribution.Advertisements
    $AtoSTS = $Adv | Where-Object { $_.PKG_Name -eq $TSPkgName } | Select-object PRG_ProgramID, PRG_ProgramName, ADV_AdvertisementID, PKG_PackageID, PKG_Name

    $AdvID = $ATOSTS.Adv_AdvertisementID
    $PkgID = $ATOSTS.PKG_PackageID
    Write-Host ("ADV: {0} | PkgID: {1}" -f $AdvID, $PkgID)

    if ($AtoSTS) {

        Write-LogFile -InputText "SCCM TS: Package found!"
        Write-LogFile -InputText ("__ TS: {0}" -f $AdvID)
        Write-LogFile -InputText ("__ PKG: {0}" -f $PkgID)

        Write-Host ("Invoking TS {0}" -f $AdvID)
        Write-LogFile -InputText "SCCM TS: Starting TS"

        try {

            if ($WhatIf) {

                Write-Host ("WhatIf: Starting Advertisement {0} with Package ID {1}" -f $AdvID, $PkgID)

            }
            else {

                $ReRun.SoftwareDistribution.RerunAdv($AdvID, $PkgID, "*")

            }

            Start-Sleep -Seconds 10 # Wait time for TS service be started
            Write-Host "TaskSequence is started..."

            Write-LogFile -InputText ("SCCM TS: TS has been started | TS Service is {0}" -f $(Get-service -Name smstsmgr -ErrorAction SilentlyContinue).Status )
            $ExitCode = "0"

        }
        catch {

            Write-Warning ("Failed to launch TS Due {0}" -f $_.Exception.Message)
            $ExitCode = "9203"

        }

        [Environment]::Exit($ExitCode)

    }
    Else {

        Write-LogFile -InputText "SCCM TS: Package not found! ... closing"
        Write-Warning "TS Not found...skipping TS Operation"
        $ExitCode = "9202"
        [Environment]::Exit($ExitCode)

    }

}
else {

    Write-LogFile -InputText ("SMSDLL: DLL not found on {0}! ... closing" -f $SMSDLLPath)
    Write-Warning "SMS DLL Not found...skipping Operation"
    $ExitCode = "9201"
    [Environment]::Exit($ExitCode)

}
