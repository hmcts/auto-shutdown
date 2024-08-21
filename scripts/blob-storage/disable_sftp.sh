#!/usr/bin/env bash
# set -x
shopt -s nocasematch

# Source shared function scripts
source scripts/blob-storage/common-functions.sh
source scripts/common/common-functions.sh

# Set variables for later use, MODE has a default but can be overridden at usage time
MODE=${1:-start}
SKIP="false"

# Catch problems with MODE input, must be one of Start/Stop
if [[ "$MODE" != "start" && "$MODE" != "stop" ]]; then
    echo "Invalid MODE. Please use 'start' or 'stop'."
    exit 1
fi

# Find all subscriptions that are available to the credential used and saved to SUBSCRIPTIONS variable
SUBSCRIPTIONS=$(az account list -o json)

# For each subscription found, start the loop
jq -c '.[]' <<<$SUBSCRIPTIONS | while read subscription
do

	# Function that returns the Subscription Id and Name as variables, sets the subscription
	# as the default then returns a json formatted variable of available SFTP Servers with an autoshutdown tag
	get_sftp_servers
	echo "Scanning $SUBSCRIPTION_NAME..."
	log "Scanning $SUBSCRIPTION_NAME..."

	# For each Storage Account found in the function `get_sftp_servers` start another loop
	# The list of SFTP Servers used is DISABLED_SFTP_SERVERS as we want to start the SFTP service
	jq -c '.[]'<<< $ENABLED_SFTP_SERVERS | while read sftpserver
	do

		# Function that returns the Resource Group, Id and Name of the Storage Account and the current state of the SFTP Server as variables
		get_sftp_server_details

		log "====================================================="
        log "Processing SFTP: $STORAGE_ACCOUNT_NAME"
        log "====================================================="

		# If SKIP is false then we progress with the action (stop/start) for the particular App Gateway in this loop run, if not skip and print message to the logs
		if [[ $SKIP == "false" ]]; then
			if [[ $DEV_ENV != "true" ]]; then
				blob_state_disabled_messages
				az storage account update -g $RESOURCE_GROUP -n $STORAGE_ACCOUNT_NAME --enable-sftp=false || echo Ignoring errors Disabling $STORAGE_ACCOUNT_NAME
			else
				ts_echo_color BLUE "Development Env: simulating state commands only."
				blob_state_disabled_messages
			fi
		else
			ts_echo_color AMBER "Storage account $STORAGE_ACCOUNT_NAME in Resource Group:$RESOURCE_GROUP and Subscription:$SUBSCRIPTION_NAME has been skipped from todays shutdown schedule"
		fi
	done
done
