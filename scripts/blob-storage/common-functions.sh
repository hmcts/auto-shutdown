#!/bin/bash

# Function that uses the subscription input to get set variables for later use and gather all storage accounts that have SFTP enabled or disabled
# within the subscription for shutdown
function get_sftp_servers() {
  SUBSCRIPTION_ID=$(jq -r '.id' <<< $subscription)
  SUBSCRIPTION_NAME=$(jq -r '.name' <<< $subscription)
  az account set -s $SUBSCRIPTION_ID
  ENABLED_SFTP_SERVERS=$(az storage account list --query  "[?tags.autoShutdown == 'true' && isSftpEnabled]" -o json)
  DISABLED_SFTP_SERVERS=$(az storage account list --query  "[?tags.autoShutdown == 'true' && !isSftpEnabled]" -o json)
}

# Function that accepts the app gateway json as input and sets variables for later use to stop or start the SFTP server
function get_sftp_server_details() {
  RESOURCE_GROUP=$(jq -r '.resourceGroup' <<< $sftpserver)
  STORAGE_ACCOUNT_ID=$(jq -r '.id' <<< $sftpserver)
  STORAGE_ACCOUNT_NAME=$(jq -r '.name' <<< $sftpserver)
  SFTP_SERVER_ENABLED=$(jq -r '.isSftpEnabled' <<< $sftpserver)
  SFTP_SERVER_STATE=$( [[ "$SFTP_SERVER_ENABLED" =~ "true" ]] && echo enabled || echo disabled )
}

function blob_state_enabled_messages() {
	ts_echo_color GREEN "Enabling SFTP on Storage Account: $STORAGE_ACCOUNT_NAME in Resource Group: $RESOURCE_GROUP and Subscription: $SUBSCRIPTION_NAME"
	ts_echo_color GREEN "Command to run: az storage account update -g $RESOURCE_GROUP -n $STORAGE_ACCOUNT_NAME --enable-sftp=true || echo Ignoring errors Enabling $STORAGE_ACCOUNT_NAME"
}

function blob_state_disabled_messages() {
	ts_echo_color GREEN "Disabling SFTP on Storage Account: $STORAGE_ACCOUNT_NAME in Resource Group: $RESOURCE_GROUP and Subscription: $SUBSCRIPTION_NAME"
	ts_echo_color GREEN "Command to run: az storage account update -g $RESOURCE_GROUP -n $STORAGE_ACCOUNT_NAME --enable-sftp=false || echo Ignoring errors Disabling $STORAGE_ACCOUNT_NAME"
}