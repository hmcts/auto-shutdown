#!/usr/bin/env bash
registrySlackWebhook=$1

INSTANCES=(00 01)

function subscription () {
    if [[ $PROJECT == "SDS" ]]; then
        SUBSCRIPTION='DTS-SHAREDSERVICES-'$SELECTED_ENV
    elif [[ $PROJECT == "CFT" ]]; then
        SUBSCRIPTION='DCD-CFTAPPS-'$SELECTED_ENV
    fi

    az account set -n $SUBSCRIPTION
    echo $SUBSCRIPTION selected
}

function cluster () {
        RESOURCE_GROUP=$(jq -r '.resourceGroup' <<< $cluster)
        NAME=$(jq -r '.name' <<< $cluster)
}

function ts_echo() {
    date +"%H:%M:%S $(printf "%s "  "$@")"
}

function notification() {
            ts_echo "$APP works in $ENVIRONMENT after $NAME start-up"
            curl -X POST --data-urlencode "payload={\"channel\": \"#aks-monitor-$ENV\", \"username\": \"AKS Auto-Start\", \"text\": \"$APP works in $ENVIRONMENT after $NAME start-up.\", \"icon_emoji\": \":tim-webster:\"}" \
            ${registrySlackWebhook}
}

subscription
    for INSTANCE in ${INSTANCES[@]}; do
        CLUSTERS=$(az resource list \
        --name $PROJECT-$SELECTED_ENV-$INSTANCE-aks \
        --query "[?tags.autoShutdown == 'true']" -o json)
        cluster

    jq -c '.[]' <<< $CLUSTERS | while read cluster; do
        cluster
        ts_echo "About to start cluster $NAME (rg:$RESOURCE_GROUP)"
        # az aks start --resource-group $RESOURCE_GROUP --name $NAME --no-wait || ts_echo Ignoring any errors starting cluster $NAME 
        
        echo "Waiting 2 mins to give clusters time to start before testing pods"
        sleep 600

        RESULT=$(az aks show --name  $NAME -g $RESOURCE_GROUP | jq -r .powerState.code)
        ts_echo "${RESULT}"
    done
done
