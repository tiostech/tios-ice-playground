#!/bin/bash
# Writes config/mysql.yml and config/snowflake.yml.
# Reuses the team credential setup when present (tios-central/bin/setup-credentials):
#   MySQL password from ~/.mysql-tios-pass, Snowflake user/key from [tios] in ~/.snowflake/connections.toml.
# Prompts only for what is missing. Overwrites existing config files.

set -e

BASEDIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )/../config" && pwd )"
echo "Using config dir: $BASEDIR"

mysql_user=`whoami`
if [ -f $HOME/.mysql-tios-pass ]; then
  mysql_user_pass=$(head -n 1 $HOME/.mysql-tios-pass)
else
  read -s -p 'EnergyCore MySQL (prod replica) password: ' mysql_user_pass; echo
fi

# toml_value KEY: value of KEY in the [tios] section of ~/.snowflake/connections.toml
SNOWFLAKE_TOML=$HOME/.snowflake/connections.toml
toml_value() {
  [ -f $SNOWFLAKE_TOML ] || return 0
  awk -v key="$1" '
    /^\[/ { in_sec = ($0 == "[tios]") }
    in_sec && $1 == key { sub(/^[^=]*=[ \t]*/, ""); gsub(/"/, ""); print; exit }
  ' $SNOWFLAKE_TOML
}

snowflake_user=$(toml_value user)
snowflake_key=$(toml_value private_key_file)
snowflake_pass=$(toml_value password)
snowflake_role=$(toml_value role)
snowflake_warehouse=$(toml_value warehouse)

[ -n "$snowflake_user" ] || read -p 'Snowflake user: ' snowflake_user
if [ -z "$snowflake_key" ] && [ -z "$snowflake_pass" ]; then
  read -p 'Path to Snowflake private key (.p8), blank to use a password: ' snowflake_key
  [ -n "$snowflake_key" ] || { read -s -p 'Snowflake password: ' snowflake_pass; echo; }
fi

cat > $BASEDIR/mysql.yml << EOMYS
development:
  username: root
  password:
  host: 127.0.0.1
  port: 3306
  name: tioscore_development_master

# The tios-labs tunnels put prod and stage both on localhost:3309, so open only one at a time.

# read-only prod replica; needs \`just prod-tunnel\` (tios-labs/bin/slave-ssh-tunnel)
production:
  username: $mysql_user
  password: "$mysql_user_pass"
  host: 127.0.0.1
  port: 3309
  name: tioscore_production

# stage; needs \`just stage-tunnel\` (tios-labs/bin/stage-ssh-tunnel)
stage:
  username: $mysql_user
  password: "$mysql_user_pass"
  host: 127.0.0.1
  port: 3309
  name: tioscore_production
EOMYS

cat > $BASEDIR/snowflake.yml << EOSNOW
readonly: &readonly
  username: $snowflake_user
  password: "$snowflake_pass"
  priv_key_file: $snowflake_key
  account_identifier: nta32714.us-east-1
  database: TIOSDATA_PRODUCTION
  schema: TIOSDATA
  warehouse: ${snowflake_warehouse:-COMPUTE_WH}
  role: ${snowflake_role:-TIOSREADER}

development:
  <<: *readonly

production:
  <<: *readonly
EOSNOW

chmod 600 $BASEDIR/mysql.yml $BASEDIR/snowflake.yml
echo "Done writing mysql.yml and snowflake.yml in $BASEDIR"
