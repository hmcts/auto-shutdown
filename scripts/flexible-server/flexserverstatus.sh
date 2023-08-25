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
    SERVERS=$(az resource list --resource-type Microsoft.DBforPostgreSQL/flexibleServers --query "[?tags.autoShutdown == 'true']" -o json)
    
    jq -c '.[]'<<< $SERVERS | while read server
    do
       ID=$(jq -r '.id' <<< $server)
       status=$(az postgres flexible-server show --ids $ID --query "state")
       if [[  "$status" =~ .*"Stopped".* ]]; then
            echo -e  "${RED}status of postgres flexible-server Name: $(jq -r '.name' <<< $server) in Subscription: $(az account show --query name)  ResourceGroup: $(jq -r '.resourceGroup' <<< $server) is $status"
       elif [[ "$status" =~ .*"Ready".* ]]; then
            echo -e "${GREEN}status of postgres flexible-server Name: $(jq -r '.name' <<< $server) in Subscription: $(az account show --query name)  ResourceGroup: $(jq -r '.resourceGroup' <<< $server) is $status" 
       else
            echo -e "${AMBER}status of postgres flexible-server Name: $(jq -r '.name' <<< $server) in Subscription: $(az account show --query name)  ResourceGroup: $(jq -r '.resourceGroup' <<< $server) is $status" 
       fi
    done
done   
