#!/usr/bin/env bash

shopt -s nocasematch
AMBER='\033[1;33m'
GREEN='\033[0;32m'
source scripts/aks/common-functions.sh

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
    SKIP=$(should_skip_shutdown $cluster_env $cluster_business_area)

    if [[ $SKIP == "false" ]]; then
      echo -e "${GREEN}About to shutdown cluster $CLUSTER_NAME (rg:$RESOURCE_GROUP)"
      echo az aks stop --resource-group $RESOURCE_GROUP --name $CLUSTER_NAME --no-wait || echo Ignoring any errors stopping cluster
      az aks stop --resource-group $RESOURCE_GROUP --name $CLUSTER_NAME --no-wait || echo Ignoring any errors stopping cluster
    else
      echo -e "${AMBER}cluster $CLUSTER_NAME (rg:$RESOURCE_GROUP) has been skipped from today's shutdown schedule"
    fi
  done
done
