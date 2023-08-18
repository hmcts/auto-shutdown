#!/usr/bin/env bash
#set -x
shopt -s nocasematch
AMBER='\033[1;33m'
GREEN='\033[0;32m'
SUBSCRIPTIONS=$(az account list -o json)
jq -c '.[]' <<< $SUBSCRIPTIONS | while read subcription 
do
    SUBSCRIPTION_ID=$(jq -r '.id' <<< $subcription) 
    SUBSCRIPTION_NAME=$(jq -r '.name' <<< $subcription) 
    az account set -s $SUBSCRIPTION_ID
    APPGS=$(az resource list --resource-type Microsoft.Network/applicationGateways --query "[?tags.autoShutdown == 'true']" -o json)
 
   
    jq -c '.[]'<<< $APPGS | while read app
    do
        SKIP="false"
        app_id=$(jq -r '.id' <<< $app)
        name=$(jq -r '.name' <<< $app)
        rg=$(jq -r '.resourceGroup' <<< $app)
        app_env=$(echo $name | awk -F "-" '{ print $(NF-1) }')
        app_env=${app_env/stg/Staging}
        app_env=${app_env/sbox/Sandbox} 
        if [[ $SUBSCRIPTION_NAME =~ "CFTAPPS-" ]]; then
            business_area="CFT"
        elif [[ $SUBSCRIPTION_NAME =~ "SHAREDSERVICES-" ]]; then
            business_area="Cross-Cutting" 
        fi
	echo "---------------------------------------------------"
        while read id
        do
            business_area_entry=$(jq -r '."business_area"' <<< $id)
            env_entry=$(jq -r '."environment"' <<< $id)
            start_date=$(jq -r '."skip_start_date"' <<< $id)
            end_date=$(jq -r '."skip_end_date"' <<< $id)
            #start date business_area_entry formatting
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
            if [[ ${env_entry} =~ ${app_env} ]] && [[ $rg =~  "network-rg" ]] && [[ $business_area_entry == $business_area ]] && [[ $start_date_seconds -eq $current_date_seconds ]] ; then
                echo "Match: $id"
                SKIP="true"
                continue
            #if current date is less than skip end date: skip shutdown on that cluster
            elif [[ ${env_entry} =~ ${app_env} ]] && [[ $rg =~ "network-rg" ]] && [[ $business_area_entry == $business_area ]] && [[ $current_date_seconds -ge $start_date_seconds ]] &&[[ $current_date_seconds -le $end_date_seconds ]]; then
                echo "Match : $id"
                SKIP="true"
                continue
            fi
        done < <(jq -c '.[]' issues_list.json)
        if [[ $SKIP == "false" ]]; then
            echo -e "${GREEN}About to shutdown App Gateway $name (rg:$rg) sub:$SUBSCRIPTION_NAME"
            echo -e "${GREEN}az network application-gateway stop --ids ${app_id} --no-wait"
            ##### enable it as part of rollout(sprint 72)
            ##az network application-gateway stop --ids ${app_id} --no-wait || echo Ignoring any errors stopping App Gateway
        else
            echo -e "${AMBER}App Gateway $name (rg:$rg) sub:$SUBSCRIPTION_NAME has been skipped from todays shutdown schedule"
        fi

    done
done 