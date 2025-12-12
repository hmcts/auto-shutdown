#!/usr/bin/env bash
# set -x
shopt -s nocasematch

# Source shared function scripts
source scripts/vmss/common-functions.sh
source scripts/common/common-functions.sh

# Set variables for later use, MODE has a default but can be overridden at usage time
# slack token for the shutdown status app is passed as env var and used to post a thread with all the individual resource statuses
MODE=${1:-start}
SKIP="false"

# Catch problems with MODE input, must be one of start/deallocate
if [[ "$MODE" != "start" && "$MODE" != "deallocate" ]]; then
	echo "Invalid MODE. Please use 'start' or 'deallocate'."
	exit 1
fi

VMSS=$(get_vmss)

auto_shutdown_notifications=""
# Iterate over each VMSS instance
while read vmss; do
    # Retrieve details about the VMSS instance
    get_vmss_details "$vmss"

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
    SKIP=$(should_skip_start_stop $VMSS_ENV $BUSINESS_AREA $MODE "vmss")

	# If SKIP is false then we progress with the status check for the particular VMSS in this loop run, if SKIP is true then do nothing
    if [[ $SKIP == "false" ]]; then
        slackMessage="VMSS: *$VMSS_NAME* in Subscription: *$SUBSCRIPTION* ResourceGroup: *$RESOURCE_GROUP* is *$VMSS_STATE* after *$MODE* action."

        # Check state of the VMSS and print output as required
        # Depending on the value of MODE a notification will also be sent
        #    - If MODE = start then a stopped VMSS is incorrect and we should notify
        #    - If MODE = deallocate then a running VMSS is incorrect and we should notify
        #    - If neither Running or Stopped is found then something else is going on and we should notify
        case "$VMSS_STATE" in
            "running")
                ts_echo_color $( [[ $MODE == "start" ]] && echo GREEN || echo RED ) "$logMessage"
                if [[ $MODE == "deallocate" ]]; then
                    auto_shutdown_notifications+=":red_circle: $slackMessage|"
                    add_to_json "$VMSS_ID" "$VMSS_NAME" "$slackMessage" "vmss" "$MODE"
                fi
                ;;
            "deallocated")
                ts_echo_color $( [[ $MODE == "start" ]] && echo RED || echo GREEN ) "$logMessage"
                if [[ $MODE == "start" ]]; then
                    auto_shutdown_notifications+=":red_circle: $slackMessage|"
                    add_to_json "$VMSS_ID" "$VMSS_NAME" "$slackMessage" "vmss" "$MODE"
                fi
                ;;
            *)
                ts_echo_color AMBER "$logMessage"
                auto_shutdown_notifications+=":yellow_circle: $slackMessage|"
                add_to_json "$VMSS_ID" "$VMSS_NAME" "$slackMessage" "vmss" "$MODE"
                ;;
        esac
    else
        ts_echo_color AMBER "VMSS: $VMSS_NAME in Resource Group: $RESOURCE_GROUP has been skipped from today's $MODE operation schedule."
    fi
done < <(jq -c '.data[]' <<<$VMSS)

post_entire_autoshutdown_thread ":red_circle: :azure: VMSS START status check" "$auto_shutdown_notifications"
