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

CLUSTERS=$(get_clusters "$2")
clusters_count=$(jq -c -r '.count' <<<$CLUSTERS)
log "$clusters_count AKS Clusters found"
log "----------------------------------------------"

jq -c '.data[]' <<<$CLUSTERS | while read cluster; do
  get_cluster_details
  cluster_env=$(echo $CLUSTER_NAME | cut -d'-' -f2)

  if [[ $cluster_env == "sbox" ]]; then
    cluster_env=${cluster_env/#sbox/Sandbox}
  elif [[ $cluster_env == "ptlsbox" ]]; then
    cluster_env=${cluster_env/ptlsbox/Sandbox}
  elif [[ $cluster_env == "stg" ]]; then
    cluster_env=${cluster_env/stg/Staging}
  fi

  cluster_business_area=$(echo $CLUSTER_NAME | cut -d'-' -f1)
  cluster_business_area=${cluster_business_area/ss/cross-cutting}

  log "====================================================="
  log "Processing Cluster: $CLUSTER_NAME"
  log "====================================================="

  log "checking skip logic for cluster_env: $cluster_env, cluster_business_area: $cluster_business_area, mode: $MODE"
  SKIP=$(should_skip_start_stop $cluster_env $cluster_business_area $MODE "aks" "$CLUSTER_NAME")

  log "SKIP evalulated to $SKIP"

  if [[ $SKIP == "false" ]]; then
    if [[ $DEV_ENV != "true" ]]; then
      aks_state_messages
      az aks $MODE --resource-group $RESOURCE_GROUP --name $CLUSTER_NAME --subscription $SUBSCRIPTION --no-wait || echo Ignoring any errors while $MODE operation on cluster

    else
      ts_echo_color BLUE "Development Env: simulating state commands only."
      aks_state_messages
    fi
  else
    ts_echo_color AMBER "cluster $CLUSTER_NAME (rg:$RESOURCE_GROUP) has been skipped from today's $MODE operation schedule"
  fi
done
