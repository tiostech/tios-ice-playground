# tios-pandas-example

A small example of querying EnergyCore MySQL and Snowflake into Pandas DataFrames.
It follows the layout of tiosfc and tios-ftr-python: Poetry, a `justfile`, and
per-environment `config/*.yml` files picked by `TIOS_ENV`.

## Setup

Needs pyenv Python 3.10.11 (`pyenv install 3.10.11`) and `just` (`brew install just`).

```bash
just init            # installs poetry 1.7.1 to ~/.local, creates .venv, installs deps
just build-configs   # writes config/mysql.yml and config/snowflake.yml from your team credentials
just test
```

`build-configs` reuses `~/.mysql-tios-pass` and the `[tios]` section of
`~/.snowflake/connections.toml` (both set up by `tios-central/bin/setup-credentials`)
and asks for anything missing. The real `config/*.yml` files hold credentials and are git-ignored.

## Environments

`TIOS_ENV` selects the section of each config file (default `development`).

| TIOS_ENV | MySQL | Snowflake |
|---|---|---|
| `development` | local `tioscore_development_master` on 3306 | `TIOSDATA_PRODUCTION`, read-only role |
| `production` | prod read replica on `localhost:3309` (`just prod-tunnel`) | `TIOSDATA_PRODUCTION`, read-only role |
| `stage` | stage on `localhost:3309` (`just stage-tunnel`) | (none) |

Both prod connections are read-only: the MySQL grant is SELECT-only and Snowflake uses `TIOSREADER`.

### Tunnels

Prod and stage MySQL are reached through SSH tunnels from the
[tios-labs](https://github.com/tiostech/tios-labs) repo, expected at `~/dev/tios-labs`
(set `TIOS_LABS` if it is elsewhere). Run the tunnel in its own terminal and leave it open:

```bash
just prod-tunnel     # tios-labs/bin/slave-ssh-tunnel: read-only prod replica on localhost:3309
just stage-tunnel    # tios-labs/bin/stage-ssh-tunnel: stage on localhost:3309
```

Both use port 3309, so only one can be open at a time. `TIOS_ENV` only picks credentials; the open
tunnel decides which database you reach, so make sure it matches. Use the replica tunnel for reads,
not `master-ssh-tunnel`. Snowflake needs no tunnel.

The examples use pandas, but scikit-learn is installed too. It is pinned to 1.7 because newer
releases need Python 3.11.

## Examples

```bash
just mysql-example           # markets table from the local dev DB
just prod-mysql-example      # same query against the prod replica (needs just prod-tunnel)
just snowflake-example 30    # top PJM DA binding constraints over the last 30 days
just prodconsole             # python REPL with TIOS_ENV=production (stageconsole for stage)
```

In your own code:

```python
import pandas as pd
from sqlalchemy import text
from tios_pandas_example.connections import get_db, get_snowflake_db

markets = pd.read_sql(text("SELECT id, urn, name FROM markets"), get_db())
shadow = pd.read_sql(
    text("SELECT dt, hr, constraint_name, shadow_price "
         "FROM TIOSDATA_PRODUCTION.TIOSDATA.PJM_DA_CONSTRAINT_SHADOW_PRICES WHERE dt >= :since"),
    get_snowflake_db(),
    params={"since": "2026-11-01"},
)
```

## Querying tips

- Select named columns and filter, especially in prod. Many tables have hundreds of millions of rows.
- Pass values as bind parameters (`:name` with `params=`), never with f-strings.
- In Snowflake, fully qualify tables (`TIOSDATA_PRODUCTION.TIOSDATA.<table>`) and filter on the date column.
- Snowflake column names come back lowercase through SQLAlchemy.
- Add dependencies with `just add-dep <package>`.
