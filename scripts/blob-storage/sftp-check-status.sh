#!/usr/bin/env bash
# set -x
shopt -s nocasematch

# Source shared function scripts
source scripts/blob-storage/common-functions.sh
source scripts/common/common-functions.sh

MODE=${1:-start}
notificationSlackWebhook=$2

SUBSCRIPTIONS=$(az account list -o json)
jq -c '.[]' <<< $SUBSCRIPTIONS | while read subscription
do
    get_sftp_servers

    jq -c '.[]'<<< $SFTP_SERVERS | while read sftpserver
    do
        # Function that returns the Resource Group, Id and Name of the Storage Account and the current state of the SFTP Server as variables
        get_sftp_server_details

        logMessage="SFTP Server is $SFTP_SERVER_STATE on Storage Account: $STORAGE_ACCOUNT_NAME in Subscription: $SUBSCRIPTION_NAME and ResourceGroup: $RESOURCE_GROUP"
        slackMessage=":red_circle: SFTP Server on Storage Account: *$STORAGE_ACCOUNT_NAME* in Subscription: *$SUBSCRIPTION_NAME* is $SFTP_SERVER_STATE after *$MODE* action."

        if [[ "$SFTP_SERVER_ENABLED" =~ "true" ]]; then
            ts_echo_color $( [[ $MODE == "start" ]] && echo GREEN || echo RED ) "$logMessage"
            if [[ $MODE == "stop" ]]; then
                auto_shutdown_notification "$slackMessage"
            fi
        elif [[  "$SFTP_SERVER_ENABLED" =~ "false" ]]; then
            ts_echo_color $( [[ $MODE == "start" ]] && echo RED || echo GREEN ) "$logMessage"
            if [[ $MODE == "start" ]]; then
                auto_shutdown_notification "$slackMessage"
            fi
        fi
    done
done
