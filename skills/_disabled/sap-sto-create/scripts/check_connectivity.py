#!/usr/bin/env python3
"""check_connectivity.py -- preflight + connectivity check for sap-sto-create.

Runs in three stages:
  1. PREREQ   offline: Python deps, CLI present, JCo jar + platform native lib
  2. CONFIG   offline: .env present, required env vars set (never print secrets)
  3. LIVE     only if configured: lightweight OData service-root GET

No secrets are ever printed. Exit codes:
  0 = everything ok (or not configured, with a clear NOT_CONFIGURED status)
  1 = prereq or config problem
"""
from __future__ import annotations

import os
import sys
from pathlib import Path

# Windows consoles often default to cp1252; force UTF-8 so CJK output survives.
for _stream in (sys.stdout, sys.stderr):
    if hasattr(_stream, "reconfigure"):
        _stream.reconfigure(encoding="utf-8", errors="replace")

ROOT = Path(__file__).resolve().parents[1]
SCRIPTS = ROOT / "scripts"
JAVA_DIR = SCRIPTS / "lib" / "java"

REQUIRED_ENV = ("SAP_URL", "SAP_ASHOST", "SAP_CLIENT", "SAP_USER", "SAP_PASSWORD")
SECRET_ENV = ("SAP_PASSWORD",)


def _platform_jco() -> tuple[str, Path | None]:
    """Return (label, expected native lib path) for the current platform."""
    if sys.platform.startswith("linux"):
        return "linux", JAVA_DIR / "lib" / "linux" / "libsapjco3.so"
    if sys.platform == "darwin":
        return "macos", JAVA_DIR / "lib" / "macos" / "libsapjco3.jnilib"
    return "windows", JAVA_DIR / "lib" / "windows" / "sapjco3.dll"


def _load_env() -> None:
    """Load .env if present (python-dotenv optional; else minimal parse)."""
    env_file = ROOT / ".env"
    if not env_file.exists():
        return
    try:
        import dotenv  # noqa: F401
        dotenv.load_dotenv(env_file, override=True)
        return
    except ImportError:
        pass
    for line in env_file.read_text(encoding="utf-8").splitlines():
        line = line.strip()
        if not line or line.startswith("#") or "=" not in line:
            continue
        k, _, v = line.partition("=")
        os.environ.setdefault(k.strip(), v.strip().strip('"').strip("'"))


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

    cli = SCRIPTS / "sap_sto_cli.py"
    status.append(f"PREREQ  CLI {cli.name}: {'ok' if cli.exists() else 'MISSING'}")
    ok = ok and cli.exists()

    lib = SCRIPTS / "lib" / "create_sto_odata.py"
    status.append(f"PREREQ  core lib create_sto_odata.py: {'ok' if lib.exists() else 'MISSING'}")
    ok = ok and lib.exists()

    jar = JAVA_DIR / "sapjco3.jar"
    status.append(f"PREREQ  sapjco3.jar: {'ok' if jar.exists() else 'MISSING'}")
    ok = ok and jar.exists()

    plat, jco_lib = _platform_jco()
    jco_ok = jco_lib.exists()
    status.append(f"PREREQ  JCo native lib ({plat}): {'ok' if jco_ok else 'MISSING'}")
    ok = ok and jco_ok

    # ---- 2. CONFIG (offline) ----
    _load_env()
    env_file = ROOT / ".env"
    status.append(f"CONFIG  .env: {'present' if env_file.exists() else 'absent (see .env.example)'}")
    present = {k: bool(os.environ.get(k)) for k in REQUIRED_ENV}
    missing = [k for k in REQUIRED_ENV if not present[k]]
    if missing:
        status.append(f"CONFIG  missing env vars: {', '.join(missing)}")
        ok = False
    else:
        status.append("CONFIG  all required env vars present (secrets not shown)")

    # ---- 3. LIVE (only when fully configured) ----
    if ok and not missing:
        url = os.environ["SAP_URL"].rstrip("/")
        try:
            r = requests.get(url, timeout=15,
                             auth=(os.environ["SAP_USER"], os.environ["SAP_PASSWORD"]))
            if r.status_code < 500:
                status.append(f"LIVE    OData service root reachable (HTTP {r.status_code})")
            else:
                status.append(f"LIVE    service responded HTTP {r.status_code} (reachable, auth may need client)")
                ok = False
        except requests.exceptions.RequestException as exc:
            status.append(f"LIVE    unreachable: {type(exc).__name__}: {str(exc)[:200]}")
            ok = False
    else:
        status.append("LIVE    skipped -- configure .env (see README.md) to enable the live check")

    print("\n".join(status))
    print("RESULT: " + ("OK" if ok else "NOT_READY"))
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main())
