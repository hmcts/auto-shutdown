#!/usr/bin/env bash
#set -x
AMBER='\033[1;33m'
GREEN='\033[0;32m'
RED='\033[0;31m'
SUBSCRIPTIONS=$(az account list -o json)
jq -c '.[]' <<< $SUBSCRIPTIONS | while read subcription 
do
    SUBSCRIPTION_ID=$(jq -r '.id' <<< $subcription) 
    az account set -s $SUBSCRIPTION_ID
    APPGS=$(az resource list --resource-type Microsoft.Network/applicationGateways --query "[?tags.autoShutdown == 'true']" -o json)
    jq -c '.[]'<<< $APPGS | while read appg
    do
       ID=$(jq -r '.id' <<< $appg)
       status=$(az network application-gateway show --ids $ID --query "operationalState")
       if [[  "$status" =~ .*"Stopped".* ]]; then
            echo -e  "${RED}status of App Gateway Name: $(jq -r '.name' <<< $appg) in Subscription: $(az account show --query name)  ResourceGroup: $(jq -r '.resourceGroup' <<< $appg) is $status"
       elif [[ "$status" =~ .*"Running".* ]]; then
            echo -e "${GREEN}status of App Gateway Name: $(jq -r '.name' <<< $appg) in Subscription: $(az account show --query name)  ResourceGroup: $(jq -r '.resourceGroup' <<< $appg) is $status" 
       else
            echo -e "${AMBER}status of App Gateway Name: $(jq -r '.name' <<< $appg) in Subscription: $(az account show --query name)  ResourceGroup: $(jq -r '.resourceGroup' <<< $appg) is $status" 
       fi
    done
done   
