#!/usr/bin/env python3
"""Generate docker-compose.yml from instances/*.env."""

from __future__ import annotations

import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent
INSTANCES_DIR = ROOT / "instances"
COMPOSE_FILE = ROOT / "docker-compose.yml"


def parse_env(path: Path) -> dict[str, str]:
    values: dict[str, str] = {}
    if not path.exists():
        return values
    for raw in path.read_text(encoding="utf-8").splitlines():
        line = raw.strip()
        if not line or line.startswith("#") or "=" not in line:
            continue
        key, value = line.split("=", 1)
        key = key.strip()
        value = value.strip().strip('"').strip("'")
        values[key] = value
    return values


def main() -> int:
    instances: list[dict[str, str]] = []
    seen_ports: dict[str, str] = {}

    for env_path in sorted(INSTANCES_DIR.glob("*.env")):
        data = parse_env(env_path)
        name = data.get("NAME") or env_path.stem
        required = ["XRAY_UUID", "REALITY_PRIVATE_KEY", "REALITY_SHORT_ID", "PORT", "HOST_PORT"]
        missing = [key for key in required if not data.get(key)]
        if missing:
            print(f"skip {env_path.name}: missing {', '.join(missing)}", file=sys.stderr)
            continue

        host_port = data["HOST_PORT"]
        if host_port in seen_ports:
            print(
                f"error: HOST_PORT {host_port} is used by both {seen_ports[host_port]} and {name}",
                file=sys.stderr,
            )
            return 1
        seen_ports[host_port] = name
        instances.append({**data, "NAME": name, "ENV_PATH": f"instances/{env_path.name}"})

    if not instances:
        print("no instances found in instances/*.env", file=sys.stderr)
        return 1

    lines = [
        "name: vpn-xray",
        "services:",
    ]
    for inst in instances:
        name = inst["NAME"]
        lines.extend(
            [
                f"  xray-{name}:",
                "    image: vpn-xray:latest",
                "    restart: unless-stopped",
                "    env_file:",
                f"      - {inst['ENV_PATH']}",
                "    ports:",
                f'      - "{inst["HOST_PORT"]}:{inst["PORT"]}/tcp"',
                "",
            ]
        )

    COMPOSE_FILE.write_text("\n".join(lines), encoding="utf-8")
    print(f"wrote {COMPOSE_FILE} with {len(instances)} instance(s): {', '.join(i['NAME'] for i in instances)}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
