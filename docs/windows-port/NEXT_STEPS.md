# Windows port plan — resumed 2026-10-17

**Checkpoint:** Linux hardware I/O succeeded. Windows-native development resumed with a read-only [HID capability probe](../../tools/windows-probe/README.md) and decoder fixture tests; no native A2854 hardware I/O has been verified. The historical ESP32 IR pivot is documented in the dated handoff.

## Phase 0 — documentation [complete for archive]

- [x] Record intended Windows usability and limitations of WSL-only approach.
- [x] Record actual pairing, BLE HID access, touch/button trace and BlueZ workaround.
- [x] Define native architecture, open questions, license obligations.
- [x] Avoid public disclosure of physical BLE address and serial number.
- [ ] Independently validate all documented behavior on more than one A2854.

## Phase 1 — Windows capability proof [not started]

- [ ] Return Intel AX200 from USB/IP to Windows, confirm normal Bluetooth works.
- [ ] Pair/recognize A2854 in Windows; capture sanitized diagnostics.
- [x] Add Windows CI smoke job for Python imports/help and offline fixture tests (CI result not yet verified).
- [x] Implement read-only HID interface enumerator, `ReadFile` probe and sanitized 0xFB/0xFC fixture tests (code only).
- [ ] **On Windows hardware:** run enumerator and verify actual HID report reads.
- [ ] Test GATT service visibility / report reference descriptors if HID fails.
- [ ] Prove actual `0xFB` and `0xFC` button/touch receipt natively, including report enable.
- [ ] Select proven transport backend or document a clear no-go.

## Phase 2 — functionality [not started]

- [ ] Reuse decoder and add fixture tests drawn from sanitized real reports.
- [ ] Map touch XY to Win32 mouse motion; distinguish hover from actual touch.
- [ ] Map Back/TV/direction/play/volume to Win32 input/media handling.
- [ ] Add low-latency reconnect, graceful release of held keys, error reporting.
- [ ] Test an actual physical device across reboots and sleep/wake.

## Phase 3 — production [not started]

- [ ] Add tray app, pause/hotkey, mapping configuration, startup option.
- [ ] Build release binaries and CI, document system requirements and limitations.
- [ ] Respect upstream license and attribution; consider improvements upstream.

## Evidence to retain

The 2026-10-17 test showed physical BLE pairing, `0x1812` HID, active report notifications, a 99% battery reading, physical buttons and touch/hover data. It did *not* prove Windows native BLE capability or fully tested touch input injection. Treat all further work as a new validation phase.

## Avoid accidental assumptions

The host-specific USB/IP bus ID and WSL experimental BlueZ flags must not be embedded into the Windows product. The user should not need WSL, USB/IP or Linux for daily use. Do not describe the temporary audio-disabled build as a full upstream build.
