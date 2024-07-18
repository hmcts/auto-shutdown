#!/usr/bin/env bash
# set -x
shopt -s nocasematch

# Source shared function scripts
source scripts/blob-storage/common-functions.sh
source scripts/common/common-functions.sh

MODE=${1:-start}
SKIP="false"

if [[ "$MODE" != "start" && "$MODE" != "stop" ]]; then
    echo "Invalid MODE. Please use 'start' or 'stop'."
    exit 1
fi

SUBSCRIPTIONS=$(az account list -o json)
jq -c '.[]' <<<$SUBSCRIPTIONS | while read subscription
do
	
	get_sftp_servers
    echo "Scanning $SUBSCRIPTION_NAME..."

	jq -c '.[]'<<< $DISABLED_SFTP_SERVERS | while read sftpserver
	do
		get_sftp_server_details

		if [[ $SKIP == "false" ]]; then
			ts_echo_color GREEN "Enabling SFTP on Storage Account: $STORAGE_ACCOUNT_NAME in Resource Group: $RESOURCE_GROUP and Subscription: $SUBSCRIPTION_NAME"
			ts_echo_color GREEN "Command to run: az storage account update -g $RESOURCE_GROUP -n $STORAGE_ACCOUNT_NAME --enable-sftp=true || echo Ignoring errors Enabling $STORAGE_ACCOUNT_NAME"
			az storage account update -g $RESOURCE_GROUP -n $STORAGE_ACCOUNT_NAME --enable-sftp=true || echo Ignoring errors Enabling $STORAGE_ACCOUNT_NAME
		else
			ts_echo_color AMBER "Storage account $STORAGE_ACCOUNT_NAME in Resource Group:$RESOURCE_GROUP and Subscription:$SUBSCRIPTION_NAME has been skipped from todays startup schedule"
		fi
	done
done