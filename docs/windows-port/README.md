# Windows-native Siri Remote — project handoff

**Status: PAUSED (2026-10-17); documentation and Linux hardware proof-of-concept only.**  
**Device:** Apple TV Siri Remote (3rd generation, A2854)  
**Upstream:** [azais-corentin/siri-remote](https://github.com/azais-corentin/siri-remote) · **Fork:** [Transient-Onlooker/siri-remote-for-windows](https://github.com/Transient-Onlooker/siri-remote-for-windows)

## Why this fork exists

The original application successfully receives remote control and touchpad events on Linux. Our intended *product* is different: a **native Windows app** using the normal Windows Bluetooth stack, without WSL2, USB/IP passthrough, a Linux server, or an always-open terminal.

As of 2026-10-17, the remote was successfully tested on Linux in WSL2. **A Windows-native BLE/HID implementation has not been built or validated.** The current fork still contains upstream Linux code. It is not yet a Windows release.

## Entry points

- [Complete dated handoff (Korean)](../../HANDOFF_2026-10-17.md)
- [Sanitized HID report fixtures](OBSERVED_REPORT_FIXTURES.md)

## Records in this folder

- [PROJECT_BRIEF.md](PROJECT_BRIEF.md) — product goal, boundaries, and upstream relationship
- [EXPERIMENT_TIMELINE.md](EXPERIMENT_TIMELINE.md) — what we actually tried and observed
- [PROTOCOL_FINDINGS.md](PROTOCOL_FINDINGS.md) — tested BLE/HID facts and interpretation limits
- [WSL_COMPATIBILITY_NOTES.md](WSL_COMPATIBILITY_NOTES.md) — Linux proof-of-concept fixes and restoration instructions
- [WINDOWS_PORT_DESIGN.md](WINDOWS_PORT_DESIGN.md) — proposed architecture and unresolved Windows restrictions
- [NEXT_STEPS.md](NEXT_STEPS.md) — ordered validation gates for resuming development

## Evidence policy

“Observed” means supported by output from our own A2854/Intel AX200/BlueZ session. “Upstream” means described by the original repository. “Planned” describes unimplemented work. Do not confuse Linux event reception with native Windows functionality.

Public notes intentionally omit the physical remote's BLE address, serial number, and full manufacturer identity bytes.
