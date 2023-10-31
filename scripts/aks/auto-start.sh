#!/usr/bin/env bash

registrySlackWebhook=$1

source scripts/aks/common-functions.sh

function process_clusters() {
    jq -c '.[]' <<< $SUBSCRIPTIONS | while read subscription; do
        subscription
        jq -c '.[]' <<< $CLUSTERS | while read cluster; do
            cluster
            ts_echo "About to start cluster $CLUSTER_NAME (rg:$RESOURCE_GROUP)"
            az aks start --resource-group $RESOURCE_GROUP --name $CLUSTER_NAME --no-wait || ts_echo Ignoring any errors starting cluster $CLUSTER_NAME
        done
    done

    echo "Waiting 10 mins to give clusters time to start before testing pods"
    sleep 600

     jq -c '.[]' <<< $SUBSCRIPTIONS | while read subscription; do
        subscription
        jq -c '.[]' <<< $CLUSTERS | while read cluster; do
            cluster
            check_cluster_status
            POWER_STATE=$(az aks show --name  $CLUSTER_NAME -g $RESOURCE_GROUP | jq -r .powerState.code)
            ts_echo "cluster: $CLUSTER_NAME, Power State : ${RESULT}"
        done
      done
}

SUBSCRIPTIONS=$(az account list -o json)
process_clusters
