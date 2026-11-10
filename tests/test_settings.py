import pytest

from tios_pandas_example import connections, settings

MYSQL_YML = """
development:
  username: root
  password:
  host: 127.0.0.1
  port: 3306
  name: tioscore_development_master
production:
  username: someone
  password: secret
  host: 127.0.0.1
  port: 3309
  name: tioscore_production
"""


@pytest.fixture
def config_dir(tmp_path, monkeypatch):
    (tmp_path / "config").mkdir()
    (tmp_path / "config" / "mysql.yml").write_text(MYSQL_YML)
    monkeypatch.setenv("TIOS_APPROOT", str(tmp_path))
    return tmp_path / "config"


def test_development_is_the_default(config_dir, monkeypatch):
    monkeypatch.delenv("TIOS_ENV", raising=False)
    url = connections.mysql_url()
    assert (url.host, url.port, url.database, url.password) == ("127.0.0.1", 3306, "tioscore_development_master", None)


def test_production_goes_through_the_prod_tunnel(config_dir, monkeypatch):
    monkeypatch.setenv("TIOS_ENV", "production")
    url = connections.mysql_url()
    assert (url.port, url.database, url.username) == (3309, "tioscore_production", "someone")


def test_missing_env_section_is_an_error(config_dir, monkeypatch):
    monkeypatch.setenv("TIOS_ENV", "stage")
    with pytest.raises(ValueError, match="no 'stage' section"):
        settings.load("mysql")


def test_unknown_env_is_rejected(monkeypatch):
    monkeypatch.setenv("TIOS_ENV", "prod")
    with pytest.raises(ValueError, match="TIOS_ENV must be one of"):
        settings.app_env()
