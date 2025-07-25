#!/usr/bin/env bash
# set -x
shopt -s nocasematch

# Source shared function scripts
source scripts/blob-storage/common-functions.sh
source scripts/common/common-functions.sh

# Set variables for later use, MODE has a default but can be overridden at usage time
# notificationSlackWebhook is used during the function call `auto_shutdown_notification`
MODE=${1:-start}
notificationSlackWebhook=$2

# Catch problems with MODE input, must be one of Start/Stop
if [[ "$MODE" != "start" && "$MODE" != "stop" ]]; then
    echo "Invalid MODE. Please use 'start' or 'stop'."
    exit 1
fi

# Find all servers with a tag of autoShutdown no matter which state it is in
ALL_SFTP_SERVERS=$(get_sftp_servers)

jq -c '.data[]' <<<$ALL_SFTP_SERVERS | while read sftpserver; do
    # Function that returns the Resource Group, Id and Name of the Storage Account and the current state of the SFTP Server as variables
    get_sftp_server_details

    # Setup message output templates for later use
    logMessage="Storage Account: $STORAGE_ACCOUNT_NAME in Subscription: $SUBSCRIPTION and ResourceGroup: $RESOURCE_GROUP after $MODE action, is SFTP enabled: $SFTP_SERVER_ENABLED"
    slackMessage=":red_circle: Storage Account: *$STORAGE_ACCOUNT_NAME* in Subscription: *$SUBSCRIPTION* after *$MODE* action, is SFTP enabled: $SFTP_SERVER_ENABLED ."

    # Check state of the SFTP Server feature and print output as required
    # Depending on the value of MODE a notification will also be sent
    #    - If MODE = Start then a stopped SFTP Server is incorrect and we should notify
    #    - If MODE = Stop then a running SFTP Server is incorrect and we should notify
    #    - If neither Running or Stopped is found then something else is going on and we should notify
    if [[ "$SFTP_SERVER_ENABLED" =~ "true" ]]; then
        ts_echo_color $([[ $MODE == "start" ]] && echo GREEN || echo RED) "$logMessage"
        if [[ $MODE == "stop" ]]; then
            # auto_shutdown_notification "$slackMessage"
            add_to_json "$STORAGE_ACCOUNT_ID" "$STORAGE_ACCOUNT_NAME" "$slackMessage" "blob-storage" "$MODE"
        fi
    fi
done
