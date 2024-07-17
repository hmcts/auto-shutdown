#!/usr/bin/env bash
# set -x
shopt -s nocasematch

# Source shared function scripts
source scripts/blob-storage/common-functions.sh
source scripts/common/common-functions.sh

MODE=${1:-start}
SKIP="false"

SUBSCRIPTIONS=$(az account list -o json)
jq -c '.[]' <<<$SUBSCRIPTIONS | while read subscription; do
	
	get_sftp_servers
	
	jq -c '.[]'<<< $DISABLED_SFTP_SERVERS | while read sftpserver

		get_sftp_server_details

		if [[ $SKIP == "false" ]]; then
			ts_echo_color GREEN "Enabling SFTP on $STORAGE_ACCOUNT_NAME in Resource Group: $RESOURCE_GROUP and Subscription: $SUBSCRIPTION_NAME"
			az storage account update -g $RESOURCE_GROUP -n $STORAGE_ACCOUNT_NAME --enable-sftp=true || echo Ignoring errors Enabling $STORAGE_ACCOUNT_NAME
		else
			ts_echo_color AMBER "Storage account $STORAGE_ACCOUNT_NAME in Resource Group:$RESOURCE_GROUP and Subscription:$SUBSCRIPTION_NAME has been skipped from todays startup schedule"
		fi
	done
done