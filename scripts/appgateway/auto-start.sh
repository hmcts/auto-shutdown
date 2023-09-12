#!/usr/bin/env bash
set -x
SUBSCRIPTIONS=$(az account list -o json)
jq -c '.[]' <<< $SUBSCRIPTIONS | while read subcription 
do
    SUBSCRIPTION_ID=$(jq -r '.id' <<< $subcription) 
    az account set -s $SUBSCRIPTION_ID
    APPGS=$(az resource list --resource-type Microsoft.Network/applicationGateways  --query "[?tags.autoShutdown == 'true']" -o json)
    jq -c '.[]'<<< $APPGS | while read appg
    do
        ID=$(jq -r '.id' <<< $appg)
        status=$(az network application-gateway  show  --ids $ID --query "operationalState")
        if [[  "$status" != *"Running"* ]]; then
            echo "Starting APP Gateway in Subscription: $(az account show --query name)  ResourceGroup: $(jq -r '.resourceGroup' <<< $appg)  Name: $(jq -r '.name' <<< $appg)"
            az network application-gateway start --ids $ID --no-wait || echo Ignoring errors Stopping VM 
        fi
    done
done   
