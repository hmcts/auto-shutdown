#!/usr/bin/env bash
#set -x
shopt -s nocasematch
AMBER='\033[1;33m'
GREEN='\033[0;32m'

source scripts/aks/common-functions.sh

MODE=${1:-start}
registrySlackWebhook=$2

SUBSCRIPTIONS=$(az account list -o json)
jq -c '.[]' <<< $SUBSCRIPTIONS | while read subscription; do
    get_subscription_clusters

jq -c '.[]' <<< $CLUSTERS | while read cluster; do
    get_cluster_details
    cluster_data=$(az aks show -n $CLUSTER_NAME -g $RESOURCE_GROUP -o json)
    cluster_status=$(jq -r '.powerState.code' <<< "$cluster_data")

    if [[ $cluster_status == "Stopped" ]]; then
        echo -e "${GREEN}$CLUSTER_NAME is $cluster_status"
    elif [[ $cluster_status == "Running" ]]; then
        echo -e "${AMBER}$CLUSTER_NAME is $cluster_status"
    fi
    if [[ $MODE == "start" ]]; then
      check_cluster_status
    fi
done
