#!/usr/bin/env bash

# Determine the location of this script file
SCRIPT_SOURCE=${BASH_SOURCE[0]}
if [[ -L "$SCRIPT_SOURCE" ]] ; then
    SCRIPT_SOURCE=$( readlink "$SCRIPT_SOURCE" )
fi
REPO_HOME=$( cd "$( dirname "$SCRIPT_SOURCE" )" && pwd )

# Data repository defaults
USERNAME=admin
PASSWORD=admin
CTP_URL=http://localhost:8080
ALIAS=datarepo

# Credentials to use to connect to CTP Test Data
T_USER=admin
T_PASS=admin

"$REPO_HOME/scripts/init.sh" \
    --username "${USERNAME}" \
    --password "${PASSWORD}" \
    --ctp-url "${CTP_URL}" \
    --ctp-username "${T_USER}" \
    --ctp-password "${T_PASS}" \
    --alias "${ALIAS}"
