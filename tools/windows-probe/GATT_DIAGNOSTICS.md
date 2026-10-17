# Paired Siri Remote: read-only Windows GATT investigation

The Windows Bluetooth Settings page can show a device as paired/disconnected even when a client has not requested an active BLE connection. During the 2026-10-17 trial, the A2854 showed a temporary connection and a battery percentage, then disconnected; the earlier HID interface probe remained unchanged at 20 interfaces. The device's Windows display name was reported as beginning with "DL1" (exact suffix not recorded). These findings do **not** yet confirm working Windows HID input.

This program uses **WinRT directly** to list paired BLE devices, request **uncached** GATT discovery on one selected device, and report whether HID 0x1812 is visible and whether its Report 0x2A4D characteristics are accessible. It never pairs/unpairs, installs drivers, writes HID feature/output reports, enables notifications, captures microphone data, or synthesizes input.

## Run in PowerShell (repository root)

```powershell
git pull --ff-only
py -3 -m pip install "bleak>=2,<4"
py -3 tools\windows-probe\gatt_probe.py
```

Look for a device named `DL1…` or another likely A2854 name among the **paired BLE devices**. Use its numbered index, for example:

```powershell
py -3 tools\windows-probe\gatt_probe.py --index 0
```

The `0` here is **only an example**. Choose the printed index for the remote, not another person's device. The script suppresses BLE addresses and unique device IDs by design. Keep the remote nearby and try tapping Back or another button while it runs. A normal BLE connection may close again after the script finishes.

If the paired WinRT enumeration does not show the remote, also list disconnected Windows Bluetooth PnP entries:

```powershell
Get-PnpDevice -Class Bluetooth |
    Where-Object { $_.FriendlyName -match 'DL1|Siri|Apple|Remote|Bluetooth LE' } |
    Select-Object Status, Class, FriendlyName
```

Avoid posting raw Windows `InstanceId` fields publicly because some encode unique Bluetooth addresses.

## Interpret carefully

- **A paired record present**: Windows has pairing metadata, not proof of active GATT connectivity.
- **Uncached GATT discovery success**: Windows obtained a service list in this attempt, indicating a working GATT operation.
- **HID 0x1812 absent**: Windows may own/hide it or service discovery is incomplete. Does not prove the device lacks HID; Linux already observed it.
- **HID 0x1812 present, characteristics AccessDenied**: Windows has denied these GATT characteristic operations to this process; a normal Windows GATT client may not be able to receive HID reports.
- **HID Report 0x2A4D visible**: This is promising, but **actual** 0xFB/0xFC notifications and required 0xAF enable writes still need a separate, explicitly approved test.
- **GATT errors/timeouts**: Record the exact status/error and Windows version; do not automatically delete pairing or change drivers.

Microsoft documents that uncached GATT discovery can initiate a BLE connection, and that a BluetoothLEDevice object alone may not. Bleak's WinRT backend may explicitly skip HID characteristics after AccessDenied, so this tool uses lower-level WinRT to preserve the denied status rather than silently omitting it.

References:
- [Microsoft: Bluetooth GATT client](https://learn.microsoft.com/en-us/windows/uwp/devices-sensors/gatt-client)
- [Microsoft: BluetoothLEDevice API](https://learn.microsoft.com/en-us/uwp/api/windows.devices.bluetooth.bluetoothledevice)
- [Bleak WinRT implementation](https://bleak.readthedocs.io/en/latest/_modules/bleak/backends/winrt/client.html)

## Validation boundaries

The program requires native Windows, Python 3.9+, and the `bleak` dependency (which brings PyWinRT modules). Successful Windows CI imports or unit tests do not prove that this specific A2854 can be read. If WinRT fails while Windows Bluetooth briefly shows a battery reading, preserve both observations; they are not necessarily contradictory.
