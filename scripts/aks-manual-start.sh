#!/usr/bin/env bash

function subscription () {
    if [[ $PROJECT == "SDS" ]]; then
        SUBSCRIPTION='DTS-SHAREDSERVICES-'$SELECTED_ENV
        PROJECT="SS"
    elif [[ $PROJECT == "CFT" ]]; then
        SUBSCRIPTION='DCD-CFTAPPS-'$SELECTED_ENV
        PROJECT="cft"
    fi

    az account set -n $SUBSCRIPTION
    ts_echo $SUBSCRIPTION selected
}

function cluster () {
        RESOURCE_GROUP=$(jq -r '.resourceGroup' <<< $cluster)
        NAME=$(jq -r '.name' <<< $cluster)
}

function ts_echo() {
    date +"%H:%M:%S $(printf "%s "  "$@")"
}

subscription
for INSTANCE in ${INSTANCES[@]}; do
    CLUSTERS=$(az resource list \
    --name $PROJECT"-"$SELECTED_ENV"-"$INSTANCE"-aks" \
    --query "[?tags.autoShutdown == 'true']" -o json)
    jq -c '.[]' <<< $CLUSTERS | while read cluster; do
        cluster
        
        ts_echo "About to start cluster $NAME (rg:$RESOURCE_GROUP)"
        # az aks start --resource-group $RESOURCE_GROUP --name $NAME --no-wait || ts_echo Ignoring any errors starting cluster $NAME 
        
        ts_echo "Waiting 2 mins to give clusters time to start before testing pods"
        sleep 120
        ts_echo $NAME
        RESULT=$(az aks show --name  $NAME -g $RESOURCE_GROUP | jq -r .powerState.code)
        ts_echo "${RESULT}"
    done
done
