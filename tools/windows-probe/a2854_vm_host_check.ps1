<#
.SYNOPSIS
Read-only preparation check for an isolated Windows HID parser test VM.
.DESCRIPTION
Does NOT enable Hyper-V, create a VM, alter Windows features, drivers,
boot settings or networking. Reports capability booleans and coarse memory
and disk size only. The user chooses an isolated VM later.
#>
[CmdletBinding()]
param()
$ErrorActionPreference = 'Stop'
Write-Output 'A2854 Windows HID VM lab - host read-only capability check'
Write-Output ('Windows build: {0}' -f [Environment]::OSVersion.Version.Build)
try {
    $os = Get-CimInstance Win32_OperatingSystem -ErrorAction Stop
    Write-Output ('OS product type: {0}' -f $(if ($os.ProductType -eq 1) { 'Workstation' } else { 'Other' }))
    Write-Output ('Total physical memory (GiB): {0}' -f [math]::Round(([double](Get-CimInstance Win32_ComputerSystem).TotalPhysicalMemory)/1GB,1))
} catch { Write-Output 'System memory / OS type: not available' }
try {
    $p = @(Get-CimInstance Win32_Processor -ErrorAction Stop)
    if ($p.Count -gt 0) {
        Write-Output ('Firmware virtualization enabled: {0}' -f $(if ($p[0].VirtualizationFirmwareEnabled) { 'yes' } elseif ($p[0].VirtualizationFirmwareEnabled -eq $false) { 'no or masked by hypervisor' } else { 'unknown' }))
        Write-Output ('SLAT advertised: {0}' -f $p[0].SecondLevelAddressTranslationExtensions)
    }
} catch { Write-Output 'CPU virtualization info: unavailable' }
try {
    $feature = Get-WindowsOptionalFeature -Online -FeatureName Microsoft-Hyper-V-All -ErrorAction Stop
    Write-Output ('Hyper-V optional feature: {0}' -f $feature.State)
} catch {
    Write-Output 'Hyper-V optional feature: not available / requires elevation / not supported by edition'
}
Write-Output ('Hyper-V PowerShell cmdlets: {0}' -f $(if (Get-Command Get-VM -ErrorAction SilentlyContinue) { 'found' } else { 'not available' }))
Write-Output ('Existing VMware executable: {0}' -f $(if (Get-Command vmrun.exe -ErrorAction SilentlyContinue) { 'found on PATH' } else { 'not on PATH' }))
try {
    $systemDisk = (Get-Item -LiteralPath $env:SystemDrive).PSDrive
    Write-Output ('System drive free space (GiB): {0}' -f [math]::Round($systemDisk.Free/1GB,1))
} catch { Write-Output 'Free space: unavailable' }
Write-Output 'No VM, driver, BIOS or Windows feature settings were modified.'
