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

    SERVERS=$(az storage account list --query "[?tags.autoShutdown == null && isSftpEnabled ]")


    jq -c '.[]'<<< $SERVERS | while read server
    do
            echo -e "${GREEN}status of storage account Name: $(jq -r '.name' <<< $server) in Subscription: $(az account show --query name)  ResourceGroup: $(jq -r '.resourceGroup' <<< $server) "
     done
done
