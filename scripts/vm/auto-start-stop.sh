#!/usr/bin/env bash
# set -x
shopt -s nocasematch

# Source shared function scripts
source scripts/vm/common-functions.sh
source scripts/common/common-functions.sh

MODE=${1:-start}
SKIP="false"

if [[ "$MODE" != "start" && "$MODE" != "stop" ]]; then
	echo "Invalid MODE. Please use 'start' or 'stop'."
	exit 1
fi

SUBSCRIPTIONS=$(az account list -o json)
SORTED_SUBSCRIPTIONS=$(jq -r '[
    ( .[] | select(.name != "HMCTS-HUB-NONPROD-INTSVC" )),
    ( .[] | select(.name == "HMCTS-HUB-NONPROD-INTSVC" ))
]' <<<$SUBSCRIPTIONS)
IS_HUB_NEEDED="false"

jq -c '.[]' <<< $SORTED_SUBSCRIPTIONS | while read subscription; do

	get_subscription_vms
	echo "Scanning $SUBSCRIPTION_NAME..."

    if [[ $SUBSCRIPTION_NAME == "HMCTS-HUB-NONPROD-INTSVC" && $IS_HUB_NEEDED == "true" && $MODE == "stop" ]]; then
		continue
	fi
    
    jq -c '.[]' <<<$VMS | while read vm; do

        get_vm_details

        declare -a vm_envs=(
            [sandbox]="sbox"
            [testing]="test"
            [staging]="aat"
            [development]="dev"
            [production]="prod"
            [demo]="demo"
            [ithc]="ithc"
        )

        if [[ "${vm_envs[$VM_ENVIRONMENT]}" ]]; then
            ENV_SUFFIX="${vm_envs[$VM_ENVIRONMENT]}"
        else
            ENV_SUFFIX="$VM_ENVIRONMENT"
        fi
		
        SKIP=$(should_skip_start_stop $ENV_SUFFIX $VM_BUSINESS_AREA $MODE) 
		if [[ $SKIP == "false" ]]; then
            ts_echo_color GREEN "About to run $MODE operation on VM: $VM_NAME in Resource Group: $RESOURCE_GROUP"
            ts_echo_color GREEN  "Command to run: az vm $MODE --ids $VM_ID --no-wait || echo Ignoring any errors while $MODE operation on vm"
            az vm $MODE --ids $VM_ID --no-wait || echo Ignoring any errors while $MODE operation on vm
        else
            ts_echo_color AMBER "VM: $VM_NAME in Resource Group: $RESOURCE_GROUP has been skipped from today's $MODE operation schedule"
            IS_HUB_NEEDED="true"
        fi
	done
done