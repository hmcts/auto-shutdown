#!/usr/bin/env bash
#set -x
shopt -s nocasematch
AMBER='\033[1;33m'
GREEN='\033[0;32m'

SUBSCRIPTIONS=$(az account list -o json)
jq -c '.[]' <<< $SUBSCRIPTIONS | while read subscription; do
    SUBSCRIPTION_ID=$(jq -r '.id' <<< $subscription)
    az account set -s $SUBSCRIPTION_ID
   virtualMachines=$(az resource list --resource-type Microsoft.Compute/virtualMachines --query "[?tags.autoShutdown == 'true']" -o json)

jq -c '.[]' <<< $virtualMachines | while read cluster; do
        RESOURCE_GROUP=$(jq -r '.resourceGroup' <<< $vm)
                virtualMachines_name=$(jq -r '.name' <<< $virtualMachines)
                virtualMachines_data=$(az vm show -n $virtualMachines_name -g $RESOURCE_GROUP -o json)
        virtualMachines_status=$(jq -r '.powerState.code' <<< "$virtualMachines_data")

        if [[ $virtualMachines_status == "Stopped" ]]; then
            echo -e "${GREEN}$virtualMachines_name is $virtualMachines_status"
        elif [[ $virtualMachines_status == "Running" ]]; then
            echo -e "${AMBER}$virtualMachines is $virtualMachines_status"
        fi
    done # end_of_vm_loop
done