#!/usr/bin/env bash
#set -x
shopt -s nocasematch
AMBER='\033[1;33m'
GREEN='\033[0;32m'

SUBSCRIPTIONS=$(az account list -o json)
jq -c '.[]' <<< $SUBSCRIPTIONS | while read subscription; do
    SUBSCRIPTION_ID=$(jq -r '.id' <<< $subscription)
    az account set -s $SUBSCRIPTION_ID
    CLUSTERS=$(az resource list --resource-type Microsoft.ContainerService/managedClusters --query "[?tags.autoShutdown == 'true']" -o json)

jq -c '.[]' <<< $CLUSTERS | while read cluster; do
        RESOURCE_GROUP=$(jq -r '.resourceGroup' <<< $cluster)
        SKIP="false"
        cluster_name=$(jq -r '.name' <<< $cluster)
        echo "---------------------"
        cluster_env=$(echo $cluster_name|cut -d'-' -f2)
        cluster_env=${cluster_env/#sbox/Sandbox}
        cluster_env=${cluster_env/stg/Staging}
        cluster_business_area=$(echo $cluster_name|cut -d'-' -f1)
        cluster_business_area=${cluster_business_area/ss/cross-cutting}
        echo $cluster_name $cluster_business_area $cluster_env
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
            #if start date is equal to current date: skip shutdown on that cluster
            if [[ ${env_entry} =~ ${cluster_env} ]] && [[ $cluster_business_area == $business_area_entry ]] && [[ $start_date_seconds -eq $current_date_seconds ]] ; then
                echo "Match: $id"
                SKIP="true"
                continue
            #if current date is less than skip end date: skip shutdown on that cluster
            elif [[ ${env_entry} =~ ${cluster_env} ]] && [[ $cluster_business_area == $business_area_entry ]] && [[ $current_date_seconds -ge $start_date_seconds ]] &&[[ $current_date_seconds -le $end_date_seconds ]]; then
                echo "Match : $id"
                SKIP="true"
                continue
            fi
        done < <(jq -c '.[]' issues_list.json)
        if [[ $SKIP == "false" ]]; then
            echo -e "${GREEN}About to shutdown cluster $cluster_name (rg:$RESOURCE_GROUP)"
            echo az aks stop --resource-group $RESOURCE_GROUP --name $cluster_name --no-wait || echo Ignoring any errors stopping cluster
            az aks stop --resource-group $RESOURCE_GROUP --name $cluster_name --no-wait || echo Ignoring any errors stopping cluster
        else
            echo -e "${AMBER}cluster $cluster_name (rg:$RESOURCE_GROUP) has been skipped from todays shutdown schedule"
        fi
    done # end_of_cluster_loop
done
