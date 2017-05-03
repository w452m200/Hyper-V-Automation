#Requires -RunAsAdministrator

[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)]
    [string]$SourcePath,
    
    [Parameter(Mandatory=$true)]
    [string]$Edition,

    [Parameter(Mandatory=$true)]
    [string]$VMName,

    [Parameter(Mandatory=$true)]
    [uint64]$VHDXSizeBytes,

    [Parameter(Mandatory=$true)]
    [string]$AdministratorPassword,

    [Parameter(Mandatory=$true)]
    [int64]$MemoryStartupBytes,

    [int64]$VMProcessorCount = 2,

    [string]$VMSwitchName = 'SWITCH',

    [string]$Locale = 'en-US'
)

$ErrorActionPreference = 'Stop'

# Get default VHD path (requires administrative privileges)
$vmms = gwmi -namespace root\virtualization\v2 Msvm_VirtualSystemManagementService
$vmmsSettings = gwmi -namespace root\virtualization\v2 Msvm_VirtualSystemManagementServiceSettingData
$vhdxPath = Join-Path $vmmsSettings.DefaultVirtualHardDiskPath "$VMName.vhdx"

# Create unattend.xml
$unattendPath = .\New-WindowsUnattendFile.ps1 -AdministratorPassword $AdministratorPassword -ComputerName $VMName -Locale $Locale

# Create VHDX from ISO image
. .\tools\Convert-WindowsImage.ps1
Convert-WindowsImage -SourcePath $SourcePath -Edition $Edition -VHDPath $vhdxPath -SizeBytes $VHDXSizeBytes -VHDFormat VHDX -DiskLayout UEFI -UnattendPath $unattendPath

# Create VM
$vm = New-VM -Name $VMName -Generation 2 -MemoryStartupBytes $MemoryStartupBytes -VHDPath $vhdxPath -SwitchName $VMSwitchName
$vm | Set-VMProcessor -Count $VMProcessorCount
$vm | Get-VMIntegrationService -Name "Guest Service Interface" | Enable-VMIntegrationService -Passthru
$vm | Start-VM

# Wait for installation complete
do { 
    Start-Sleep -Seconds 1
} until (($vm | Get-VMIntegrationService -Name 'Heartbeat').PrimaryStatusDescription -eq 'OK')

$vm