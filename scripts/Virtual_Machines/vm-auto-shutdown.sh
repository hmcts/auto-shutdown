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

jq -c '.[]' <<< $virtualMachines | while read virtualMachines; do
        RESOURCE_GROUP=$(jq -r '.resourceGroup' <<< $virtualMachines)
        SKIP="false"
        virtualMachines_name=$(jq -r '.name' <<< $virtualMachines)
        echo "---------------------"
        virtualMachines_env=$(echo $virtualMachines_name|cut -d'-' -f2)
        virtualMachines_env=${virtualMachines_env/#sbox/Sandbox}
        virtualMachines_env=${virtualMachines_env/stg/Staging}
        virtualMachines_business_area=$(echo $virtualMachines_name|cut -d'-' -f1)
        virtualMachines_business_area=${virtualMachines_business_area/ss/cross-cutting}
        echo $virtualMachines_name $virtualMachines_business_area $virtualMachines_env
        while read id
        do
            business_area_entry=$(jq -r '."business_area"' <<< $id)
            env_entry=$(jq -r '."environment"' <<< $id)
            start_date=$(jq -r '."skip_start_date"' <<< $id)
            end_date=$(jq -r '."skip_end_date"' <<< $id)
            #start date formatting
            start_date_formatting=$(awk -F'-' '{printf("%04d-%02d-%02d\n",$3,$2,$1)}' <<< $start_date)
            start_date_seconds=$(date -d "$start_date_formatting 00:00:00" +%s)
            #end date formatting
            end_date_formatting=$(awk -F'-' '{printf("%04d-%02d-%02d\n",$3,$2,$1)}' <<< $end_date)
            end_date_seconds=$(date -d "$end_date_formatting 00:00:00" +%s)
            #current date formatting
            current_date=$(date +'%d-%m-%Y')
            current_date_formatting=$(awk -F'-' '{printf("%04d-%02d-%02d\n",$3,$2,$1)}' <<< $current_date)
            current_date_seconds=$(date -d "$current_date_formatting 00:00:00" +%s)
            #Skip logic
            #if start date is equal to current date: skip shutdown on that virtualMachines
            if [[ ${env_entry} =~ ${virtualMachines_env} ]] && [[ $virtualMachines_business_area == $business_area_entry ]] && [[ $start_date_seconds -eq $current_date_seconds ]] ; then
                echo "Match: $id"
                SKIP="true"
                continue
            #if current date is less than skip end date: skip shutdown on that virtualMachines
            elif [[ ${env_entry} =~ ${virtualMachines_env} ]] && [[ $virtualMachines_business_area == $business_area_entry ]] && [[ $current_date_seconds -ge $start_date_seconds ]] &&[[ $current_date_seconds -le $end_date_seconds ]]; then
                echo "Match : $id"
                SKIP="true"
                continue
            fi
        done < <(jq -c '.[]' issues_list.json)
        if [[ $SKIP == "false" ]]; then
            echo -e "${GREEN}About to shutdown virtualMachines $virtualMachines_name (rg:$RESOURCE_GROUP)"
            echo az vm stop --resource-group $RESOURCE_GROUP --name $virtualMachines_name --no-wait || echo Ignoring any errors stopping virtualMachines
            az vm stop --resource-group $RESOURCE_GROUP --name $virtualMachines_name --no-wait || echo Ignoring any errors stopping virtualMachines
        else
            echo -e "${AMBER}virtualMachines $virtualMachines_name (rg:$RESOURCE_GROUP) has been skipped from todays shutdown schedule"
        fi
    done # end_of_virtualMachines_loop
done
