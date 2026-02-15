import re
import sys
from collections import defaultdict
from pathlib import Path

CONFIG_PATH = Path("app/core/config/config.py")
CODE_ROOT = Path("app")

# Match settings.X
SETTINGS_USAGE_RE = re.compile(r"\bsettings\.([A-Z0-9_]+)\b")

# Match Settings field definitions
SETTINGS_FIELD_RE = re.compile(r"^\s*([A-Z0-9_]+)\s*:", re.MULTILINE)


def main() -> None:
    # ---- read config.py ----
    config_text = CONFIG_PATH.read_text(encoding="utf-8", errors="ignore")
    defined_fields = set(SETTINGS_FIELD_RE.findall(config_text))

    # ---- scan code for settings.X usage ----
    usages: dict[str, list[tuple[Path, int, str]]] = defaultdict(list)

    for py_file in CODE_ROOT.rglob("*.py"):
        if py_file == CONFIG_PATH:
            continue

        lines = py_file.read_text(encoding="utf-8", errors="ignore").splitlines()

        for idx, line in enumerate(lines, start=1):
            if line.strip().startswith("#"):
                continue
            for match in SETTINGS_USAGE_RE.findall(line):
                usages[match].append((py_file, idx, line.strip()))

    # ---- compare ----
    undefined = sorted(name for name in usages if name not in defined_fields)

    if undefined:
        print("❌ settings.<NAME> used in code but NOT defined in config.py:\n")

        for name in undefined:
            print(f"{name}:")
            for path, line_no, line_text in usages[name]:
                print(f"  - {path}:{line_no}")
                print(f"      {line_text}")
            print()

        print("Fix options:")
        print(" - Add the setting to Settings in config.py")
        print(" - OR remove/refactor the usage")
        sys.exit(1)

    print("✅ All settings.<NAME> usages are defined in config.py")


if __name__ == "__main__":
    main()
