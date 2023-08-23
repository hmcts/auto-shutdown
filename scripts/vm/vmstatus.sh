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
    VMS=$(az resource list --resource-type Microsoft.Compute/virtualMachines --query "[?tags.autoShutdown == 'true']" -o json)
    jq -c '.[]'<<< $VMS | while read vm
    do
       ID=$(jq -r '.id' <<< $vm)
       status=$(az vm show -d --ids $ID --query "powerState")
       if [[  "$status" =~ .*"deallocated".* ]]; then
        echo -e  "${RED}status of VM in Subscription: $(az account show --query name)  ResourceGroup: $(jq -r '.resourceGroup' <<< $vm)  Name: $(jq -r '.name' <<< $vm) is $status"
       elif [[ "$status" =~ .*"running".* ]]; then
        echo -e "${GREEN}status of VM in Subscription: $(az account show --query name)  ResourceGroup: $(jq -r '.resourceGroup' <<< $vm)  Name: $(jq -r '.name' <<< $vm) is $status" 
       else
        echo -e "${AMBER}status of VM in Subscription: $(az account show --query name)  ResourceGroup: $(jq -r '.resourceGroup' <<< $vm)  Name: $(jq -r '.name' <<< $vm) is $status" 
       fi
    done
done   
