#!/usr/bin/env bash

shopt -s nocasematch
AMBER='\033[1;33m'
GREEN='\033[0;32m'
RED='\033[0;31m'
source scripts/sqlmi/common-functions.sh
source scripts/common/common-functions.sh

MODE=${1:-start}
SKIP="false"

if [[ "$MODE" != "start" && "$MODE" != "stop" ]]; then
    echo "Invalid MODE. Please use 'start' or 'stop'."
    exit 1
fi

SUBSCRIPTIONS=$(az account list -o json)

jq -c '.[]' <<< $SUBSCRIPTIONS | while read subscription; do
  get_subscription_sql_servers
  jq -c '.[]' <<< $SERVERS | while read server; do
    get_sql_server_details
    server_env=$(echo $SERVER_NAME | cut -d'-' -f 3)
    server_env=${server_env/stg/Staging}
    server_business_area=${server_business_area/ss/cross-cutting}
    server_business_area=$( jq -r '.tags.businessArea' <<< $server)

    SKIP=$(should_skip_start_stop $server_env $server_business_area $MODE)

    if [[ $SKIP == "false" ]]; then
        echo -e "${GREEN}About to run $MODE operation on sql server $SERVER_NAME (rg:$RESOURCE_GROUP)"
        echo az sql mi $MODE --resource-group $RESOURCE_GROUP --name $SERVER_NAME --no-wait || echo Ignoring any errors while $MODE operation on sql server
        az sql mi $MODE --resource-group $RESOURCE_GROUP --name $SERVER_NAME --no-wait || echo Ignoring any errors while $MODE operation on sql server
    else
        echo -e "${AMBER}sql server $SERVER_NAME (rg:$RESOURCE_GROUP) has been skipped from today's $MODE operation schedule"
    fi
  done
done