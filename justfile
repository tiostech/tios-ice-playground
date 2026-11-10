home                := env_var("HOME")
bash                := env_var("SHELL")

project             := invocation_directory()
pyproject           := project + "/pyproject.toml"

venv                := project + "/.venv"
pip                 := venv + "/bin/pip"
python              := venv + "/bin/python"
pytest              := venv + "/bin/pytest"
blackbin            := venv + "/bin/black"

poetry_root         := home + "/.local"
poetry              := poetry_root + "/bin/poetry"
poetry_ver          := "1.7.1"

venv_python         := home + "/.pyenv/versions/3.10.11/bin/python"
syspython_version   := "Python 3.10.11"

pip_version         := "24.0"

configs             := "mysql snowflake"

# tunnel scripts from the tios-labs repo (git@github.com:tiostech/tios-labs.git)
tios_labs           := env_var_or_default("TIOS_LABS", home + "/dev/tios-labs")
tunnel_port         := "3309"

default:
  @just --list

_verify-syspython-exists:
    @([ -x {{venv_python}} ]) || (echo 'no python found! (checked {{venv_python}}; try `pyenv install 3.10.11`)' && exit 1)

# checks existence and version of syspython
verify-syspython: _verify-syspython-exists
    @PYVERSION=$({{venv_python}} --version) \
        && ( [ "$PYVERSION" = "{{syspython_version}}" ] || (echo "incorrect system python version: '$PYVERSION' (expected '{{syspython_version}}')" && exit 1) ) \
        && echo "verified system python: $PYVERSION"

_verify-poetry-exists:
    @[ -x {{poetry}} ] || (echo "poetry not found: {{poetry}} (call 'just install-poetry'?)" && exit 1)

verify-poetry: _verify-poetry-exists
    #!{{bash}}
    installed=`{{poetry}} -V | sed -e 's/.* //g' | sed -e 's/[^0-9\.]//g'`
    if [ "$installed" != "{{poetry_ver}}" ]; then
      echo "poetry $installed found, expected {{poetry_ver}} (call 'just upgrade-poetry')"
      exit 1
    fi

# downloads and installs poetry (to $HOME/.local/bin/poetry)
install-poetry: verify-syspython
    #!{{bash}}
    [ -x {{poetry}} ] && just -q verify-poetry && exit 0
    echo 'downloading poetry'
    curl -sSL https://install.python-poetry.org | {{venv_python}} - -f --version={{poetry_ver}}
    just verify-poetry

upgrade-poetry:
    rm -rf {{poetry_root}}/share/pypoetry {{poetry}}
    just install-poetry

# creates venv at ./.venv, replacing it if it has the wrong python
install-venv: verify-syspython
    #!{{bash}}
    if [ -x {{python}} ] && [[ "$({{python}} --version)" != "{{syspython_version}}" ]]; then
        echo "Detected venv with the wrong python. Removing it"
        just remove-venv
    fi
    [ -x {{python}} ] || {{venv_python}} -m venv {{venv}}
    {{pip}} install -q pip=={{pip_version}}

# rm -rf ./.venv
remove-venv:
    rm -rf {{venv}}

# checks venv has the right python
verify-venv:
    @([ -x {{python}} ] && [ -x {{pip}} ]) \
        || (echo "missing venv: expected python/pip in {{venv}}/bin (call 'just init'?)" && exit 1)
    @([ "$({{python}} --version)" = "{{syspython_version}}" ] || (echo "incorrect version of python in venv" && exit 1))

# checks pyproject.toml exists
verify-pyproject:
    @[ -f {{pyproject}} ] || (echo "pyproject file not found: {{pyproject}}" && exit 1)

# verifies everything is in its right place, then calls `poetry ...`
poetry-cmd +args="": verify-pyproject verify-venv verify-poetry
    PATH="{{venv}}/bin:$PATH" python={{python}} {{poetry}} {{args}}

# adds a new dependency to pyproject.toml and installs it
add-dep dep +args="":
    @just poetry-cmd add {{dep}} {{args}}

# upgrade a dependency
update-dep dep +args="":
    @just poetry-cmd update {{dep}} {{args}}

install-deps:
    @just poetry-cmd install

# smoke test that venv python can import deps
verify-import-packages:
    #!{{python}}
    import pandas, sqlalchemy, pymysql, snowflake.sqlalchemy, sklearn
    print(f"pandas {pandas.__version__}, sqlalchemy {sqlalchemy.__version__}, scikit-learn {sklearn.__version__}")

# write config/*.yml from your existing team credentials (prompts for anything missing)
build-configs:
    {{project}}/bin/build-configs.sh

# copy sample config files to enabled path
use-config-samples:
    #!{{bash}}
    for yml in {{configs}}; do
        [ -f config/$yml.yml ] || cp -v config/$yml.yml.sample config/$yml.yml
    done

# checks config files exist
verify-config:
    #!{{bash}}
    for yml in {{configs}}; do
        CFG="{{project}}/config/$yml.yml"
        [ -f $CFG ] || (echo "config file not found: $CFG (call 'just build-configs'?)" && exit 1)
    done

# install everything from scratch
init: install-poetry install-venv install-deps verify-venv verify-import-packages

test +args="": verify-venv
    TIOS_ENV=test {{pytest}} --tb=native {{args}}

black +args=".":
    {{blackbin}} {{args}}

# start (venv) python repl
console +args="": verify-venv
    {{python}} {{args}}

# open the tunnel to the read-only prod MySQL replica on localhost:3309 (leave it running in its own terminal)
prod-tunnel:
    {{tios_labs}}/bin/slave-ssh-tunnel

# open the tunnel to stage MySQL on localhost:3309 (leave it running in its own terminal)
stage-tunnel:
    {{tios_labs}}/bin/stage-ssh-tunnel

# checks something is listening on the tunnel port
verify-tunnel:
    @nc -z 127.0.0.1 {{tunnel_port}} 2>/dev/null \
        || (echo "nothing on localhost:{{tunnel_port}}: run 'just prod-tunnel' (or 'just stage-tunnel') in another terminal" && exit 1)

# python repl with TIOS_ENV=production (needs 'just prod-tunnel')
prodconsole: verify-venv verify-config verify-tunnel
    TIOS_ENV=production {{python}}

# python repl with TIOS_ENV=stage (needs 'just stage-tunnel')
stageconsole: verify-venv verify-config verify-tunnel
    TIOS_ENV=stage {{python}}

# run a script with the venv python, e.g. `just run examples/mysql_markets.py`
run script +args="": verify-venv verify-config
    {{python}} {{script}} {{args}}

mysql-example: (run "examples/mysql_markets.py")

prod-mysql-example: verify-tunnel
    TIOS_ENV=production just run examples/mysql_markets.py

snowflake-example days="7": (run "examples/snowflake_shadow_prices.py" days)
