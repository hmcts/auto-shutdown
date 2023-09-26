#!/usr/bin/env bash
#set -x
shopt -s nocasematch
AMBER='\033[1;33m'
GREEN='\033[0;32m'
RED='\033[0;31m'
# SUBSCRIPTIONS=$(az account list -o json)
SUBSCRIPTIONS='[
  {
    "id": "b44eb479-9ae2-42e7-9c63-f3c599719b6f",
    "name": "DTS-MANAGEMENT-NONPROD-INTSVC"
  }
]'
jq -c '.[]' <<<$SUBSCRIPTIONS | while read subscription; do
	SUBSCRIPTION_ID=$(jq -r '.id' <<<$subscription)
	SUBSCRIPTION_NAME=$(jq -r '.name' <<<$subscription)
	az account set -s $SUBSCRIPTION_ID
	APPGS=$(az storage account list --query "[?tags.autoShutdown == 'true' || isSftpEnabled]")

	jq -c '.[]' <<<$APPGS | while read app; do

		SKIP="false"
		app_id=$(jq -r '.id' <<<$app)
		name=$(jq -r '.name' <<<$app)
		rg=$(jq -r '.resourceGroup' <<<$app)
		app_env=$(echo $name | awk -F "-" '{ print $(NF) }')
		app_env=${app_env/stg/Staging}
		app_env=${app_env/sbox/Sandbox}
		if [[ $SUBSCRIPTION_NAME =~ "SHAREDSERVICES" ]]; then
			business_area="Cross-Cutting"
		else
			business_area="core"
		fi
			env_entry=$(jq -r '."environment"' <<<$app)
			start_date=$(jq -r '."skip_start_date"' <<<$app)
			end_date=$(jq -r '."skip_end_date"' <<<$app)
			#start date business_area_entry formatting
			start_date_formatting=$(awk -F'-' '{printf("%04d-%02d-%02d\n",$3,$2,$1)}' <<<$start_date)
			start_date_seconds=$(date -d "$start_date_formatting 00:00:00" +%s)
			#end date formatting
			end_date_formatting=$(awk -F'-' '{printf("%04d-%02d-%02d\n",$3,$2,$1)}' <<<$end_date)
			end_date_seconds=$(date -d "$end_date_formatting 00:00:00" +%s)
			#current date formatting
			current_date=$(date +'%d-%m-%Y')
			current_date_formatting=$(awk -F'-' '{printf("%04d-%02d-%02d\n",$3,$2,$1)}' <<<$current_date)
			current_date_seconds=$(date -d "$current_date_formatting 00:00:00" +%s)
			#Skip logic
			#if start date is equal to current date: skip shutdown on that cluster
			if [[ ${env_entry} =~ ${app_env} ]] && [[ $business_area == $business_area_entry ]] && [[ $start_date_seconds -eq $current_date_seconds ]]; then
				echo "Match: $app"
				SKIP="true"
				continue
			#if current date is less than skip end date: skip shutdown on that cluster
			elif [[ ${env_entry} =~ ${app_env} ]] && [[ $business_area == $business_area_entry ]] && [[ $current_date_seconds -ge $start_date_seconds ]] && [[ $current_date_seconds -le $end_date_seconds ]]; then
				echo "Match : $app"
				SKIP="true"
				continue
			fi
		done < <(jq -c '.[]' issues_list.json)
		if [[ $SKIP == "false" ]]; then
			echo -e "${GREEN}About to shutdown flexible server $name (rg:$rg) sub:$SUBSCRIPTION_NAME"
			echo -e "${GREEN}az storage account update -n $name  -g $rg --no-wait"
			az storage account update -n $name -g $rg --no-wait --sftp-status Disabled  || echo Ignoring errors stopping $name
		else
			echo -e "${AMBER}storage account $name (rg:$rg) sub:$SUBSCRIPTION_NAME has been skipped from todays shutdown schedule"
		fi

done
