"""SQLAlchemy engines for EnergyCore MySQL and Snowflake, built from config/*.yml."""

import os
from functools import cache

from cryptography.hazmat.primitives import serialization
from snowflake.sqlalchemy import URL as SnowflakeURL
from sqlalchemy import create_engine
from sqlalchemy.engine import URL, Engine

from tios_pandas_example import settings


def mysql_url() -> URL:
    yml = settings.load("mysql")
    return URL.create(
        "mysql+pymysql",
        username=yml.get("username"),
        password=yml.get("password") or None,
        host=yml.get("host", "127.0.0.1"),
        port=int(yml.get("port", 3306)),
        database=yml.get("name"),
    )


def snowflake_url() -> str:
    yml = settings.load("snowflake")
    return SnowflakeURL(
        account=yml["account_identifier"],
        user=yml["username"],
        password=yml.get("password") or "",
        database=yml.get("database"),
        schema=yml.get("schema"),
        warehouse=yml.get("warehouse"),
        role=yml.get("role"),
    )


def _private_key_der(path: str) -> bytes:
    """Snowflake's connector wants the .p8 key as unencrypted DER bytes."""
    with open(os.path.expanduser(path), "rb") as f:
        key = serialization.load_pem_private_key(f.read(), password=None)
    return key.private_bytes(
        encoding=serialization.Encoding.DER,
        format=serialization.PrivateFormat.PKCS8,
        encryption_algorithm=serialization.NoEncryption(),
    )


@cache
def get_db() -> Engine:
    """EnergyCore MySQL engine for the current TIOS_ENV."""
    return create_engine(mysql_url(), pool_pre_ping=True)


@cache
def get_snowflake_db() -> Engine:
    """Snowflake engine for the current TIOS_ENV (key pair if priv_key_file is set, else password)."""
    key_file = settings.load("snowflake").get("priv_key_file")
    connect_args = {"private_key": _private_key_der(key_file)} if key_file else {}
    return create_engine(snowflake_url(), connect_args=connect_args)
