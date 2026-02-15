
# Backend CI Scripts & Environment Contract

This folder contains all scripts and configuration files for backend CI checks and environment contract enforcement.

## Structure

### ci/

- `check_no_direct_env_access.py` — Fails if any code uses `os.getenv`/`os.environ` outside `config.py`.
- `check_env_example_vs_config.py` — Ensures all env vars in `config.py` are present in `.env.example` and vice versa.
- `check_settings_usage_declared.py` — Ensures all `settings.X` usages in code are declared in `config.py`.
- `check_config_vs_ssm_declaration.py` — Ensures all env vars in `config.py` are declared in SSM lists, and vice versa.
- `check_ssm_params_existence.sh` — Checks that all SSM parameters exist in AWS; writes missing params to a file.
- `slack_notify_missing_ssm.sh` — Notifies DevOps via Slack if any SSM params are missing.
- `ssm_global_envs.txt` — List of global SSM env vars (shared across all environments).
- `ssm_env_specific_envs.txt` — List of env-specific SSM env vars (per environment, e.g., dev/prod).

## Recommended CI Execution Order

1. `check_no_direct_env_access.py`
2. `check_env_example_vs_config.py`
3. `check_settings_usage_declared.py`
4. `check_config_vs_ssm_declaration.py`
5. `check_ssm_params_existence.sh`
6. `slack_notify_missing_ssm.sh` (only if missing params found)

## Environment Contract

- `config.py` is the source of truth for environment variables.
- `.env.example` and SSM lists must match all variables used in `config.py`.
- All `settings.X` usages in the codebase must be declared in `config.py`.
- No direct environment variable access (`os.getenv`, `os.environ`) is allowed outside `config.py`.

See each script for usage details and implementation.
