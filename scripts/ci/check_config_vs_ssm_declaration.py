import re
import sys
from pathlib import Path
from typing import Optional

CONFIG_PATH = Path("app/core/config/config.py")
SSM_GLOBAL_FILE = Path("scripts/ci/ssm_global_envs.txt")
SSM_ENV_FILE = Path("scripts/ci/ssm_env_specific_envs.txt")

GETENV_PATTERN = re.compile(r'os\.getenv\(\s*["\']([A-Z0-9_]+)["\']')


def read_env_list(path: Path, pattern: Optional[re.Pattern] = None) -> set[str]:
    if not path.exists():
        return set()

    envs = set()
    lines = path.read_text().splitlines()
    non_comment_lines = [
        line.strip()
        for line in lines
        if line.strip() and not line.strip().startswith("#")
    ]
    if pattern:
        # Join non-comment lines and apply pattern once
        text = "\n".join(non_comment_lines)
        envs = set(pattern.findall(text))
    else:
        envs = set(non_comment_lines)
    return envs


def main() -> None:
    # ---- extract envs from config.py ----
    config_envs = read_env_list(CONFIG_PATH, GETENV_PATTERN)

    # ---- read SSM lists ----
    ssm_global_envs = read_env_list(SSM_GLOBAL_FILE)
    ssm_env_specific_envs = read_env_list(SSM_ENV_FILE)

    ssm_all_envs = ssm_global_envs | ssm_env_specific_envs

    errors = False

    # ---- check: config -> SSM ----
    missing_in_ssm = sorted(config_envs - ssm_all_envs)
    if missing_in_ssm:
        errors = True
        print("❌ Env vars used in config.py but NOT declared in SSM lists:")
        for env in missing_in_ssm:
            print(f" - {env}")
        print()

    # ---- check: SSM -> config ----
    # unused_in_config = sorted(ssm_all_envs - config_envs)
    # if unused_in_config:
    #     errors = True
    #     print("❌ Env vars declared in SSM lists but NOT used in config.py:")
    #     for env in unused_in_config:
    #         print(f" - {env}")
    #     print()

    # ---- check: duplicates between global & env-specific ----
    duplicates = sorted(ssm_global_envs & ssm_env_specific_envs)
    if duplicates:
        errors = True
        print("❌ Env vars declared in BOTH global and env-specific SSM lists:")
        for env in duplicates:
            print(f" - {env}")
        print()

    if errors:
        sys.exit(1)

    print("✅ config.py and SSM lists are consistent.")


if __name__ == "__main__":
    main()
