#!/usr/bin/env bash
#set -x
shopt -s nocasematch
#waiting for clusters to shutdown.
sleep 600

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
        echo "$cluster_name is $cluster_status"
        
    done # end_of_cluster_loop
done
