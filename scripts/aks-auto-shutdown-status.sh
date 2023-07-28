#!/usr/bin/env bash
#set -x
shopt -s nocasematch
AMBER='\033[1;33m'
GREEN='\033[0;32m'

SUBSCRIPTIONS=$(az account list -o json)
jq -c '.[]' <<< $SUBSCRIPTIONS | while read subscription; do
    SUBSCRIPTION_ID=$(jq -r '.id' <<< $subscription)
    az account set -s $SUBSCRIPTION_ID
    CLUSTERS=$(az resource list --resource-type Microsoft.ContainerService/managedClusters --query "[?tags.autoShutdown == 'true']" -o json)

jq -c '.[]' <<< $CLUSTERS | while read cluster; do
        RESOURCE_GROUP=$(jq -r '.resourceGroup' <<< $cluster)
        cluster_name=$(jq -r '.name' <<< $cluster)
        cluster_data=$(az aks show -n $cluster_name -g $RESOURCE_GROUP -o json)
        cluster_status=$(jq -r '.powerState.code' <<< "$cluster_data")

        if [[ $cluster_status == "Stopped" ]]; then
            echo -e "${GREEN}$cluster_name is $cluster_status"
        elif [[ $cluster_status == "Running" ]]; then
            echo -e "${AMBER}$cluster_name is $cluster_status"
        fi
    done # end_of_cluster_loop
done
