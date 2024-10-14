#!/usr/bin/env bash
#set -x
shopt -s nocasematch
AMBER='\033[1;33m'
GREEN='\033[0;32m'

source scripts/aks/common-functions.sh
source scripts/common/common-functions.sh

MODE=${1:-start}
registrySlackWebhook=$2

CLUSTERS=$(get_clusters)
clusters_count=$(jq -c -r '.count' <<<$CLUSTERS)
log "$clusters_count AKS Clusters found"
log "----------------------------------------------"

jq -c '.data[]' <<<$CLUSTERS | while read cluster; do
    get_cluster_details

    if [[ $cluster_status == "Stopped" ]]; then
        echo -e "${GREEN}$CLUSTER_NAME is $cluster_status"
    elif [[ $cluster_status == "Running" ]]; then
        echo -e "${AMBER}$CLUSTER_NAME is $cluster_status"
    fi
    if [[ $MODE == "start" ]]; then
        check_cluster_status
    fi
done
