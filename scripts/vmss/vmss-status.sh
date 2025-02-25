#!/usr/bin/env bash
# set -x
shopt -s nocasematch

# Source shared function scripts
source scripts/vm/common-functions.sh
source scripts/common/common-functions.sh

# Set variables for later use, MODE has a default but can be overridden at usage time
# notificationSlackWebhook is used during the function call `auto_shutdown_notification`
MODE=${1:-start}
notificationSlackWebhook=$2
SKIP="false"

# Catch problems with MODE input, must be one of start/deallocate
if [[ "$MODE" != "start" && "$MODE" != "deallocate" ]]; then
	echo "Invalid MODE. Please use 'start' or 'deallocate'."
	exit 1
fi

VMSS=$(get_vmss)

# Iterate over each VMSS instance
jq -c '.data[]' <<<$VMSS_LIST | while read vmss; do
    # Retrieve details about the VMSS instance
    get_vmss_details

    log "====================================================="
    log "Processing VMSS: $VMSS_NAME in Resource Group: $RESOURCE_GROUP"
    log "====================================================="

    # Map the environment name to match Azure enviornment tag
    if [[ $ENVIRONMENT == "development" ]]; then
        VM_ENV=${ENVIRONMENT/development/Preview}
    elif [[ $ENVIRONMENT == "testing" ]]; then
        VM_ENV=${ENVIRONMENT/testing/Perftest}
    else
        VM_ENV=$(to_lowercase "$ENVIRONMENT")
    fi

    # SKIP variable updated based on the output of the `should_skip_start_stop` function which calculates its value based
    # on a tag named `startupMode` and the `issues_list.json` file which contains user requests to keep environments online after normal hours vmss
    log "Checking skip logic for env: $VMSS_ENV, business_area: $BUSINESS_AREA, mode: $MODE"
    SKIP=$(should_skip_start_stop $VMSS_ENV $BUSINESS_AREA $MODE)

    # Setup message output templates for later use
	logMessage="VMSS: $VMSS_NAME in ResourceGroup: $RESOURCE_GROUP is in $VMSS_STATE after $MODE action."
    slackMessage="VMSS: *$VMSS_NAME* in Subscription: *$SUBSCRIPTION* ResourceGroup: *$RESOURCE_GROUP* is *$VMSS_STATE* after *$MODE* action."