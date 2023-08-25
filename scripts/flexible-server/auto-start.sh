#!/usr/bin/env bash
SUBSCRIPTIONS=$(az account list -o json)
jq -c '.[]' <<< $SUBSCRIPTIONS | while read subcription 
do
    SUBSCRIPTION_ID=$(jq -r '.id' <<< $subcription) 
    az account set -s $SUBSCRIPTION_ID
    SERVERS=$(az resource list --resource-type Microsoft.DBforPostgreSQL/flexibleServers  --query "[?tags.autoShutdown == 'true']" -o json)
    jq -c '.[]'<<< $SERVERS | while read server
    do
        ID=$(jq -r '.id' <<< $server)
        NAME=$(jq -r '.name' <<< $server)
        status=$(az postgres flexible-server show  --ids $ID --query "state")
        if [[  "$status" != *"Ready"* ]]; then
            echo "Starting flexible-server show  in Subscription: $(az account show --query name)  ResourceGroup: $(jq -r '.resourceGroup' <<< $server)  Name: $NAME"
            az postgres flexible-server start --ids $ID --no-wait || echo Ignoring error starting $NAME
        fi
    done
done   
