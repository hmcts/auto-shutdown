#!/usr/bin/env bash
# set -x
shopt -s nocasematch

# Source shared function scripts
source scripts/vm/common-functions.sh
source scripts/common/common-functions.sh

# Set variables for later use, MODE has a default but can be overridden at usage time
MODE=${1:-start}
SKIP="false"

# Catch problems with MODE input, must be one of Start/Stop
if [[ "$MODE" != "start" && "$MODE" != "deallocate" ]]; then
	echo "Invalid MODE. Please use 'start' or 'deallocate'."
	exit 1
fi

# Find all subscriptions that are available to the credential used and saved to SUBSCRIPTIONS variable
# Then re-order that list placing "HMCTS-HUB-NONPROD-INTSVC" last in SORTED_SUBSCRIPTIONS
SUBSCRIPTIONS=$(az account list -o json)
SORTED_SUBSCRIPTIONS=$(jq -r '[
    ( .[] | select(.name != "HMCTS-HUB-NONPROD-INTSVC" )),
    ( .[] | select(.name == "HMCTS-HUB-NONPROD-INTSVC" ))
]' <<<$SUBSCRIPTIONS)
IS_HUB_NEEDED="false"

# For each subscription found, start the loop
jq -c '.[]' <<< $SORTED_SUBSCRIPTIONS | while read subscription; do

    # Function that returns the Subscription Id and Name as variables,
    # sets the subscription as the default then returns a json formatted variable of available VMs with an autoshutdown tag
    get_subscription_vms
    echo "Scanning $SUBSCRIPTION_NAME..."

    if [[ $SUBSCRIPTION_NAME == "HMCTS-HUB-NONPROD-INTSVC" && $IS_HUB_NEEDED == "true" && $MODE == "deallocate" ]]; then
		continue
	fi

    # For each App Gateway found in the function `get_sql_mi_servers` start another loop
    jq -c '.[]' <<<$VMS | while read vm; do

        # Function that returns the Resource Group, Id and Name of the VMs and its current state as variables
        get_vm_details

        # Declare and populate a map of environments and real names
        declare -A vm_envs=(
            [sandbox]="sbox"
            [testing]="test"
            [staging]="aat"
            [development]="dev"
            [production]="prod"
            [demo]="demo"
            [ithc]="ithc"
        )

        # Check the map of environments using the ENVIRONMENT returned by `get_vm_details` to see if one is found
        # If found set the name based on the value from the `vm_envs` variable map
        if [[ "${vm_envs[$ENVIRONMENT]}" ]]; then
            ENV_SUFFIX="${vm_envs[$ENVIRONMENT]}"
        else
            ENV_SUFFIX="$ENVIRONMENT"
        fi

        # SKIP variable updated based on the output of the `should_skip_start_stop` function which calculates its value based
        # on a tag named `startupMode` and the `issues_list.json` file which contains user requests to keep environments online after normal hours
        SKIP=$(should_skip_start_stop $ENV_SUFFIX $BUSINESS_AREA $MODE)

        # If SKIP is false then we progress with the action (deallocate/start) for the particular VM in this loop run, if not skip and print message to the logs
        if [[ $SKIP == "false" ]]; then
            if [[ $DEV_ENV != "true" ]]; then
                vm_state_messages
                az vm $MODE --ids $VM_ID --no-wait || echo Ignoring any errors while $MODE operation on vm
            else
                ts_echo_color BLUE "Development Env: simulating state commands only."
                vm_state_messages
            fi
        else
            ts_echo_color AMBER "VM: $VM_NAME in Resource Group: $RESOURCE_GROUP has been skipped from today's $MODE operation schedule"
            IS_HUB_NEEDED="true"
        fi
	done
done
