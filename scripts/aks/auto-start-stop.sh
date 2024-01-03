#!/usr/bin/env bash

shopt -s nocasematch
AMBER='\033[1;33m'
GREEN='\033[0;32m'
source scripts/aks/common-functions.sh
source scripts/common/common-functions.sh

MODE=${1:-start}
SKIP="false"

if [[ "$MODE" != "start" && "$MODE" != "stop" ]]; then
    echo "Invalid MODE. Please use 'start' or 'stop'."
    exit 1
fi

SUBSCRIPTIONS=$(az account list -o json)
jq -c '.[]' <<< $SUBSCRIPTIONS | while read subscription; do
  get_subscription_clusters
  jq -c '.[]' <<< $CLUSTERS | while read cluster; do
    get_cluster_details
    cluster_env=$(echo $CLUSTER_NAME | cut -d'-' -f2)
    cluster_env=${cluster_env/#sbox/Sandbox}
    cluster_env=${cluster_env/stg/Staging}
    cluster_business_area=$(echo $CLUSTER_NAME | cut -d'-' -f1)
    cluster_business_area=${cluster_business_area/ss/cross-cutting}

    SKIP=$(should_skip_start_stop $cluster_env $cluster_business_area $MODE)

    if [[ $SKIP == "false" ]]; then
      echo -e "${GREEN}About to run $MODE operation on cluster $CLUSTER_NAME (rg:$RESOURCE_GROUP)"
      echo az aks $MODE --resource-group $RESOURCE_GROUP --name $CLUSTER_NAME --no-wait || echo Ignoring any errors while $MODE operation on cluster
      if [[ $DRYRUN != "true" ]]; then
        az aks $MODE --resource-group $RESOURCE_GROUP --name $CLUSTER_NAME --no-wait || echo Ignoring any errors while $MODE operation on cluster
      fi
    else
      echo -e "${AMBER}cluster $CLUSTER_NAME (rg:$RESOURCE_GROUP) has been skipped from today's $MODE operation schedule"
    fi
  done
done