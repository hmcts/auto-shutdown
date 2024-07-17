#!/bin/bash

function get_sftp_servers() {
  SUBSCRIPTION_ID=$(jq -r '.id' <<< $subscription)
  SUBSCRIPTION_NAME=$(jq -r '.name' <<< $subscription)
  az account set -s $SUBSCRIPTION_ID
  SFTP_SERVERS=$(az storage account list --query  "[?tags.autoShutdown == 'true' && isSftpEnabled]" -o json)
}

function get_sftp_server_details() {
  RESOURCE_GROUP=$(jq -r '.resourceGroup' <<< $sftpserver)
  STORAGE_ACCOUNT_ID=$(jq -r '.id' <<< $sftpserver)
  STORAGE_ACCOUNT_NAME=$(jq -r '.name' <<< $sftpserver)
  SFTP_SERVER_ENABLED=$(jq -r '.isSftpEnabled' <<< $sftpserver)
  SFTP_SERVER_STATE=$( [[ "$SFTP_SERVER_ENABLED" =~ "true" ]] && echo enabled || echo disabled )
}