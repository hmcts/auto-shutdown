#!/usr/bin/env bash
# set -x
shopt -s nocasematch

# Source shared function scripts
source scripts/flexible-server/common-functions.sh
source scripts/common/common-functions.sh

MODE=${1:-start}
notificationSlackWebhook=$2

MODE=${1:-start}
SKIP="false"

if [[ "$MODE" != "start" && "$MODE" != "stop" ]]; then
    echo "Invalid MODE. Please use 'start' or 'stop'."
    exit 1
fi

SUBSCRIPTIONS=$(az account list -o json)

jq -c '.[]' <<< $SUBSCRIPTIONS | while read subscription; do
  get_subscription_flexible_sql_servers
  
  jq -c '.[]' <<< $FLEXIBLE_SERVERS | while read flexibleserver; do
    
    get_flexible_sql_server_details

    server_env=$(echo $SERVER_NAME | rev | cut -d'-' -f 1 | rev )
    server_env=${server_env/stg/Staging}
    server_business_area=${server_business_area/ss/cross-cutting}
    server_business_area=$( jq -r '.tags.businessArea' <<< $flexibleserver)

    SKIP=$(should_skip_start_stop $server_env $server_business_area $MODE)

    if [[ $SKIP == "false" ]]; then
        ts_echo_color GREEN "About to run $MODE operation on sql server $SERVER_NAME (rg:$RESOURCE_GROUP)"
        echo az postgres flexible-server $MODE --resource-group $RESOURCE_GROUP --name $SERVER_NAME --no-wait || echo Ignoring any errors while $MODE operation on sql server
        az postgres flexible-server $MODE --resource-group $RESOURCE_GROUP --name $SERVER_NAME --no-wait || echo Ignoring any errors while $MODE operation on sql server
    else
        ts_echo_color AMBER "SQL server $SERVER_NAME (rg:$RESOURCE_GROUP) has been skipped from today's $MODE operation schedule"
    fi
  done
done