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

for row in $(echo "$SORTED_SUBSCRIPTIONS" | jq -r '.[] | @base64' ); do
    
    _jq() {
    echo ${row} | base64 --decode | jq -r ${1}
    }

    SUBSCRIPTION_ID=$(_jq '.id')
    SUBSCRIPTION_NAME=$(_jq '.name')
    az account set -s $SUBSCRIPTION_ID
    VMS=$(az resource list --resource-type Microsoft.Compute/virtualMachines --query "[?tags.autoShutdown == 'true']" -o json)
    
    if [[ $SUBSCRIPTION_NAME == "HMCTS-HUB-NONPROD-INTSVC" && $IS_HUB_NEEDED == "true" && $MODE == "stop" ]]; then
		continue
	fi
    
    for vm_row in $(echo "$VMS" | jq -r '.[] | @base64' ); do
        _jq_vm() {
        echo ${vm_row} | base64 --decode | jq -r ${1}
        }
        RESOURCE_GROUP=$(_jq_vm '.resourceGroup')
        VM_NAME=$(_jq_vm '.name')
        STARTUP_MODE=$(_jq_vm '.tags.startupMode')
		ID=$(_jq_vm '.id')
        ENVIRONMENT=$(_jq_vm '.tags.environment')
        VM_BUSINESS_AREA=$(_jq_vm '.tags.businessArea')
        declare -A vm_envs=(
            [sandbox]="sbox"
            [testing]="test"
            [staging]="aat"
            [development]="dev"
            [production]="prod"
            [demo]="demo"
            [ithc]="ithc"
        )
        if [[ "${vm_envs[$ENVIRONMENT]}" ]]; then
            ENV_SUFFIX="${vm_envs[$ENVIRONMENT]}"
        else
            ENV_SUFFIX="$ENVIRONMENT"
        fi
		status=$(az vm show -d --ids $ID --query "powerState")
        SKIP=$(should_skip_start_stop $ENV_SUFFIX $VM_BUSINESS_AREA $MODE) 
		if [[ $SKIP == "false" ]]; then
            echo -e "${GREEN}About to run $MODE operation on vm $VM_NAME (rg:$RESOURCE_GROUP)"
            echo az vm $MODE --ids $ID --no-wait || echo Ignoring any errors while $MODE operation on vm
            az vm $MODE --ids $ID --no-wait || echo Ignoring any errors while $MODE operation on vm
        else
            echo -e "${AMBER}vm $VM_NAME (rg:$RESOURCE_GROUP) has been skipped from today's $MODE operation schedule"
            IS_HUB_NEEDED="true"
        fi
	done
done