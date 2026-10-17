#!/usr/bin/env python3
"""Privacy-safe read-only summary of recent bluetoothd systemd journal messages.

Never prints raw journal text, unique hardware IDs, addresses, device names,
hostnames, D-Bus paths, UUIDs or manufacturer values. Prints generic failure
categories and small status/error codes only. Requires no Python packages.
"""
from __future__ import annotations

import argparse
from collections import Counter
import re
import subprocess
import sys

ERROR_CODE = re.compile(
    r"(?i)\b(?:att\s+ecode|error(?:\s+code)?|status|reason|err)\s*[:=]?\s*"
    r"(0x[0-9a-f]{1,4}|-[0-9]{1,5}|[0-9]{1,5})\b"
)
BT_MAC = re.compile(r"(?i)\b(?:[0-9a-f]{2}:){5}[0-9a-f]{2}\b")


def classify(line: str):
    """Return generic category and bounded numeric codes; never source text."""
    low = line.lower()
    if not any(x in low for x in (
        "fail", "error", "disconnect", "timeout", "timed out", "abort",
        "unresolved", "cancel", "auth", "gatt", "att ", "service",
        "hci", "firmware", "connection", "connect",
    )):
        return None
    if any(x in low for x in ("authentication", "authorization", "encrypt",
                               "pairing", "smp ", "bonding")):
        label = "security-or-bond"
    elif any(x in low for x in ("gatt", "att ", "service", "database hash",
                                 "primary", "resolved")):
        label = "gatt-or-service-discovery"
    elif any(x in low for x in ("disconnect", "connection", "connect",
                                 "terminated", "link loss")):
        label = "connection-or-disconnection"
    elif any(x in low for x in ("hci", "firmware", "controller", "usb")):
        label = "controller-or-hci"
    elif any(x in low for x in ("fail", "error", "timeout", "abort")):
        label = "other-bluetooth-failure"
    else:
        return None

    # Only these *explicitly labelled* short protocol/error codes are emitted.
    # Never emit unlabelled hex: these could be identifying data.
    codes = []
    for match in ERROR_CODE.finditer(line):
        code = match.group(1)
        if code.lower().startswith("0x"):
            code = "0x" + code[2:].upper()
        codes.append(code)
    return label, tuple(codes[:3])


def summarize(lines):
    categories = Counter()
    details = Counter()
    for line in lines:
        if BT_MAC.search(line):
            # Continue classifying, but never expose source text regardless.
            pass
        item = classify(line)
        if item is None:
            continue
        label, codes = item
        categories[label] += 1
        if codes:
            details[(label, codes)] += 1
    return categories, details


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument("--minutes", type=int, default=30,
                   help="look back from now (1..180 minutes)")
    p.add_argument("--max-lines", type=int, default=600,
                   help="maximum latest bluetoothd lines examined (1..2000)")
    args = p.parse_args()
    if not 1 <= args.minutes <= 180 or not 1 <= args.max_lines <= 2000:
        p.error("--minutes and --max-lines must be in supported bounds")
    cmd = [
        "journalctl", "--unit=bluetooth.service",
        "--since", f"{args.minutes} minutes ago",
        "--no-pager", "--output=cat", "--quiet",
        "--lines", str(args.max_lines),
    ]
    try:
        result = subprocess.run(cmd, text=True, capture_output=True,
                                timeout=12, check=False)
    except (OSError, subprocess.TimeoutExpired):
        print("bluetoothd journal could not be read; try sudo python3 ...")
        return 1
    if result.returncode:
        print("bluetoothd journal command failed; journal permissions may be missing.")
        return 1
    lines = result.stdout.splitlines()
    categories, details = summarize(lines)
    print(f"Read bluetoothd journal lines: {len(lines)}")
    print("Only sanitized categories and numeric error statuses follow.")
    if not categories:
        print("No recognizable bluetoothd failures in this window.")
        print("Absence of messages does not prove GATT succeeded; debug logging may be off.")
        return 0
    for category, count in sorted(categories.items()):
        print(f"  {category}: {count}")
    for (category, codes), count in details.most_common(12):
        print(f"  status: {category}; codes={','.join(codes)}; events={count}")
    print("No MACs, raw messages, device identifiers or D-Bus paths were printed.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
