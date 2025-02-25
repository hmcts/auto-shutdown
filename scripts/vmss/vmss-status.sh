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
