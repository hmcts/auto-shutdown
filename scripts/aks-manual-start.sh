#!/usr/bin/env bash

function subscription () {
    if [[ $SELECTED_ENV == "test/perftest" && $PROJECT == "SDS" ]]; then
        PROJECT="ss"
        SELECTED_ENV="test"
        SUBSCRIPTION='DTS-SHAREDSERVICES-'$SELECTED_ENV
    elif [[ $SELECTED_ENV == "test/perftest" && $PROJECT == "CFT" ]]; then
        SELECTED_ENV="perftest"
        SUBSCRIPTION='DCD-CFTAPPS-TEST'
    elif [[ $SELECTED_ENV == "ptlsbox" && $PROJECT == "SDS" ]]; then
        PROJECT="ss"
        SUBSCRIPTION='DTS-SHAREDSERVICESPTL-SBOX'
    elif [[ $SELECTED_ENV == "ptlsbox" && $PROJECT == "CFT" ]]; then
        SUBSCRIPTION='DTS-CFTSBOX-INTSVC'
    elif [[ $SELECTED_ENV != "test/perftest" && $SELECTED_ENV != "ptlsbox" && $PROJECT == "SDS" ]]; then
        PROJECT="ss"
        SUBSCRIPTION='DTS-SHAREDSERVICES-'$SELECTED_ENV
    elif [[ $SELECTED_ENV != "test/perftest" && $SELECTED_ENV != "ptlsbox" && $PROJECT == "CFT" ]]; then
        SUBSCRIPTION='DCD-CFTAPPS-'$SELECTED_ENV
    fi

    if [[ $INSTANCES == 'All' ]]; then
        INSTANCES=(00 01)
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
        az aks start --resource-group $RESOURCE_GROUP --name $NAME --no-wait || ts_echo Ignoring any errors starting cluster $NAME 
        
        ts_echo "Waiting 2 mins to give clusters time to start before testing pods"
        sleep 120
        ts_echo $NAME
        RESULT=$(az aks show --name  $NAME -g $RESOURCE_GROUP | jq -r .powerState.code)
        ts_echo "${RESULT}"
    done
done
