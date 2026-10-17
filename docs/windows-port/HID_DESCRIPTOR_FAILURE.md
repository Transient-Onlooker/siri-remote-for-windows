# A2854 Windows HID start failure: descriptor investigation

## Established (physical device, 2026-10-17)

The native Windows PnP chain connects the remote-like BLE parent to its **own** `BTHLEDEVICE/HIDClass` child; the unrelated BLE keyboard child does not match. That Siri Remote child has:
- Driver service: `mshidumdf`
- PnP problem code: **10 / failed to start**
- `DEVPKEY_Device_ProblemStatus`: **`0xC00000B9`**
- Exact-instance Kernel-PnP Configuration **event 411**, at 2026-10-17 12:53:25 local time, `Problem=0xA` and **`Status=0xC00000B9`**.

The remote had also produced a native WinRT GATT `SUCCESS/CONNECTED` session with **seven services**, including HID `0x1812`, while listing its HID characteristics returned `ACCESS_DENIED`. No additional HID interface became visible in the before/after 20-interface snapshots. The first of three connection attempts in one run was `UNREACHABLE` and the second succeeded; this timing is a separate issue.

## Status meaning and limits of attribution

Microsoft's NTSTATUS table names `0xC00000B9` **`STATUS_COULD_NOT_INTERPRET`**. Its general documented meaning discusses an ACL, which **does not imply** an ACL is faulty here. Crucially, Microsoft's **HidP_GetCollectionDescription** reference explicitly lists this same NTSTATUS when **an error is detected in a HID report descriptor**. The `HIDP_GETCOLDESC_DBG` structure can provide a parser error code and byte offset in the appropriate driver-debug context.

This makes a Windows HID descriptor parsing/compatibility failure the **leading hypothesis**, *not a proven root cause*. The identical NTSTATUS could be propagated from another layer. Microsoft also documents other possible HID parser outcomes, such as truncation, missing top-level collections, and malformed items. No report-map bytes or HIDCLASS parser trace for this actual A2854 have yet been captured, so do not identify a specific invalid field, assume all Siri Remotes have the issue, or infer that the remote is incompatible with every Windows transport.

Authoritative references:
- [MS-ERREF: 0xC00000B9 meaning](https://learn.microsoft.com/en-us/openspecs/windows_protocols/ms-erref/596a1078-e883-4972-9bbc-49e60bebca55)
- [Microsoft HidP_GetCollectionDescription return codes](https://learn.microsoft.com/en-us/windows-hardware/drivers/ddi/hidpddi/nf-hidpddi-hidp_getcollectiondescription)
- [Microsoft HIDP_GETCOLDESC_DBG / BreakOffset](https://learn.microsoft.com/en-us/windows-hardware/drivers/ddi/hidpddi/ns-hidpddi-_hidp_getcoldesc_dbg)
- [Microsoft HID I2C troubleshooting (HIDCLASS parser example; not necessarily the same BLE cause)](https://learn.microsoft.com/en-us/windows-hardware/drivers/hid/troubleshoot-hid-over-i2c-device-issues)
- [BlueZ GATT Characteristic ReadValue](https://bluez.readthedocs.io/en/latest/gatt-api/)

## Practical next evidence: raw HID Report Map (UUID 0x2A4B)

We have physical samples of Input reports `0xFB` (buttons) and `0xFC` (touch), and Linux previously accessed multiple `0x2A4D` report characteristics. **These samples are not the descriptor.** The raw HID Report Map characteristic `0x2A4B` is necessary to examine the HID item stream and potentially reproduce Windows parser objections.

A [read-only BlueZ capture and offline inspector](../../tools/protocol/report_map.py) has been added. It requires a **pre-existing Linux BlueZ session that is already connected and has resolved GATT services**, where the OS does not claim the HID service. It does **not** re-pair, connect, modify BlueZ, write feature reports, or change Windows drivers. Do not switch the Windows Bluetooth adapter to Linux just to run the Windows-side command below.

Once an eligible connected BlueZ session is available:

```bash
python3 -m pip install --user dbus-next
python3 tools/protocol/report_map.py --output a2854-report-map.bin
```

If several HID peripherals are connected, narrow to the already known local Bluetooth name prefix with `--name-prefix DL1`, or disconnect unrelated peripherals. **No BLE address is needed in the command.** The script fails closed unless precisely one suitable Report Map can be located. It creates the output file exclusively and never overwrites an existing capture.

Then inspect **the saved file** offline on either platform, without a Bluetooth adapter:

```powershell
py -3 tools\protocol\report_map.py --inspect .\a2854-report-map.bin
```

The inspector prints SHA-256, length, Report IDs, item/collection counts, and basic structural warnings. This is a **lightweight bounds checker**, not a full HID standard validator or reproduction of Windows HIDPARSE. A clean result therefore does not contradict Code 10.

When the Report Map is available, the next development step is to test it against Microsoft's HID parser or collect a sanitized HIDCLASS driver trace to identify the exact error offset. **No driver disabling, inf edits, registry writes or Windows pairing reset is authorized or necessary for the present diagnosis.**

## Alternative research branch

If reusing BlueZ is impractical, check Windows driver diagnostic providers and HIDCLASS ETW/WPP availability without touching live driver bindings, before any trace capture. Raw traces may contain addresses/serials; do **not** upload raw ETL or setupapi.dev.log publicly without redaction. Whatever the approach, first validate the descriptor hypothesis before attempting a virtual HID or proprietary transport workaround.
