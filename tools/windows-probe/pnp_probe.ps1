<#
.SYNOPSIS
Read-only Windows PnP driver-binding diagnostics for BLE HID devices.

.DESCRIPTION
Summarizes Bluetooth/HIDClass PnP nodes (including non-present devices), looking
for BTHLE-related nodes, HID-over-GATT drivers, and remote-like names.
Does not print InstanceId, DevicePath, MAC, container GUID, serials, or raw PnP
hardware IDs. Never changes drivers, pairing, or device settings.
#>

[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'

if (-not (Get-Command Get-PnpDevice -ErrorAction SilentlyContinue)) {
    Write-Error 'Get-PnpDevice is not available. Run in Windows PowerShell 5.1 on Windows.'
    exit 2
}

function Get-SafeName([string]$Name) {
    if ([string]::IsNullOrWhiteSpace($Name)) { return '(unnamed)' }
    if ($Name -match '(?i)^DL1' -or $Name -match '(?i)Siri Remote') {
        return '(remote-like name, redacted)'
    }
    # Device names sometimes contain unique Bluetooth addresses / identifiers.
    if ($Name -match '(?i)(?:[0-9a-f]{2}[:-]){5}[0-9a-f]{2}' -or
        $Name -match '(?i)(?:[0-9a-f]{2}[_-]){5}[0-9a-f]{2}' -or
        $Name -match '(?i)[0-9a-f]{12}') {
        return '(identifier-bearing name, redacted)'
    }
    # Avoid dumping arbitrary potentially personally identifying display names.
    return '(other device)'
}

function Get-PropertyValue($Device, [string]$KeyName) {
    try {
        $p = $Device | Get-PnpDeviceProperty -KeyName $KeyName -ErrorAction Stop
        if ($null -ne $p) { return $p.Data }
    } catch {
        # Some devices simply do not expose a property.
    }
    return $null
}

$all = @(Get-PnpDevice -ErrorAction Stop)
$filtered = @($all | Where-Object {
    $_.Class -in @('Bluetooth','HIDClass') -or
    $_.FriendlyName -match '(?i)^DL1|Siri Remote' -or
    $_.InstanceId -match '(?i)BTHLE'
})

Write-Output ("All PnP devices: {0}; Bluetooth/HIDClass/BTHLE candidates: {1}" -f $all.Count, $filtered.Count)
Write-Output 'This is a driver-binding inventory, NOT proof a node belongs to A2854.'
Write-Output 'No instance IDs, MAC addresses, device paths, or unique device identifiers are printed.'

$rows = @(
    foreach ($d in $filtered) {
        $service = Get-PropertyValue $d 'DEVPKEY_Device_Service'
        $driverDesc = Get-PropertyValue $d 'DEVPKEY_Device_DriverDesc'
        $problem = Get-PropertyValue $d 'DEVPKEY_Device_ProblemCode'
        $kind = if ($d.InstanceId -match '(?i)BTHLEDEVICE') { 'BTHLEDEVICE' }
                elseif ($d.InstanceId -match '(?i)BTHLE') { 'BTHLE' }
                else { 'other' }
        $serviceSafe = if ($null -eq $service) { '(none)' }
                       elseif ([string]$service -match '^[A-Za-z0-9_.-]{1,64}$') {
                           [string]$service
                       } else { '(unusual service name redacted)' }
        $driverSafe = if ([string]$driverDesc -match '(?i)HID.*Bluetooth|Bluetooth.*HID') {
            'Bluetooth HID'
        } elseif ([string]$driverDesc -match '(?i)Bluetooth') {
            'Bluetooth (other)'
        } elseif ($null -eq $driverDesc) {
            '(none)'
        } else { '(other)' }
        [pscustomobject]@{
            Class = [string]$d.Class
            Status = [string]$d.Status
            Node = $kind
            Name = Get-SafeName ([string]$d.FriendlyName)
            Service = $serviceSafe
            Driver = $driverSafe
            Problem = if ($null -eq $problem) { '?' } else { [string]$problem }
        }
    }
)

# Summarize driver services, then show a short set of BLE- or HID-related nodes.
Write-Output ''
Write-Output 'Driver service counts (all candidate nodes):'
$rows | Group-Object Service | Sort-Object Count -Descending |
    Select-Object Count, Name | Format-Table -AutoSize | Out-String -Width 180 |
    Write-Output

Write-Output 'Bluetooth LE / HID-related candidate nodes:'
$candidates = @($rows | Where-Object {
    $_.Node -ne 'other' -or
    $_.Class -eq 'HIDClass' -or
    $_.Name -eq '(remote-like name, redacted)' -or
    $_.Service -match '(?i)HID|BthLE'
})
if ($candidates.Count -eq 0) {
    Write-Output '(no matching PnP nodes found)'
} else {
    $candidates | Sort-Object Class, Node, Service |
        Format-Table Class, Status, Node, Name, Service, Driver, Problem -AutoSize |
        Out-String -Width 180 | Write-Output
}

Write-Output 'Notes: non-present nodes may be stale; a generic/absent service is not proof'
Write-Output 'of driver failure. Do not change driver/pairing configuration based on this alone.'
