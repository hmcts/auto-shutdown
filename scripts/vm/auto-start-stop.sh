#!/usr/bin/env bash

shopt -s nocasematch
AMBER='\033[1;33m'
GREEN='\033[0;32m'
RED='\033[0;31m'
source scripts/vm/common-functions.sh

MODE=${1:-start}
SKIP="false"

if [[ "$MODE" != "start" && "$MODE" != "stop" ]]; then
    echo "Invalid MODE. Please use 'start' or 'stop'."
    exit 1
fi

SUBSCRIPTIONS=$(az account list -o json)

jq -c '.[]' <<<$SUBSCRIPTIONS | while read subscription; do
	get_subscription_vms
    # set -x
	jq -c '.[]' <<<$VMS | while read vm; do
        get_vm_details
		ID=$(jq -r '.id' <<<$vm)
        name=$(jq -r '.name' <<<$vm)
        rg=$(jq -r '.resourceGroup' <<<$vm)
        set -x
        ENVIRONMENT=$(jq -r '.tags.environment' <<<$vm)
        vm_envs=(
            [sandbox]="sbox"
            [testing]="test"
            [testing]="perftest"
            [staging]="aat"
            [development]="dev"
            [production]="prod"
            [demo]="demo"
            [ithc]="ithc"
        )
        if [ -v "${vm_envs[$ENVIRONMENT]}" ]; then
            ENV_SUFFIX="${vm_envs[$ENVIRONMENT]}"
        else
            ENV_SUFFIX="$ENVIRONMENT"
        fi
        vm_business_area=$(jq -r '.tags.businessArea' <<<$vm)
		status=$(az vm show -d --ids $ID --query "powerState")

        SKIP=$(should_skip_start_stop $ENV_SUFFIX $vm_business_area $MODE) 

		if [[ $SKIP == "false" ]]; then
            echo -e "${GREEN}About to run $MODE operation on vm $VM_NAME (rg:$RESOURCE_GROUP)"
            echo az vm $MODE --ids $ID --no-wait || echo Ignoring any errors while $MODE operation on vm
            # az vm $MODE --ids $ID --no-wait || echo Ignoring any errors while $MODE operation on vm
        else
            echo -e "${AMBER}vm $VM_NAME (rg:$RESOURCE_GROUP) has been skipped from today's $MODE operation schedule"
        fi
        
	done
done