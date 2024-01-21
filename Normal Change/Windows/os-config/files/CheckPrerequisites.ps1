#==========================================================================
# LANGUAGE       : PowerShell (v.2+)
# TEMPLATEID     : 2019-10-14
# AUTHOR         : COC - DIP10
# DATE           : 2020-09-28
# Script VERSION : 1.8
#
# DESCRIPTION   : Check Prerequisites before upgrade
#
# Exit codes:
<#
CoC exit codes (>=19999)

    === #region Preparation ===
    20100 = Not administrator
    20200 = Can't find '$XMLFile'
    20210 = Error when read '$XMLFile' file.
    20220 = Unsupported OS
    20666 = Other errors 
    1010011010 = other instance of this script is running

    === region AllActions ===
    21010 = Cluster service (ClusSvc) found. The target host is a member of an MSCS cluster.
    21020 = At least one SQL instance installed on the target host is too old, an SQL upgrade is required before the Windows upgrade.
    21030 = Not enough free space on the system (C:) disk. At least '20' GB of free space is required for upgrade.
    21040 = Disk 'D:' does not exist or it is not a type '3' (Local hard disk).
    21050 = Not enough free space on the D: disk. At least '30' GB of free space is required for upgrade.

    === region Finalization ===

#>
<#
ChangeLog:
1.8 2020-09-28
- Add 'Total disk size' and 'Free space' information to the errors 21030 and 21050.


1.7 2020-06-04
- Change diskspace minimum to 30GB

1.6 2020-04-17
- Add 'generic' catch to SQL check

1.5 2020-04-06
- Script will end if OS version in not '6.1.*' (W2008R2)

1.4 2020-04-06
- Add "dedicated" exit codes if the prerequisite is not met.
  21010 = Cluster service (ClusSvc) found. The target host is a member of an MSCS cluster.
  21020 = At least one SQL instance installed on the target host is too old, an SQL upgrade is required before the Windows upgrade.
  21030 = Not enough free space on the system (C:) disk. At least '20' GB of free space is required for upgrade.
  21040 = Disk 'D:' does not exist or it is not a type '3' (Local hard disk).
  21050 = Not enough free space on the D: disk. At least '30' GB of free space is required for upgrade.

1.3 2020-03-30
- Add Prerequisites check:
    - Check if any SQL Instance with version < 11 exist

1.2 2020-02-19
- Add Prerequisites check:
    - Check if server is cluster

1.1 2019-12-03
- Add Prerequisites check:
	- Disk D: must exist
	- Disk D: must have at least 20GB free
#>   
#==========================================================================

#[CmdletBinding()]
param(
    $LogFile,
    $XMLFile,
    [switch]$StartTranscript = $false,
    $MasterLogFile,
    $FullCmdFileName
)

#=====================
#region Preparation
#=====================
$Message = "`n==== region Preparation ==="; Write-Host $Message -BackgroundColor White -ForegroundColor Black

#-------------------
# Set PS environment
#-------------------
Set-PSDebug -Strict
Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

#--------------------------
# Variables and Transcript.
#--------------------------
$PSExecutedFile = $MyInvocation.MyCommand.Path
[System.Console]::Title = $PSExecutedFile
$WorkDir = Split-Path -Path $PSExecutedFile -Parent
$PSFile  = Split-Path -Path $PSExecutedFile -Leaf
$LogDir  = Split-Path $LogFile -Parent
#$LogFileName = Split-Path -Path $LogFile -Leaf
$LogFileNameWithoutExtension = [io.path]::GetFileNameWithoutExtension($LogFile)

# Create $LogDir if not exist
if(!(Test-Path $LogDir)) {
	New-Item -Type Directory $LogDir
}

# Check if StartTranscript=$true
if ($StartTranscript) {
    # string 'Transcript' is mandatory in transcript file name!
    $TranscriptFile = "$LogDir\$LogFileNameWithoutExtension.Transcript.log" 
    try {Start-Transcript -Path $TranscriptFile}
    catch {
        $ExitCode = 1010011010
        $ErrorMessage = $_.Exception.Message
        $Message = "`nCommand {Start-Transcript -Path '$TranscriptFile'} return error."; Write-Host $Message -BackgroundColor White -ForegroundColor DarkRed
        $Message = "Error: '$ErrorMessage'"; Write-Host $Message -BackgroundColor White -ForegroundColor Red       
        $Message = "It seems that other instance of this script is running."; Write-Host $Message -BackgroundColor White -ForegroundColor DarkRed
        $Message = "Terminate all '$PSExecutedFile' instances and close this window.`n"; Write-Host $Message -BackgroundColor White -ForegroundColor DarkRed
        [Environment]::Exit($ExitCode)
    }
}

