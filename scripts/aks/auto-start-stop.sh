#!/usr/bin/env bash

shopt -s nocasematch
AMBER='\033[1;33m'
GREEN='\033[0;32m'
source scripts/aks/common-functions.sh

MODE=${1:-start}
registrySlackWebhook=$1
SKIP="false"

if [[ "$MODE" != "start" && "$MODE" != "stop" ]]; then
    echo "Invalid MODE. Please use 'start' or 'stop'."
    exit 1
fi

SUBSCRIPTIONS=$(az account list -o json)
jq -c '.[]' <<< $SUBSCRIPTIONS | while read subscription; do
  subscription
  jq -c '.[]' <<< $CLUSTERS | while read cluster; do
    cluster
    cluster_env=$(echo $CLUSTER_NAME | cut -d'-' -f2)
    cluster_env=${cluster_env/#sbox/Sandbox}
    cluster_env=${cluster_env/stg/Staging}
    cluster_business_area=$(echo $CLUSTER_NAME | cut -d'-' -f1)
    cluster_business_area=${cluster_business_area/ss/cross-cutting}
    if [[ $MODE == "stop" ]]; then
      SKIP=$(should_skip_shutdown $cluster_env $cluster_business_area)
    fi
    if [[ $SKIP == "false" ]]; then
      echo -e "${GREEN}About to run $MODE operation on cluster $CLUSTER_NAME (rg:$RESOURCE_GROUP)"
      echo az aks $MODE --resource-group $RESOURCE_GROUP --name $CLUSTER_NAME --no-wait || echo Ignoring any errors while $MODE operation on cluster
      az aks $MODE --resource-group $RESOURCE_GROUP --name $CLUSTER_NAME --no-wait || echo Ignoring any errors while $MODE operation on cluster
    else
      echo -e "${AMBER}cluster $CLUSTER_NAME (rg:$RESOURCE_GROUP) has been skipped from today's $MODE operation schedule"
    fi
  done
done

if [[ $MODE == "start" ]]; then
  echo "Waiting 10 mins to give clusters time to start before testing pods"
  sleep 600

  jq -c '.[]' <<< $SUBSCRIPTIONS | while read subscription; do
      subscription
      jq -c '.[]' <<< $CLUSTERS | while read cluster; do
          cluster
          check_cluster_status
          POWER_STATE=$(az aks show --name  $CLUSTER_NAME -g $RESOURCE_GROUP | jq -r .powerState.code)
          ts_echo "cluster: $CLUSTER_NAME, Power State : ${POWER_STATE}"
      done
  done
fi