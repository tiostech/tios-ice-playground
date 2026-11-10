"""Load PJM day-ahead constraint shadow prices from Snowflake and find the top binding constraints.

    just snowflake-example          # last 7 days
    just snowflake-example 30       # last 30 days
"""

import sys

import pandas as pd
from sqlalchemy import text

from tios_pandas_example.connections import get_snowflake_db

# Fully qualify Snowflake tables and always filter on DT: the big tables have billions of rows.
SQL = text(
    """
    SELECT dt, hr, constraint_name, shadow_price
    FROM TIOSDATA_PRODUCTION.TIOSDATA.PJM_DA_CONSTRAINT_SHADOW_PRICES
    WHERE dt >= DATEADD(day, -:days, CURRENT_DATE())
    """
)


def main(days: int):
    df = pd.read_sql(SQL, get_snowflake_db(), params={"days": days})
    # Snowflake column names come back lowercase through SQLAlchemy.
    print(f"{len(df):,} hourly rows since {df['dt'].min()}")

    top = (
        df.groupby("constraint_name")
        .agg(hours_bound=("hr", "size"), total_shadow=("shadow_price", "sum"))
        .sort_values("total_shadow", key=abs, ascending=False)
        .head(10)
    )
    print(top.to_string())


if __name__ == "__main__":
    main(int(sys.argv[1]) if len(sys.argv) > 1 else 7)
