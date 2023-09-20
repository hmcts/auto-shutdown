#!/usr/bin/env bash
SUBSCRIPTIONS=$(az account list -o json)
jq -c '.[]' <<< $SUBSCRIPTIONS | while read subcription 
do
    SUBSCRIPTION_ID=$(jq -r '.id' <<< $subcription) 
    az account set -s $SUBSCRIPTION_ID
    SERVERS=$(az resource list --resource-type Microsoft.Sql/managedInstances  --query "[?tags.autoShutdown == 'true']" -o json)
    jq -c '.[]'<<< $SERVERS | while read server
    do
        ID=$(jq -r '.id' <<< $server)
        NAME=$(jq -r '.name' <<< $server)
        status=$(az sql managed-instance show  --ids $ID --query "state")
        if [[  "$status" != *"Ready"* ]]; then
            echo "Starting sql managed-instance show  in Subscription: $(az account show --query name)  ResourceGroup: $(jq -r '.resourceGroup' <<< $server)  Name: $NAME"
            az sql managed-instance start --ids $ID --no-wait || echo Ignoring error starting $NAME
        fi
    done
done 