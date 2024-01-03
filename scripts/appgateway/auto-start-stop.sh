#!/usr/bin/env bash

shopt -s nocasematch
AMBER='\033[1;33m'
GREEN='\033[0;32m'
RED='\033[0;31m'
source scripts/appgateway/common-functions.sh
source scripts/common/common-functions.sh

MODE=${1:-start}
SKIP="false"

if [[ "$MODE" != "start" && "$MODE" != "stop" ]]; then
    echo "Invalid MODE. Please use 'start' or 'stop'."
    exit 1
fi

SUBSCRIPTIONS=$(az account list -o json)

jq -c '.[]' <<< $SUBSCRIPTIONS | while read subscription; do
  get_application_gateways
  jq -c '.[]' <<< $APPLICATION_GATEWAYS | while read application_gateway; do
    get_application_gateways_details
    application_gateway_env=$(echo $APPLICATION_GATEWAY_NAME | rev | cut -d'-' -f 2 | rev )
    application_gateway_env=${application_gateway_env/stg/Staging}
    application_gateway_business_area=${application_gateway_business_area/ss/cross-cutting}
    application_gateway_business_area=$( jq -r '.tags.businessArea' <<< $application_gateway)

    SKIP=$(should_skip_start_stop $application_gateway_env $application_gateway_business_area $MODE)

    if [[ $SKIP == "false" ]]; then
        echo -e "${GREEN}About to run $MODE operation on application gateway $APPLICATION_GATEWAY_NAME (rg:$RESOURCE_GROUP)"
        echo az network application-gateway $MODE --resource-group $RESOURCE_GROUP --name $APPLICATION_GATEWAY_NAME --no-wait || echo Ignoring any errors while $MODE operation on application_gateway
        az network application-gateway $MODE --resource-group $RESOURCE_GROUP --name $APPLICATION_GATEWAY_NAME --no-wait || echo Ignoring any errors while $MODE operation on application_gateway
    else
        echo -e "${AMBER}application_gateway $APPLICATION_GATEWAY_NAME (rg:$RESOURCE_GROUP) has been skipped from today's $MODE operation schedule"
    fi
  done
done