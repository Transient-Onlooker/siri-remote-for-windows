<#
.SYNOPSIS
Inspect the captured HIDCLASS Event 3 v2 safely without revealing device IDs.

.DESCRIPTION
Read-only. Reuses the newest local siri_hidclass_*.etl; does not start
tracing, re-pair, restart PnP nodes, or alter Windows configuration.

Reads Event 3 v2's DeviceStartStatus, ReportDescriptorLength and
DeviceInstancePath in memory. Prints ONLY numeric statuses/lengths and
the result of an exact Windows PnP-node/parent-ancestry correlation.

Never prints event Message, XML, DeviceInstancePath, MAC, VID/PID,
ReportDescriptor bytes, user/computer names or raw ETL filename.

NOTE: An unknown device association is not evidence that an event
belongs to the Siri Remote.
#>
[CmdletBinding()]
param(
    [ValidateRange(1, 500)]
    [int]$MaxEvents = 200,
    [ValidateRange(1, 15)]
    [int]$MaxDepth = 10
)

$ErrorActionPreference = 'Stop'
$providerName = 'Microsoft-Windows-Input-HIDCLASS'

function Get-NumericStatus($value) {
    if ($null -eq $value) { return '(missing)' }
    $s = ([string]$value).Trim()
    if ($s -match '(?i)^0x([0-9a-f]{1,8})$') {
        return ('0x{0}' -f $Matches[1].ToUpperInvariant().PadLeft(8, '0'))
    }
    try {
        $number = [long]::Parse($s)
        $bits = [BitConverter]::ToUInt32([BitConverter]::GetBytes($number), 0)
        return ('0x{0:X8}' -f $bits)
    } catch {
        return '(unavailable)'
    }
}
function Safe-Length($value) {
    if ($null -eq $value) { return '(missing)' }
    try {
        $n = [long]::Parse(([string]$value).Trim())
        if ($n -ge 0 -and $n -le 1048576) { return [string]$n }
    } catch {}
    return '(unavailable)'
}
function Get-Parent($id) {
    if ([string]::IsNullOrWhiteSpace($id)) { return $null }
    try {
        $p = Get-PnpDeviceProperty -InstanceId $id -KeyName 'DEVPKEY_Device_Parent' -ErrorAction Stop
        if ($null -ne $p -and -not [string]::IsNullOrWhiteSpace([string]$p.Data)) {
            return [string]$p.Data
        }
    } catch {}
    return $null
}
function Is-Descendant($child, $ancestor) {
    if ([string]::IsNullOrWhiteSpace($ancestor) -or
        [string]::IsNullOrWhiteSpace($child)) { return $false }
    $seen = @{}
    $current = [string]$child
    for ($i = 0; $i -le $MaxDepth; $i++) {
        if ($current -ieq $ancestor) { return $true }
        if ($seen.ContainsKey($current)) { break }
        $seen[$current] = $true
        $current = Get-Parent $current
        if ([string]::IsNullOrWhiteSpace($current)) { break }
    }
    return $false
}

$etl = Get-ChildItem -LiteralPath ([IO.Path]::GetTempPath()) -File -Filter 'siri_hidclass_*.etl' |
    Sort-Object LastWriteTimeUtc -Descending | Select-Object -First 1
if ($null -eq $etl) {
    Write-Output 'No local HIDCLASS ETL trace found in TEMP for this Windows account.'
    exit 1
}

$metadata = Get-WinEvent -ListProvider $providerName -ErrorAction Stop
$template = @($metadata.Events | Where-Object { $_.Id -eq 3 -and $_.Version -eq 2 })
if ($template.Count -ne 1) {
    Write-Output 'HIDCLASS event 3 version 2 schema unavailable; no unsafe assumptions.'
    exit 1
}

[xml]$xml = [string]$template[0].Template
$fields = @($xml.SelectNodes('//*[local-name()="data"]'))
$indices = @{}
for ($i = 0; $i -lt $fields.Count; $i++) {
    $name = [string]$fields[$i].GetAttribute('name')
    if (-not $indices.ContainsKey($name)) { $indices[$name] = $i }
}
$needed = @('DeviceStartStatus', 'DeviceInstancePath', 'ReportDescriptorLength')
foreach ($name in $needed) {
    if (-not $indices.ContainsKey($name)) {
        Write-Output 'Expected event schema field absent; stopping without guessing offsets.'
        exit 1
    }
}

$events = @(
    Get-WinEvent -Path $etl.FullName -Oldest -ErrorAction Stop |
        Where-Object { $_.ProviderName -eq $providerName -and $_.Id -eq 3 -and $_.Version -eq 2 } |
        Select-Object -First $MaxEvents
)
Write-Output ("Event 3 v2 records found (up to {0}): {1}" -f $MaxEvents, $events.Count)
if ($events.Count -eq 0) { exit 0 }

# The PnP lookup is confined to local machine memory; IDs/paths never leave
# this process. A match requires EXACT InstanceId and then parent ancestry.
$anchor = $null
$pnp = @()
try { $pnp = @(Get-PnpDevice -ErrorAction Stop) } catch {}
$remoteCandidates = @(
    $pnp | Where-Object {
        $_.Class -eq 'Bluetooth' -and
        $_.FriendlyName -match '(?i)^(DL1)|Siri Remote'
    }
)
if ($remoteCandidates.Count -eq 1) {
    $anchor = [string]$remoteCandidates[0].InstanceId
    Write-Output 'Unique paired remote Bluetooth PnP anchor: yes.'
} else {
    Write-Output 'Unique remote anchor: unavailable; device correlation is inconclusive.'
}
$knownIds = @{}
foreach ($device in $pnp) {
    if (-not [string]::IsNullOrWhiteSpace([string]$device.InstanceId)) {
        $knownIds[[string]$device.InstanceId] = $true
    }
}

$rows = @()
$i = 0
foreach ($e in $events) {
    $i++
    if ($e.Properties.Count -lt $fields.Count) {
        $rows += [pscustomobject]@{
            No = $i; Attribution = 'SchemaMismatch'
            StartStatus = '(unavailable)'; DescriptorBytes = '(unavailable)'
        }
        continue
    }
    $instanceId = [string]$e.Properties[$indices['DeviceInstancePath']].Value
    $association = 'UnmatchedPath'
    if ($knownIds.ContainsKey($instanceId)) {
        $association = 'OtherPnP'
        if ($null -ne $anchor -and (Is-Descendant $instanceId $anchor)) {
            $association = 'RemoteDescendant'
        }
    }
    $rows += [pscustomobject]@{
        No = $i
        Attribution = $association
        StartStatus = Get-NumericStatus $e.Properties[$indices['DeviceStartStatus']].Value
        DescriptorBytes = Safe-Length $e.Properties[$indices['ReportDescriptorLength']].Value
    }
}
$rows | Format-Table -AutoSize | Out-String -Width 120 | Write-Output
Write-Output 'Device paths/identifiers and descriptor bytes were not printed.'
Write-Output 'UnmatchedPath means NOT attributable, not that it is unrelated.'
Write-Output 'StartStatus is an event-field value, not proof of a new device-start attempt.'
