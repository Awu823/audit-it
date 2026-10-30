#!/usr/bin/env python3
"""check_connectivity.py -- preflight + connectivity check for sap-stock-availability.

Stages:
  1. PREREQ   offline: requests importable, catalog.json present, CLI present
  2. CONFIG   offline: connection.json present? credential stored in keystore?
  3. LIVE     only if configured: delegate to `sap_stock.py doctor` (read-only
              BAPI_MATERIAL_GETLIST probe through the REST2RFC gateway)

Never prints secrets. Exit codes mirror sap_stock.py semantics:
  0 ok (or NOT_CONFIGURED, still 0 so CI can distinguish via the status word)
  1 prereq / config problem
  3 auth/credentials (only when a live probe was attempted)
"""
from __future__ import annotations

import subprocess
import sys
from pathlib import Path

# Windows consoles often default to cp1252; force UTF-8 so CJK output survives.
for _stream in (sys.stdout, sys.stderr):
    if hasattr(_stream, "reconfigure"):
        _stream.reconfigure(encoding="utf-8", errors="replace")

ROOT = Path(__file__).resolve().parents[1]
SCRIPTS = ROOT / "scripts"


def main() -> int:
    status: list[str] = []
    ok = True

    # ---- 1. PREREQ (offline) ----
    try:
        import requests  # noqa: F401
        status.append("PREREQ  requests: ok")
    except ImportError:
        status.append("PREREQ  requests: MISSING (pip install -r scripts/requirements.txt)")
        ok = False

    for name in ("sap_stock.py", "sap_credentials.py", "rest2rfc_meta.py"):
        p = SCRIPTS / name
        status.append(f"PREREQ  {name}: {'ok' if p.exists() else 'MISSING'}")
        ok = ok and p.exists()

    catalog = ROOT / "catalog.json"
    status.append(f"PREREQ  catalog.json: {'ok' if catalog.exists() else 'MISSING'}")
    ok = ok and catalog.exists()

    # ---- 2. CONFIG (offline) ----
    conn = ROOT / "connection.json"
    conn_example = ROOT / "connection.example.json"
    if conn.exists():
        status.append(f"CONFIG  connection.json: present ({conn_example.name} is the template)")
    else:
        status.append(f"CONFIG  connection.json: ABSENT -- copy {conn_example.name} and fill host/client/user")
        ok = False

    # credential presence (keystore, never the value)
    try:
        import json
        conn_data = json.loads(conn.read_text(encoding="utf-8")) if conn.exists() else {}
        cred_key = f"{conn_data.get('host', '?')}|{conn_data.get('client', '?')}:{conn_data.get('user', '?')}"
        sys.path.insert(0, str(SCRIPTS))
        from sap_credentials import probe_keystores, select_keystore
        store = select_keystore(None)
        configured = store.get(cred_key) is not None if conn.exists() else False
        status.append(f"CONFIG  keystore backend: {store.name}; credential {'stored' if configured else 'not stored'}")
        if not configured:
            ok = False
    except Exception as exc:  # noqa: BLE001 - config problem, never crash
        status.append(f"CONFIG  credential check skipped: {type(exc).__name__}: {str(exc)[:120]}")
        ok = False

    # ---- 3. LIVE (only when fully configured) ----
    if ok and conn.exists():
        proc = subprocess.run([sys.executable, str(SCRIPTS / "sap_stock.py"), "doctor"],
                              capture_output=True, text=True)
        if proc.returncode == 0:
            status.append("LIVE    gateway reachable (doctor OK)")
        else:
            status.append(f"LIVE    doctor failed (exit {proc.returncode}): {(proc.stderr or '')[-300:]}")
            ok = False
    else:
        status.append("LIVE    skipped -- configure connection.json + `credentials set` (see README.md)")

    print("\n".join(status))
    word = "OK" if ok else "NOT_CONFIGURED"
    print("RESULT: " + word)
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main())
