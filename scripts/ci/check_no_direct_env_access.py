# Copied from find_direct_env_usage.py (renamed for clarity)
#!/usr/bin/env python3
"""
Script to find direct environment variable usage instead of using settings from config.py
"""
import re
from pathlib import Path


def find_direct_env_usage(directory):
    """Find all direct os.getenv() and os.environ.get() calls in Python files"""
    results = []

    # Patterns to match direct env variable access
    getenv_pattern = r'os\.getenv\(["\']([^"\']+)["\']'
    environ_pattern = r'os\.environ\.get\(["\']([^"\']+)["\']'

    # Exclude config files since they're supposed to use direct access
    exclude_patterns = [
        "config.py",
        "check_env_vars.py",
        "check_no_direct_env_access.py",
    ]

    for py_file in Path(directory).rglob("*.py"):
        # Skip excluded files
        if any(pattern in py_file.name for pattern in exclude_patterns):
            continue

        try:
            with open(py_file, "r", encoding="utf-8") as f:
                lines = f.readlines()

            for line_num, line in enumerate(lines, 1):
                # Check for os.getenv() calls
                getenv_matches = re.findall(getenv_pattern, line)
                environ_matches = re.findall(environ_pattern, line)

                for var_name in getenv_matches + environ_matches:
                    results.append(
                        {
                            "file": str(py_file),
                            "line": line_num,
                            "variable": var_name,
                            "code": line.strip(),
                        }
                    )

        except Exception as e:
            print(f"Error reading {py_file}: {e}")

    return results


def main():
    # Get the backend app directory
    script_dir = Path(__file__).parent.parent.parent
    app_dir = script_dir / "app"

    if not app_dir.exists():
        print(f"ERROR: App directory not found at {app_dir}")
        return

    print("Direct Environment Variable Usage Check")
    results = find_direct_env_usage(app_dir)
    if results:
        print("\n❌ Found direct environment variable usage outside config.py:")
        for r in results:
            print(f" - {r['file']}:{r['line']}  {r['variable']}  {r['code']}")
        exit(1)
    else:
        print("✅ No direct environment variable usage found outside config.py.")


if __name__ == "__main__":
    main()
