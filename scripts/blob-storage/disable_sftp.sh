#!/usr/bin/env bash
# set -x
shopt -s nocasematch

# Source shared function scripts
source scripts/blob-storage/common-functions.sh
source scripts/common/common-functions.sh

SKIP="false"

ENABLED_SFTP_SERVERS=$(get_sftp_servers "$1" true)

# For each Storage Account found in the function `get_sftp_servers` start another loop
# The list of SFTP Servers used is ENABLED_SFTP_SERVERS as we want to stop the SFTP service
jq -c '.data[]' <<<$ENABLED_SFTP_SERVERS | while read sftpserver; do

	# Function that returns the Resource Group, Id and Name of the Storage Account and the current state of the SFTP Server as variables
	get_sftp_server_details

	log "====================================================="
	log "Processing SFTP: $STORAGE_ACCOUNT_NAME"
	log "====================================================="

	# If SKIP is false then we progress with the action (stop/start) for the particular App Gateway in this loop run, if not skip and print message to the logs
	if [[ $SKIP == "false" ]]; then
		if [[ $DEV_ENV != "true" ]]; then
			blob_state_disabled_messages
			az storage account update -g $RESOURCE_GROUP -n $STORAGE_ACCOUNT_NAME --subscription $SUBSCRIPTION --enable-sftp=false || echo Ignoring errors Disabling $STORAGE_ACCOUNT_NAME
		else
			ts_echo_color BLUE "Development Env: simulating state commands only."
			blob_state_disabled_messages
		fi
	else
		ts_echo_color AMBER "Storage account $STORAGE_ACCOUNT_NAME in Resource Group:$RESOURCE_GROUP and Subscription:$SUBSCRIPTION_NAME has been skipped from todays shutdown schedule"
	fi
done
