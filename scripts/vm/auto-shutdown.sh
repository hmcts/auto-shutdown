#!/usr/bin/env bash
#set -x
shopt -s nocasematch
AMBER='\033[1;33m'
GREEN='\033[0;32m'
RED='\033[0;31m'
SUBSCRIPTIONS=$(az account list -o json)
SKIP_HUB="false"
while read subcription; do
	SUBSCRIPTION_ID=$(jq -r '.id' <<<$subcription)
	SUBSCRIPTION_NAME=$(jq -r '.name' <<<$subcription)
	if [[ $SUBSCRIPTION_NAME == "HMCTS-HUB-NONPROD-INTSVC" ]]; then
		continue
	fi
	az account set -s $SUBSCRIPTION_ID
	APPGS=$(az resource list --resource-type Microsoft.Compute/virtualMachines --query "[?tags.autoShutdown == 'true']" -o json)
	while read app; do
		SKIP="false"
		app_id=$(jq -r '.id' <<<$app)
		name=$(jq -r '.name' <<<$app)
		rg=$(jq -r '.resourceGroup' <<<$app)
		app_env=$(echo $SUBSCRIPTION_NAME | awk -F "-" '{ print $(NF) }')
		app_env=${app_env/stg/Staging}
		app_env=${app_env/sbox/Sandbox}
		app_env=${app_env/SHAREDSERVICESPTL/PTL}
		if [[ $SUBSCRIPTION_NAME =~ "SHAREDSERVICES" ]]; then
			business_area="Cross-Cutting"
		else
			business_area="CFT"
		fi

		while read id; do
			business_area_entry=$(jq -r '."business_area"' <<<$id)
			env_entry=$(jq -r '."environment"' <<<$id)
			start_date=$(jq -r '."start_date"' <<<$id)
			end_date=$(jq -r '."end_date"' <<<$id)
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
			echo business_area_from_form: $business_area_entry business_area: $business_area :: $env_entry $app_env :: $start_date $end_date $start_date_seconds $current_date_seconds
			if [[ ${env_entry} =~ ${app_env} ]] && [[ $business_area == $business_area_entry ]] && [[ $start_date_seconds -eq $current_date_seconds ]]; then
				echo "Match: $id"
				SKIP="true"
				SKIP_HUB="true"
				continue
			#if current date is less than skip end date: skip shutdown on that cluster
			elif [[ ${env_entry} =~ ${app_env} ]] && [[ $business_area == $business_area_entry ]] && [[ $current_date_seconds -ge $start_date_seconds ]] && [[ $current_date_seconds -le $end_date_seconds ]]; then
				echo "Match : $id"
				SKIP="true"
				SKIP_HUB="true"
				continue
			fi
		done < <(jq -c '.[]' issues_list.json)
	
		if [[ $SKIP == "false" ]]; then
			echo "Stopping VM in Subscription: $SUBSCRIPTION_NAME  ResourceGroup: $rg  Name: $name"
			az vm deallocate --ids $app_id --no-wait || echo Ignoring errors Stopping VM
		else
			echo -e "${AMBER}VM $name (rg:$rg) sub:$SUBSCRIPTION_NAME has been skipped from todays shutdown schedule"
		fi

	done < <(jq -c '.[]' <<<$APPGS)
done < <(jq -c '.[]' <<<$SUBSCRIPTIONS)

# vm in subscription HMCTS-HUB-NONPROD-INTSVC will be skipped if any one of the non-prod env are skipped.
if [[ $SKIP_HUB == "false" ]]; then
	az account set -s "HMCTS-HUB-NONPROD-INTSVC"
	APPGS=$(az resource list --resource-type Microsoft.Compute/virtualMachines --query "[?tags.autoShutdown == 'true']" -o json)

	jq -c '.[]' <<<$APPGS | while read app; do
		SKIP="false"
		app_id=$(jq -r '.id' <<<$app)
		name=$(jq -r '.name' <<<$app)
		rg=$(jq -r '.resourceGroup' <<<$app)
		echo "Stopping VM in Subscription: $SUBSCRIPTION_NAME  ResourceGroup: $rg  Name: $name"
		az vm deallocate --ids $app_id --no-wait || echo Ignoring errors Stopping VM
	done
fi

