"""Reads config/<name>.yml for the current TIOS_ENV, the same way tiosfc does."""

import os
from pathlib import Path

import yaml

ENVS = {"development", "test", "stage", "production"}


def app_env() -> str:
    env = os.environ.get("TIOS_ENV", "development")
    if env not in ENVS:
        raise ValueError(f"TIOS_ENV must be one of {sorted(ENVS)}, not '{env}'")
    return env


def app_root() -> Path:
    """The repo root, or TIOS_APPROOT when set."""
    return Path(os.environ.get("TIOS_APPROOT", Path(__file__).parent.parent.parent))


def config_dir() -> Path:
    return app_root() / "config"


def load(name: str) -> dict:
    """Returns the section of config/<name>.yml for the current TIOS_ENV."""
    path = config_dir() / f"{name}.yml"
    if not path.is_file():
        raise IOError(f"config file not found: {path} (run bin/build-configs.sh or `just use-config-samples`)")

    with open(path) as f:
        yml = yaml.safe_load(f)

    env = app_env()
    if env not in yml:
        raise ValueError(f"no '{env}' section in {path}")
    return yml[env]