#++++++++++++
# Functions
#++++++++++++
# Add $Text to $Global:LogFile
Function Write-ToLog ($Text) {
    try {
        "{0} - {1}" -f "<$(get-date -Format "yyyy-MM-dd HH:mm:ss")>", $Text | Add-Content -LiteralPath $Global:LogFile -ErrorAction Stop
    }
    catch {
        Write-Host " <Write-ToLog>. ExceptionMessage: $($_.Exception.Message)" -ForegroundColor DarkYellow
    }
}

Function Write-ToMasterLog ($Text) {
    try {
        "{0} - {1}" -f "<$(get-date -Format "yyyy-MM-dd HH:mm:ss")>", $Text | Add-Content -LiteralPath $Global:MasterLogFile -ErrorAction Stop
    }
    catch {
        Write-Host " <Write-ToMasterLog>. ExceptionMessage: $($_.Exception.Message)" -ForegroundColor DarkYellow
    }
}

# First write to log
Write-ToLog -Text "Start $PSExecutedFile"
Write-ToLog -Text "==== region Preparation ==="

# If terminating error
Trap {
    $_
    $ExitCode = 20666
    $Message = "`nUnknown error trapped. See transcript for more information. Exit $ExitCode."; Write-ToLog -Text $Message; Write-Host $Message -ForegroundColor Red
    $Message = "Transcript file: '$TranscriptFile'."; Write-ToLog -Text $Message; Write-Host $Message
    [Environment]::Exit($ExitCode)
}

#-------------------
# Host and User info
#-------------------
#$ComputerSystem = Get-WMIObject -class Win32_ComputerSystem
$mkHost = "$($env:COMPUTERNAME).$($env:USERDOMAIN)"
Write-ToLog -Text "Host: $mkHost"
Write-ToLog -Text "Logged user: $($env:USERNAME)"
$RunAsUser = [System.Security.Principal.WindowsIdentity]::GetCurrent()
Write-ToLog -Text "Run As User: $($RunAsUser.Name)"

