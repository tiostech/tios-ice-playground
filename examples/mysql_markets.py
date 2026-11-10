"""Load the EnergyCore markets table from MySQL into a DataFrame.

    just mysql-example              # local dev DB
    just prod-mysql-example         # prod replica (needs tios-tunnel prod)
"""

import pandas as pd
from sqlalchemy import bindparam, text

from tios_pandas_example.connections import get_db
from tios_pandas_example.settings import app_env

ISOS = ["caiso", "ercot", "isone", "miso", "nyiso", "pjm", "spp"]

# Select named columns and filter: prod tables can be huge. Pass values as bind params, never f-strings.
SQL = text(
    """
    SELECT id, urn, name, time_zone, observes_dst
    FROM markets
    WHERE urn IN :urns
    ORDER BY urn
    """
).bindparams(bindparam("urns", expanding=True))


def main():
    df = pd.read_sql(SQL, get_db(), params={"urns": ISOS})
    print(f"TIOS_ENV={app_env()}: {len(df)} markets")
    print(df.to_string(index=False))


if __name__ == "__main__":
    main()
