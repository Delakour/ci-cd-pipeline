#!/usr/bin/env python3
"""
Script to check if .env.example variables match those declared in app/core/config/config.py
"""
import re
import sys
from pathlib import Path


def parse_env_example(file_path):
    """Parse .env.example file and extract variable names"""
    variables = set()

    with open(file_path, "r", encoding="utf-8") as f:
        for line in f:
            line = line.strip()
            # Skip comments and empty lines
            if line.startswith("#") or not line:
                continue
            # Extract variable name (before =)
            if "=" in line:
                var_name = line.split("=")[0].strip()
                variables.add(var_name)

    return variables


def parse_config_py(file_path):
    """Parse config.py and extract os.getenv() calls"""
    variables = set()

    with open(file_path, "r", encoding="utf-8") as f:
        lines = f.readlines()

    # Remove comment lines
    non_comment_lines = [line for line in lines if not line.strip().startswith("#")]
    content = "".join(non_comment_lines)

    # Find all os.getenv() calls
    getenv_pattern = r'os\.getenv\(["\']([^"\']+)["\']'
    matches = re.findall(getenv_pattern, content)

    for match in matches:
        variables.add(match)

    return variables


def main():
    # Get the project root directory (go up from scripts/ci to project root)
    script_dir = Path(__file__).parent.parent.parent

    # Define file paths
    env_example_path = script_dir / ".env.example"
    config_path = script_dir / "app" / "core" / "config" / "config.py"

    # Check if files exist
    if not env_example_path.exists():
        print(f"ERROR: .env.example not found at {env_example_path}")
        sys.exit(1)

    if not config_path.exists():
        print(f"ERROR: config.py not found at {config_path}")
        sys.exit(1)

    env_vars = parse_env_example(env_example_path)
    config_vars = parse_config_py(config_path)

    missing_in_env = sorted(config_vars - env_vars)
    extra_in_env = sorted(env_vars - config_vars)

    if missing_in_env:
        print("❌ Variables in config.py but missing in .env.example:")
        for var in missing_in_env:
            print(f" - {var}")
        print()

    if extra_in_env:
        print("⚠️ Variables in .env.example but not used in config.py:")
        for var in extra_in_env:
            print(f" - {var}")
        print()

    if missing_in_env:
        sys.exit(1)

    print("✅ .env.example matches config.py")


if __name__ == "__main__":
    main()