# Check for elevation
If (-NOT ([Security.Principal.WindowsPrincipal] $RunAsUser).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator"))
{
    $ExitCode = 20100
    Write-Host "You need to run this script as an local Administrator!" -ForegroundColor Red
    Write-ToLog -Text "You need to run this script as an local Administrator!"
    Write-ToLog -Text "Aborting script..."
    Write-ToLog -Text "PS Error! Exit $ExitCode."
    [Environment]::Exit($ExitCode)
}

Write-ToLog -Text "'$($RunAsUser.Name)' account has the local Administrator rights on the '$mkHost' computer."

#--------------------------------------------------------------------------
# Read xml file.
#--------------------------------------------------------------------------
# $WorkDir = ''
# $XMLFile = '\\fr-vfiler166\install_ws\CoC\OS\Windows server\Changes\2019\_WindowsMigration\StartMigration.xml'

$Message = "`nTry to read '$XMLFile' file..."; Write-ToLog -Text $Message; Write-Host $Message -ForegroundColor Magenta
if (-not (Test-Path -Path $XMLFile -PathType Leaf)) {
    $ExitCode = 20200
    $Message = "Error! Can't find '$XMLFile'. Exit $ExitCode."; Write-ToLog -Text $Message; Write-Host $Message
    [Environment]::Exit($ExitCode)
}

try {
    [xml]$XML = Get-Content -Path $XMLFile -ErrorAction Stop
} 
catch {
    $ExitCode = 20210
    $ErrorMessage = $_.Exception.Message
    $Message = "Error when read '$XMLFile' file. Error message: {$ErrorMessage}. Exit $ExitCode."; Write-ToLog -Text $Message; Write-Host $Message
    [Environment]::Exit($ExitCode)
}
$Message = "File '$XMLFile' read."; Write-ToLog -Text $Message; Write-Host $Message

#-------------------------
# ToDo? Validate xml file
#-------------------------

#-------------------------
# Package variables
#-------------------------
$SoftShortName = $XML.Root.PackageVariables.SoftShortName
$SoftLongName = $XML.Root.PackageVariables.SoftLongName
$SoftVersion = $XML.Root.PackageVariables.SoftVersion
#[int]$intSoftVersion = $SoftVersion -replace "\.","" # convert to integer

$Message = "`nGet ATREF Package ID from xml file (.Root.PackageVariables.ATREF...)."; Write-ToLog -Text $Message; Write-Host $Message -ForegroundColor Magenta
try {$ATREF_2008R2 = $XML.Root.PackageVariables.ATREF.W2008R2} catch {$ErrorMessage = $_.Exception.Message; $Message = "Warning: {$ErrorMessage}."; Write-ToLog -Text $Message; Write-Host $Message -ForegroundColor Yellow  }
try {$ATREF_2012   = $XML.Root.PackageVariables.ATREF.W2012}   catch {$ErrorMessage = $_.Exception.Message; $Message = "Warning: {$ErrorMessage}."; Write-ToLog -Text $Message; Write-Host $Message -ForegroundColor Yellow  }
try {$ATREF_2012R2 = $XML.Root.PackageVariables.ATREF.W2012R2} catch {$ErrorMessage = $_.Exception.Message; $Message = "Warning: {$ErrorMessage}."; Write-ToLog -Text $Message; Write-Host $Message -ForegroundColor Yellow  }
try {$ATREF_2016   = $XML.Root.PackageVariables.ATREF.W2016}   catch {$ErrorMessage = $_.Exception.Message; $Message = "Warning: {$ErrorMessage}."; Write-ToLog -Text $Message; Write-Host $Message -ForegroundColor Yellow  }
try {$ATREF_2019   = $XML.Root.PackageVariables.ATREF.W2019}   catch {$ErrorMessage = $_.Exception.Message; $Message = "Warning: {$ErrorMessage}."; Write-ToLog -Text $Message; Write-Host $Message -ForegroundColor Yellow  }

#$OSVersion = (Get-WmiObject -class Win32_OperatingSystem).version
#$OSVersion = (Get-CimInstance -ClassName Win32_OperatingSystem).Version # Error on Windows 2008R2 with PS6.2.3
$OSVersionOutput = wmic os get version
#$OSVersion = $OSVersionOutput[2]
$OSVersion = $OSVersionOutput -match '^\d'

switch -wildcard  ($OSVersion) {
    "6.1.*" {$ATRefPID  = $ATREF_2008R2; break} # W2008R2
    #"6.2.*" {$ATRefPID  = $ATREF_2012;   break} # W2012
    #"6.3.*" {$ATRefPID  = $ATREF_2012R2; break} # W2012R2
    #"10.0.14*" {$ATRefPID = $ATREF_2016;   break} # W2016
    #"10.0.17*" {$ATRefPID = $ATREF_2019;   break} # W2019
    Default {
       $ExitCode = 20220
       $Message = "Unsupported OS. OS version: '$OSVersion'. Exit $ExitCode"
       Write-ToLog -Text $Message; Write-Host $Message -ForegroundColor Red
       [Environment]::Exit($ExitCode)
    }
}
$Message = "OS version: $OSVersion"; Write-ToLog -Text $Message; Write-Host $Message
$Message = "ATRefPID: $ATRefPID"; Write-ToLog -Text $Message; Write-Host $Message

#endregion Preparation
#=====================

#=====================
#region AllActions
#=====================
$Message = "`n==== region AllActions ==="; Write-ToLog -Text $Message; Write-Host $Message -BackgroundColor White -ForegroundColor Black
$PrerequisitesOK = $true

#--------------------------------------------------------------
# 10. Check if a server is clustered or stand-alone
#--------------------------------------------------------------
$Message = "`nCheck if a server is clustered or stand-alone..."; Write-ToLog -Text $Message; Write-Host $Message -ForegroundColor Magenta

# Method 1
$ServiceName = 'ClusSvc'
$ClusterService = Get-Service -Name $ServiceName -ErrorAction Continue
if ($ClusterService) {
    $ExitCode = 21010
    $Message = "Automated in-place upgrade is not supported for clusters. You must remove cluster node first."; Write-ToLog -Text $Message; Write-Host $Message -ForegroundColor Yellow
    $Message = "Service '$ServiceName' found. The target host is a member of an MSCS cluster. Exit '$ExitCode'."; Write-ToLog -Text $Message; Write-Host $Message -ForegroundColor Yellow
    [Environment]::Exit($ExitCode)
    $PrerequisitesOK = $false
}
else {
    $Message = "Service '$ServiceName' is NOT found. Continue prerequisites check..."; Write-ToLog -Text $Message; Write-Host $Message
}

#----------- 2020-03-26 ---------------------------
# 20. Check if any SQL Instance with version < 11 exist
#--------------------------------------------------
$Message = "`nCheck if any SQL Instance with version < 11 exist..."; Write-ToLog -Text $Message; Write-Host $Message -ForegroundColor Magenta
$SQLPrerequisitesOK = $true

# Get all SQL instances
$RegKey = 'HKLM:\SOFTWARE\Microsoft\Microsoft SQL Server'
$AllSQLInstances = @()
$Message = "Try to get all SQL instances from RegKey: '$RegKey'"; Write-ToLog -Text $Message; Write-Host $Message
try {
    $AllSQLInstances = (Get-ItemProperty -Path $RegKey -ErrorAction Stop).InstalledInstances
}
catch [System.Management.Automation.ItemNotFoundException] {
    $Message = "'ItemNotFoundException' caught"; Write-ToLog -Text $Message; Write-Host $Message
    $ErrorMessage = $_.Exception.Message
    $Message = $ErrorMessage; Write-ToLog -Text $Message; Write-Host $Message
}
# 2020-04-17
catch {
    $Message = "Exception caught"; Write-ToLog -Text $Message; Write-Host $Message
    $ErrorMessage = $_.Exception.Message
    $Message = $ErrorMessage; Write-ToLog -Text $Message; Write-Host $Message
}

$AllSQLInstancesCount = $AllSQLInstances.Count
$Message = "'$AllSQLInstancesCount' SQL instances found on this server"; Write-ToLog -Text $Message; Write-Host $Message
$i=0
if ($AllSQLInstancesCount -gt 0) {
    foreach ($Instance in $AllSQLInstances) {
        $i++
        $Message = "Instance $i/$AllSQLInstancesCount ($Instance)"; Write-ToLog -Text $Message; Write-Host $Message
        $p = (Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Microsoft SQL Server\Instance Names\SQL').$Instance
        $Edition = (Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Microsoft SQL Server\$p\Setup").Edition
        $Version = (Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Microsoft SQL Server\$p\Setup").Version
        $Message = "   Edition: '$Edition'"; Write-ToLog -Text $Message; Write-Host $Message
        $Message = "   Version: '$Version'"; Write-ToLog -Text $Message; Write-Host $Message
        [int]$MajorVersion = ($Version -split '\.')[0]
        if ($MajorVersion -lt 11) {
            # SQL2k8 is installed on this server. Update to a higher version is required
            $Message = "KO - SQL instance version is too old. Update to a higher SQL version is required before in-place upgrade."; Write-ToLog -Text $Message; Write-Host $Message -ForegroundColor Yellow
            $SQLPrerequisitesOK = $false
        }
        else {
            $Message = "OK - Server with this SQL instance is eligible for in-place upgrade."; Write-ToLog -Text $Message; Write-Host $Message
        }
    }
}

if (-Not $SQLPrerequisitesOK) {
    $ExitCode = 21020
    $PrerequisitesOK = $false
    $Message = "At least one SQL instance installed on the target host is too old, an SQL upgrade is required before the Windows upgrade. Exit '$ExitCode'."; Write-ToLog -Text $Message; Write-Host $Message -ForegroundColor Red
    [Environment]::Exit($ExitCode)

}
#-----------------------------------------
# 30. Check free space on $env:SystemDrive
#-----------------------------------------
$RequiredFreeSpaceGB = 30
$Message = "`nCheck disk free space on the system '$env:SystemDrive' drive."; Write-ToLog -Text $Message; Write-Host $Message -ForegroundColor Magenta
$SystemDrive = Get-WmiObject Win32_LogicalDisk -Filter "DeviceID='$env:SystemDrive'" | Select-Object Size,FreeSpace

$SystemDriveFreeSpaceGB = $SystemDrive.FreeSpace /1gb
$SystemDriveSizeGB = $SystemDrive.Size /1gb
$Message = "'$env:SystemDrive' - TotalSize: $SystemDriveSizeGB GB"; Write-ToLog -Text $Message; Write-Host $Message
$Message = "'$env:SystemDrive' - FreeSpace: $SystemDriveFreeSpaceGB GB"; Write-ToLog -Text $Message; Write-Host $Message

$Message = "RequiredFreeSpaceGB - '$RequiredFreeSpaceGB' GB"; Write-ToLog -Text $Message; Write-Host $Message

if (-Not ($SystemDriveFreeSpaceGB -gt $RequiredFreeSpaceGB)) {
    $ExitCode = 21030
    $PrerequisitesOK = $false
    # 1.8 2020-09-28
    $Message = "'$env:SystemDrive' - TotalSize: $SystemDriveSizeGB GB"; Write-ToLog -Text $Message; Write-Host $Message -ForegroundColor Yellow
    $Message = "'$env:SystemDrive' - FreeSpace: $SystemDriveFreeSpaceGB GB"; Write-ToLog -Text $Message; Write-Host $Message -ForegroundColor Yellow
    $Message = "Not enough free space on the system '$env:SystemDrive' disk. At least '$RequiredFreeSpaceGB' GB of free space is required for upgrade. Exit '$ExitCode'."; Write-ToLog -Text $Message; Write-Host $Message -ForegroundColor Red
    [Environment]::Exit($ExitCode)
}

#------------------------------------------------------------------------
# 40. Check if local hard disk 'D:' exist and have '3' type (Local Disk).
#-------------------------------------------------------------------------
$DiskLetter = 'D:'
$Message = "`nCheck if local hard disk '$DiskLetter' drive exist and have '3' type (Local Disk)."; Write-ToLog -Text $Message; Write-Host $Message -ForegroundColor Magenta

$LogicalDisk = Get-WmiObject Win32_LogicalDisk -Filter "DeviceID='$DiskLetter' AND DriveType='3'" | Select-Object Size,FreeSpace
if (-Not $LogicalDisk) {
    $PrerequisitesOK = $false
    $ExitCode = 21040
    $Message = "Disk '$DiskLetter' does not exist or it is not a type '3' (Local hard disk). Exit '$ExitCode'."; Write-ToLog -Text $Message; Write-Host $Message -ForegroundColor Red
    [Environment]::Exit($ExitCode)
}

$DriveFreeSpaceGB = $LogicalDisk.FreeSpace /1gb
$DriveSizeGB = $LogicalDisk.Size /1gb
$Message = "'$DiskLetter' - TotalSize: $DriveSizeGB GB"; Write-ToLog -Text $Message; Write-Host $Message
$Message = "'$DiskLetter' - FreeSpace: $DriveFreeSpaceGB GB"; Write-ToLog -Text $Message; Write-Host $Message

#------------------------------------------------------------------
# 50. Check if there is enough free space on the '$DiskLetter' disk
#------------------------------------------------------------------
$RequiredDFreeSpaceGB = 30
$Message = "`nCheck if there is enough free space on the local '$DiskLetter' drive."; Write-ToLog -Text $Message; Write-Host $Message -ForegroundColor Magenta

$Message = "RequiredFreeSpaceGB - '$RequiredDFreeSpaceGB' GB"; Write-ToLog -Text $Message; Write-Host $Message

if (-Not ($DriveFreeSpaceGB -gt $RequiredDFreeSpaceGB)) {
    $PrerequisitesOK = $false
    $ExitCode = 21050
    # 1.8 2020-09-28
    $Message = "'$DiskLetter' - TotalSize: $DriveSizeGB GB"; Write-ToLog -Text $Message; Write-Host $Message -ForegroundColor Yellow
    $Message = "'$DiskLetter' - FreeSpace: $DriveFreeSpaceGB GB"; Write-ToLog -Text $Message; Write-Host $Message -ForegroundColor Yellow
    $Message = "Not enough free space on the '$DiskLetter' disk. At least '$RequiredDFreeSpaceGB' GB of free space is required for upgrade. Exit '$ExitCode'."; Write-ToLog -Text $Message; Write-Host $Message -ForegroundColor Red
    #$Message = "PrerequisitesOK=$PrerequisitesOK"; Write-ToLog -Text $Message; Write-Host $Message -ForegroundColor Yellow
    [Environment]::Exit($ExitCode)
}

#--------------------
# List all services
#--------------------
$Message = "`nList all services:"; Write-ToLog -Text $Message; Write-Host $Message -ForegroundColor Magenta
# $LogFile = 'C:\~LOGS\MyWM\CheckPrerequisites\CheckPrerequisites_2019-11-28_11-35-45.92.log'
$AllServices = get-service
Add-Content -LiteralPath $LogFile -Value 'Name,DisplayName,Status'
foreach ($OneService in $AllServices) {
    $LogLine = "{0},{1},{2}" -f $OneService.Name, $OneService.DisplayName, $OneService.Status
    Add-Content -LiteralPath $LogFile -Value $LogLine
}

#---------------
# Set Exit code
#---------------
$Message = "`nSet Exit code..."; Write-ToLog -Text $Message; Write-Host $Message -ForegroundColor Magenta
if ($PrerequisitesOK) {
    $ExitCode = 0
    $Message = "PrerequisitesOK=$PrerequisitesOK. Start upgrade..."; Write-ToLog -Text $Message; Write-Host $Message -ForegroundColor Green
} 
else {
    # Normally, this "else" condition will never be met and the next line will never be executed!
    $Message = "PrerequisitesOK=$PrerequisitesOK. Abort upgrade..."; Write-ToLog -Text $Message; Write-Host $Message -ForegroundColor Red
}
#endregion AllActions
#=====================

#=======================
#region Finalization
#=======================
$Message = "`n==== region Finalization ==="; Write-ToLog -Text $Message; Write-Host $Message -BackgroundColor White -ForegroundColor Black

#----------------------------------------------
# Set Exit Code if $ExitCode variable not exist
#----------------------------------------------
$Message = "`nSet Exit Code if `$ExitCode variable not exist."; Write-ToLog -Text $Message; Write-Host $Message -ForegroundColor Magenta
if (-not (Test-Path variable:ExitCode)) {
    $Message = "`nVariable '`$ExitCode' is not set. Set '`$ExitCode=0' and exit."; Write-ToLog -Text $Message; Write-Host $Message -ForegroundColor Yellow
    $ExitCode=0
}
$Message = "`$ExitCode=$ExitCode"; Write-ToLog -Text $Message; Write-Host $Message -ForegroundColor DarkGreen

#--------------------------
# Write $ATRefFlagFile file
#--------------------------
$Message = "`nWrite ATRefFlagFile file..."; Write-ToLog -Text $Message; Write-Host $Message -ForegroundColor Magenta

# Set ATRefFlagFile
$ATRefFlagsDir = 'C:\Tools\Flags'
$ATRefFlagFile = "$ATRefFlagsDir\${SoftShortName}_$ATRefPID.atref"

If (-Not (Test-Path -PathType Container -Path $ATRefFlagsDir)) {
    New-Item $ATRefFlagsDir -ItemType Directory | ForEach-Object {$_.Attributes = "hidden"} 
}
$null = New-Item $ATRefFlagFile -type file -force
$Message = "Tag file '$ATRefFlagFile' has been created"; Write-ToLog -Text $Message; Write-Host $Message -ForegroundColor DarkGreen

#--------------------------
# Set reg values
#--------------------------
$Message = "`nSet reg values..."; Write-ToLog -Text $Message; Write-Host $Message -ForegroundColor Magenta
try {$ParentKeyPath = $XML.Root.ParentKeyPath}
catch {
    $ExceptionMessage = $_.Exception.Message
    $Message = "ExceptionMessage: '$ExceptionMessage'"; Write-ToLog -Text $Message; Write-Host $Message -ForegroundColor Yellow
    $Message = "Check xml file: '$XMLFile'"; Write-ToLog -Text $Message; Write-Host $Message -ForegroundColor Yellow
    
    $ParentKeyPath = 'HKLM:\SOFTWARE\AIRBUS\MASTER\SOFTS'
    $Message = "Set ParentKeyPath = '$ParentKeyPath'"; Write-ToLog -Text $Message; Write-Host $Message -ForegroundColor Yellow
}

# Prepare RegKey
#$KeyPath = "$ParentKeyPath\$SoftShortName"
$DateTimeStamp = get-date -Format "yyyy-MM-dd HH_mm_ss"
# $SoftName & $SoftVersion from xml file
$KeyPath = "$ParentKeyPath\${SoftShortName}_v.$SoftVersion $DateTimeStamp"
$Message = "Write to: [$KeyPath]"; Write-ToLog -Text $Message; Write-Host $Message -ForegroundColor DarkGreen
if (-Not (Test-Path $KeyPath)) {$null = New-Item -Path $KeyPath -Force}

# ...Soft LongName (from xml file)
$Name = 'SoftLongName'
$Value = $SoftLongName ; $PropertyType = 'String'
$Message = "Set $Name = '$Value'"; Write-ToLog -Text $Message; Write-Host $Message -ForegroundColor DarkGreen
$null = New-ItemProperty -Path $KeyPath -Name $Name -Value $Value -PropertyType $PropertyType -Force

# ...Soft VERSION (from xml file)
$Name = 'SoftVersion'
$Value = $SoftVersion ; $PropertyType = 'String'
$Message = "Set $Name = '$Value'"; Write-ToLog -Text $Message; Write-Host $Message -ForegroundColor DarkGreen
$null = New-ItemProperty -Path $KeyPath -Name $Name -Value $Value -PropertyType $PropertyType -Force

# ... ScriptFile
$Name = 'ScriptFile'
$Value = $PSExecutedFile ; $PropertyType = 'String'
$Message = "Set $Name = '$Value'"; Write-ToLog -Text $Message; Write-Host $Message -ForegroundColor DarkGreen
$null = New-ItemProperty -Path $KeyPath -Name $Name -Value $Value -PropertyType $PropertyType -Force

# ... ScriptVersion
# Get this script version from script file ($PSExecutedFile)
$aux = Select-String -Path $PSExecutedFile -Pattern '^#\s*Script\s*VERSION\s*:\s*\d+'
$ScriptVersion = (($aux -split ':')[-1]).Trim()
$Name = 'ScriptVersion'
$Value = $ScriptVersion ; $PropertyType = 'String'
$Message = "Set $Name = '$Value'"; Write-ToLog -Text $Message; Write-Host $Message -ForegroundColor DarkGreen
$null = New-ItemProperty -Path $KeyPath -Name $Name -Value $Value -PropertyType $PropertyType -Force

# ... ScriptFile_LastWriteTime
$Name = 'ScriptFile_LastWriteTime'
# $PSExecutedFile = 'E:\Masters\_MasterDeploy\_PostInstall\LocalActions\Hardening\Hardening.ps1'
$lastModifiedDate = ((Get-Item "$PSExecutedFile").LastWriteTime).ToString("yyyy/MM/dd - HH:mm:ss")
$Value = $lastModifiedDate ; $PropertyType = 'String'
$Message = "Set $Name = '$Value'"; Write-ToLog -Text $Message; Write-Host $Message -ForegroundColor DarkGreen
$null = New-ItemProperty -Path $KeyPath -Name $Name -Value $Value -PropertyType $PropertyType -Force

# ... ScriptFile_SHA1Hash
$Name = 'ScriptFile_SHA1Hash'
# $PSExecutedFile = 'E:\Masters\_MasterDeploy\_PostInstall\LocalActions\Hardening\Hardening.ps1'
$SHA1Provider = New-Object System.Security.Cryptography.SHA1CryptoServiceProvider 
$SHA1Hash = [System.BitConverter]::ToString( $SHA1Provider.ComputeHash([System.IO.File]::ReadAllBytes($PSExecutedFile)))
$Value = $SHA1Hash ; $PropertyType = 'String'
$Message = "Set $Name = '$Value'"; Write-ToLog -Text $Message; Write-Host $Message -ForegroundColor DarkGreen
$null = New-ItemProperty -Path $KeyPath -Name $Name -Value $Value -PropertyType $PropertyType -Force

# ... LogFile
$Name = 'LogFile'
$Value = $LogFile ; $PropertyType = 'String'
$Message = "Set $Name = '$Value'"; Write-ToLog -Text $Message; Write-Host $Message -ForegroundColor DarkGreen
$null = New-ItemProperty -Path $KeyPath -Name $Name -Value $Value -PropertyType $PropertyType -Force

# ... Date
$Name = 'Date'
$Value = Get-Date -format "yyyy/MM/dd - HH:mm:ss" ; $PropertyType = 'String'
$Message = "Set $Name = '$Value'"; Write-ToLog -Text $Message; Write-Host $Message -ForegroundColor DarkGreen
$null = New-ItemProperty -Path $KeyPath -Name $Name -Value $Value -PropertyType $PropertyType -Force

#-------------------------------------
# Stop-Transcript & Exit with ExitCode
#-------------------------------------
Stop-Transcript
$Message = "`nPS OK. Exit $ExitCode."; Write-ToLog -Text $Message; Write-Host $Message -ForegroundColor Black -BackgroundColor Green
# cmd /c pause
[Environment]::Exit($ExitCode)
#endregion Finalization
#=======================
